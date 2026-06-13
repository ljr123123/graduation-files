function du = qs_mspg_rhs_impl_hyst(u)
%QS_MSPG_RHS_IMPL_HYST 在 qs_mspg_rhs_impl 基础上增加迟滞门控状态 q(t)
%
% 除瞬时 Hill φ(A)=A^n/(KA^n+A^n) 外，引入 q∈[0,1]：
%   w_up(A)=A^n/(KA_on^n+A^n)，w_dn(A)=KA_off^n/(KA_off^n+A^n)（KA_on>KA_off）
%   dq/dt = k_hyst·(w_up·(1−q) − w_dn·q)
% 公共收益与食物项使用 φ_eff = q·φ(A)，即 boost = 1 + qsBoost·φ_eff。
%
% 输入 u = [x_1; ...; x_M; A; q]；参数 KA_on、KA_off、k_hyst、q0 由 Model Workspace 提供。

mw = get_param(bdroot, "ModelWorkspace");

M = evalin(mw, "M");
nTraits = evalin(mw, "nTraits");

if numel(u) ~= M + 2
    error("qs_mspg_rhs_impl_hyst:BadU", "u 长度须为 M+2=%d，当前为 %d。", M + 2, numel(u));
end

x = u(1:M);
Ahl = u(M+1);
qh = u(M+2);
qh = min(1, max(0, qh));

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
KA_on = double(evalin(mw, "KA_on"));
KA_off = double(evalin(mw, "KA_off"));
k_hyst = double(evalin(mw, "k_hyst"));
KA_on = KA_on(1);
KA_off = KA_off(1);
k_hyst = max(0, k_hyst(1));

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
p_ch = f(:).' * cheat_frac;
B_trait = sum(b_vec(:) .* (1 - p_ch(:)));
Apos = max(0, Ahl);
phiA = (Apos^nHill) / (max(eps, KA^nHill) + Apos^nHill);

w_up = (Apos^nHill) / (max(eps, KA_on^nHill) + Apos^nHill);
w_dn = (max(eps, KA_off^nHill)) / (max(eps, KA_off^nHill) + Apos^nHill);
dqdt = k_hyst * (w_up * (1 - qh) - w_dn * qh);

phi_eff = qh * phiA;
boost = 1 + qsBoost * phi_eff;
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

du = [dx; dAdt; dqdt];
end
