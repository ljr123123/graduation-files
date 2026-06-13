function du = qs_mspg_rhs_impl(u)
%QS_MSPG_RHS_IMPL 多菌群公共物品适应度 + 复制子动力学 + Logistic 增长 + QS(AHL)
%
% 适应度（与文档「合作者-欺骗者」一致，可推广到 M 菌株 × nTraits 性状）：
%   p_ch(i) = 性状 i 上「不生产公共物」的菌群频率加权和
%   B_trait = Σ_i b_i(1 - p_ch(i))（性状层「环境公共物/合作收益」基础量）
%   φ(A) = A^n/(KA^n+A^n)（Hill；A 为 AHL 浓度）
%   公共收益放大：Bcommon = ω0 + B_trait·(1 + qsBoost·φ(A))（qsBoost≥0；0 则 A 不影响适应度）
%   ω_j = Bcommon - Σ_i c_i·I{菌株 j 生产性状 i} - c_signal·kA_j（产信号有代谢代价；产公共性状仍有 c_i）
% 公共物即食物（可选）：S_food = (B_trait + foodAmbient)·(1 + qsBoost·φ(A))，avail = S_food/(N+eps)。
%   产量加权取食权 q_j = (Σ_i b_i·produce_{j,i}) / (Σ_i b_i)，access_j = a_min + (1-a_min)·q_j，
%   a_min = foodAccessMin∈[0,1]（全不产者仅保留 a_min 倍取食效率；a_min=1 时退化为株间无差别）。
%   sat_j = min(1, avail·access_j / max(need_j, need_floor))，need_vec 为人均食物需求。
% 群体动力学：
%   dx_j/dt = sat_j·x_j·( r·(1-N/K) + η·(ω_j - \bar{ω}) ),  \bar{ω}=Σ f_j ω_j
%   dA/dt   = Σ_j kA_j·x_j - dA·A - δ·N·A
%   enableFoodLimit=false 时 sat_j≡1，退化为原方程。
%
% 输入 u = [x_1; ...; x_M; A]，所有标量/向量/矩阵参数从当前 bdroot 的 Model Workspace 读取：
%   M, nTraits, r, K, eta_game, omega0, b_vec(1×nTraits), c_vec(1×nTraits),
%   produce(M×nTraits, 0/1 是否承担性状 i 成本), decepStrength(放大有效成本 c),
%   kA_vec(1×M), dA, delta_qs, KA, n, epsN
%   qsBoost（A 对性状公共收益的放大系数）, c_signal（单位 kA 的信号合成代价）
%   enableFoodLimit, foodAmbient, foodAccessMin, need_vec(1×M), need_floor
%
% 输出 du = [dx_1; ...; dx_M; dA]

mw = get_param(bdroot, "ModelWorkspace");

M = evalin(mw, "M");
nTraits = evalin(mw, "nTraits");

x = u(1:M);
Ahl = u(M+1);

r = evalin(mw, "r");
K = evalin(mw, "K");
eta_game = evalin(mw, "eta_game");
omega0 = evalin(mw, "omega0");
b_vec = evalin(mw, "b_vec");
c_vec = evalin(mw, "c_vec");
decepStrength = evalin(mw, "decepStrength");
produce = evalin(mw, "produce");
kA_vec = evalin(mw, "kA_vec");
dAcoef = evalin(mw, "dA");
delta_qs = evalin(mw, "delta_qs");
KA = evalin(mw, "KA");
nHill = evalin(mw, "n");
epsN = evalin(mw, "epsN");
try
    qsBoost = double(evalin(mw, "qsBoost"));
catch
    qsBoost = 0;
end
try
    c_signal = double(evalin(mw, "c_signal"));
catch
    c_signal = 0;
end
qsBoost = qsBoost(1);
c_signal = c_signal(1);
KA = double(KA(1));
nHill = double(nHill(1));

try
    enableFoodLimit = logical(evalin(mw, "enableFoodLimit"));
catch
    enableFoodLimit = false;
end
try
    foodAmbient = double(evalin(mw, "foodAmbient"));
catch
    foodAmbient = 0;
end
try
    need_floor = double(evalin(mw, "need_floor"));
catch
    need_floor = 1e-9;
end
try
    foodAccessMin = double(evalin(mw, "foodAccessMin"));
catch
    foodAccessMin = 1.0;
end

b_vec = b_vec(:);
c_vec = c_vec(:) * decepStrength;

N = sum(x);
g = 1 - N / K;
f = x / (N + epsN);

cheat_frac = 1 - produce;
p_ch = f(:).' * cheat_frac;  % 1×nTraits，性状 i 上「不生产」的频率加权和
B_trait = sum(b_vec(:) .* (1 - p_ch(:)));
Apos = max(0, Ahl);
phiA = (Apos^nHill) / (max(eps, KA^nHill) + Apos^nHill);
boost = 1 + qsBoost * phiA;
Bcommon = omega0 + B_trait * boost;

cost_per_strain = produce * c_vec;
signal_cost = c_signal * kA_vec(:);
omega = Bcommon - cost_per_strain - signal_cost;

omega_bar = dot(f(:), omega(:));

if enableFoodLimit
    S_food = (B_trait + foodAmbient) * boost;
    avail = S_food / (N + epsN);
    try
        need_vec = evalin(mw, "need_vec");
        need_vec = need_vec(:);
    catch
        need_vec = ones(M, 1);
    end
    if numel(need_vec) ~= M
        need_vec = ones(M, 1);
    end
    sb = sum(b_vec);
    if sb > 1e-12
        qcontrib = (produce * b_vec) / sb;
    else
        qcontrib = mean(produce, 2);
    end
    aMin = min(1, max(0, foodAccessMin));
    access = aMin + (1 - aMin) * qcontrib(:);
    sat = min(1, (avail * access) ./ max(need_vec, need_floor));
else
    sat = ones(M, 1);
end

dx = x .* sat .* (r * g + eta_game * (omega - omega_bar));

dAdt = dot(kA_vec(:), x(:)) - dAcoef * Ahl - delta_qs * N * Ahl;

du = [dx; dAdt];
end
