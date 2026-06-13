function modelName = build_modular_qs_simulink_model_hyst(varargin)
%BUILD_MODULAR_QS_SIMULINK_MODEL_HYST 本文件为 build_modular_qs_simulink_model 的副本：MSPG 路径增加 QS 迟滞门控状态 q(t)
%
% 【双菌欺骗结构扫描】菌群 N1/N2，信号 A1/A2，产物 B1/B2：
%   已知 A1 促进 N1 产 B1；A2 对 N2 产 B2 无直接调制；B1、B2 分别抑制 N1、N2。
%   四种假设对应 (A2→N1 产 B1, A1→N2 产 B2) 的促进/抑制组合（sign ∈ {+1,-1}）。
%   欺骗模式：N1、N2 各自是否合成 A1、A2（无 / 仅 A1 / 仅 A2 / A1+A2，共 4×4 组合）。
%   指标：末段几何平均菌量 sqrt(N1*N2)、末段几何平均产物 sqrt(B1*B2)、累积资源 R(T)；
%   另记录末段 std(N1+N2) 仅作诊断，不参与排序。
%   综合评价（取代原 scoreNorm / 论文 d1–d3 排序）：先在同一假设 16 组内对 geomMeanN、geomMeanB、resTotal
%     分别 min-max 归一化得 geomMeanN_h、geomMeanB_h、resTotal_h（其中 resTotal_h=1−minmax(resTotal)，越大越省）；
%     **主排序标量** econGeomScore = (geomMeanN_h + geomMeanB_h + resTotal_h) / 3，各假设内按该值降序，平局 strat 升序；
%     lexRank=1 为最优。与门槛比较得 passCountEcon，仅诊断，不参与 lexRank。
%   门槛模式 DeceptionEconThreshMode：「median16」= 各假设 16 组各自取中位数作门槛（N、B 为 ≥，res 为 ≤）；
%     「fixed」= 用 DeceptionThreshGeomMeanN/B、DeceptionThreshResTotal（NaN 表示该条不参与计数）；
%     「none」= 不过门槛比较，passCountEcon 固定为 3。
%   调用：build_modular_qs_simulink_model_hyst("RunDualCommunityDeceptionSweep",true)
%   d1,d2,d3（Table 1）仍写入 rows 仅作**稳态诊断**，不参与 lexRank；判据与 DualStableEps1/2/3 见下。
%   强度参数：双菌扫描默认 DualUseHysteresis=true 时用 dual_qs_community_rhs_hyst（在 dual_qs_community_rhs
%   上增加 A1/A2 迟滞门控 q1、q2）；false 时用原版 dual_qs_community_rhs。论文式 (9)–(16) 同构（无量纲 S=S/S0）。
%   论文 Table 1 定标：将 DualD、DualS0、DualKS、DualKBmax*、DualOmega*、DualK_A*_B* 等替换为实验先验；
%   DualAinflux1/2 为外源/渗漏 A 通量，避免无产信号时 A≡0 导致交叉假设不可辨识（纯闭合系统可置 0）。
%
% 欺骗/合作以「多性状公共物品」适应度量化（可推广到 M 菌株 × nTraits 性状）：
%   p_ch(i) = Σ_j f_j·(1 - produce_{j,i})，f_j = x_j/N
%   ω_j = ω0 + Σ_i b_i(1 - p_ch(i)) - Σ_i c_i·produce_{j,i}·decepStrength
%   dx_j/dt = x_j·r·(1-N/K) + η·x_j·(ω_j - \bar{ω})
%   dA/dt = Σ_j kA_j·x_j - dA·A - δ·N·A
% 可选：公共物作食物 — enableFoodLimit、foodAmbient、foodAccessMin、need_vec、need_floor；
%   access_j=foodAccessMin+(1-foodAccessMin)·(Σ_i b_i produce_{j,i})/(Σ_i b_i)，
%   sat_j=min(1, S_food/(N+eps)·access_j/max(need_j,need_floor))；foodAccessMin=1 时株间取食无差别。
% 默认 produce（nTraits=2, M=4）：合作者 / 只欺瞒性状1 / 只欺瞒性状2 / 两性状均不生产（纯搭便车）。
%
% 【备注】默认经济参数（演示用，打破对称）
%   若 b1=b2 且 c1=c2，且初值比例相同，则「只欺瞒性状1」与「只欺瞒性状2」两株有 ω2=B−c2、
%   ω3=B−c1 恒相等，复制子方程对称，Mux_Pop(2) 与 Mux_Pop(3) 会完全重合。
%   下列为脚本内置默认（未传入 b_vec/c_vec 时写入 Model Workspace）：
%     nTraits=2 ： b_vec = [0.58, 0.36]  （性状1 公共收益权重高于性状2）
%                c_vec = [0.24, 0.16]  （承担性状1 成本高于性状2，故欺骗株 2、3 不再等价）
%     nTraits>2 ： b_vec、c_vec 用 linspace 在相近量级上略单调变化，避免多株偶然全对称。
%   论文定标时请按实验/文献替换，或通过 Name-Value「b_vec」「c_vec」覆盖。
%   信号代价 c_signal：ω 中减去 c_signal·kA_j。默认取与「produce·c」同量级（kA_sum≈0.1 时 kA_j 约 0.03–0.1，
%   故 c_signal≈4 使 c_signal·kA 约 0.1–0.4，与单株双性状成本可比）；旧版 0.07 会使信号项过小。
%   QS 形状 φ(A)=A^n/(KA^n+A^n)：默认 KA≈0.75（相对旧版 KA=5），在 A∼0.3–1 时 φ 已较大，便于展示促进；
%   qsBoost 默认约 1，使 (1+qsBoost·φ) 动态范围更明显（定标请按文献再调）。
% 【迟滞】增加标量状态 q∈[0,1]（Simulink 中 Int_q 积分）：表征 Lux 类调控的慢「开/关」记忆。
%   w_up(A)=A^n/(KA_on^n+A^n) 促进 q 上升；w_dn(A)=KA_off^n/(KA_off^n+A^n) 在 A 低时促进 q 下降；要求 KA_on>KA_off。
%   dq/dt = k_hyst·(w_up·(1−q) − w_dn·q)。有效感应项取 φ_eff = q·φ(A)，即 boost = 1 + qsBoost·φ_eff（食物链同样用 φ_eff）。
%   参数：KA_on/KA_off（传 ≤0 时分别取 1.2·KA、0.7·KA）、k_hyst、q0。RHS 见 qs_mspg_rhs_impl_hyst.m。
%
% 依赖同目录下 qs_mspg_rhs_impl_hyst.m、qs_mspg_rhs_component_hyst.m（每状态一个 MATLAB Fcn 标量输出）；
% 构建时会 addpath 本脚本目录。
%
% 用法：
%   build_modular_qs_simulink_model_hyst              % 默认不弹出 Simulink 编辑窗（OpenModel=false）
%   build_modular_qs_simulink_model_hyst("ModelName","qs_modular_mspg")
%   build_modular_qs_simulink_model_hyst("OpenModel",true,"RunSim",true)  % 需要看图或改模型时再打开
%   build_modular_qs_simulink_model_hyst("RunDecepSweep",true)
%   build_modular_qs_simulink_model_hyst("RunNpopSweep",true)
%   build_modular_qs_simulink_model_hyst("NumStrains",3,"nTraits",2, ...)  % 若不要「全隐瞒」株可改回 M=3
%   build_modular_qs_simulink_model_hyst("enableFoodLimit",false)  % 关闭「公共物=食物」限制（退化为原 dx）
%   build_modular_qs_simulink_model_hyst("foodAccessMin",1)  % 与旧版相同：不按产量区分取食权
%   build_modular_qs_simulink_model_hyst("foodAccessMin",0.08,"foodAmbient",0.015)  % 全瞒株更难蹭饭
%   build_modular_qs_simulink_model_hyst("RunDualCommunityDeceptionSweep",true,"OpenModel",false,"SaveModel",false)
%   （双菌图默认在 figure_hyst/，与原版 figure/ 区分；mat 内 dualSweepMeta.usedHysteresisDual、dualRhsId 可核对是否用迟滞 RHS）
%   build_modular_qs_simulink_model_hyst("RunDualCommunityDeceptionSweep",true,"DualUseHysteresis",false)  % 双菌退回无迟滞 8 维
%   build_modular_qs_simulink_model_hyst("RunDualCommunityDeceptionSweep",true,"DualHystRateA1",5,"DualHystq01",0.2)
%   独立 ode45：按 build 脚本中 local_dualBuildParamStruct 的字段表自行构造 struct p（须含 k_hyst_A*、KA_on_A*、KA_off_A*），
%   [t,y]=ode45(@(t,y)dual_qs_community_rhs_hyst(t,y,p),[0,T],y0);
%
% 说明：求解器 variable-step/ode45；参数在 Model Workspace；InitFcn 根据 N_pop、frac_init 写 x0_1..x0_M；q 初值为 q0

scriptDir = fileparts(mfilename("fullpath"));
if ~isempty(scriptDir)
    addpath(scriptDir);
end

opts = struct( ...
    "ModelName", "qs_modular_mspg_hyst", ...  % 与原版模型名区分；避免与 qs_modular_sys.* 同名遮蔽
    "OpenModel", false, ...   % false：不 open_system，仅 MATLAB 图窗；需编辑模型时传 true
    "RunSim", false, ...
    "SaveModel", true, ...
    "StopTime", "24", ...
    "MaxStep", "0.1", ...
    "RunDecepSweep", false, ...
    "RunNpopSweep", false, ...
    "DecepSweepValues", [0.25 0.5 1.0 1.5 2.0], ...
    "NpopSweepValues", [0.05 0.1 0.2 0.35 0.5 0.8], ...
    "NumStrains", 4, ...
    "nTraits", 2, ...
    "ProduceMatrix", [], ...   % 空则默认：合作者 + 各「单性状欺骗」+ 全欺骗行
    "FracInit", [], ...      % 空则均匀 1/M；长度须为 M
    "b_vec", [], ...         % 空则 0.5×ones(1,nTraits)
    "c_vec", [], ...         % 空则 0.2×ones(1,nTraits)
    "kA_vec", [], ...        % 空则仅菌株 1 产 AHL
    "enableFoodLimit", true, ...
    "foodAmbient", 0.02, ...   % 外源底物；越小越依赖公共物转化来的食物
    "foodAccessMin", 0.1, ...  % 全不产者取食效率下限；1=株间无差别（旧行为）
    "need_vec", [], ...        % 空则 ones(1,M)
    "need_floor", 1e-9, ...
    "qsBoost", 1.0, ...         % B_trait 上乘 (1+qsBoost·φ)；增大则 QS 促进在图中更显眼
    "KA", 0.75, ...            % Hill 半饱和尺度；取 <1 使常见 A 浓度下 φ(A) 不过小（旧默认 5 过钝）
    "hillN", 2, ...            % Hill 指数 n，写入 Model Workspace 的变量名仍为 n
    "c_signal", 4.0, ...        % 单位 kA 的信号代价；与 kA_sum~0.1、c_vec 配合使 c_signal·kA 与性状成本同量级
    "KA_on", 0, ...             % Hill「易开」尺度；≤0 时构建阶段取 max(1e-6,1.2*KA)
    "KA_off", 0, ...            % Hill「易关」尺度；≤0 时取 max(1e-6,0.7*KA)；须 KA_off < KA_on
    "k_hyst", 3.0, ...          % 迟滞门控弛豫速率 k_hyst ≥ 0
    "q0", 0, ...                % q(0)∈[0,1]
    "RunDualCommunityDeceptionSweep", false, ...
    "DualStopTime", 120, ...
    "DualN0", 0.12, ...                % N1、N2 初值（各，无量纲丰度）
    "DualS0", 1.0, ...                 % 恒化器无量纲营养上界 S0（入流浓度 / 尺度）
    "DualSInit", [], ...               % 空则 = DualS0
    "DualAInit", 0.02, ...             % A1、A2 初值（与 Hill 半饱和同量级便于辨识）
    "DualBInit", 1e-6, ...             % B1、B2 初值
    "DualBaseKA", 0.09, ...            % 开启某信号通道时的 per-capita 合成系数（写入 kA*_N*）
    "DualD", 0.07, ...                 % 稀释率 D（与论文 D h^{-1} 同角色；此处与 t 无量纲一致）
    "DualKS", 0.22, ...                 % Monod 半饱和（无量纲 S）
    "DualMuMax1", 0.52, ...
    "DualMuMax2", 0.48, ...
    "DualGamma1", 1.1, ...             % 产量系数 gamma（越大则同等 mu 耗 S 越少）
    "DualGamma2", 1.1, ...
    "DualKBmax1", 0.32, ...            % B1 最大合成率尺度 KB_max,1
    "DualKBmax2", 0.28, ...
    "DualOmegaMax", 0.28, ...          % omega_max（杀伤强度）
    "DualKOmega", 0.55, ...              % K_omega（杀伤 Hill 半饱和）
    "DualNOmega", 2, ...               % n_omega 杀伤 Hill 指数
    "DualK_A1_B1", 0.12, ...           % A1→B1 诱导半饱和（与 DualAInit 同量级）
    "DualK_A2_B1", 0.12, ...           % A2→B1 交叉调节半饱和
    "DualK_A1_B2", 0.12, ...           % A1→B2 交叉调节半饱和
    "DualMetCostA", 0.018, ...         % 生长负担：对 (kA1+kA2) 线性计价
    "DualMetCostB1", 0.022, ...
    "DualMetCostB2", 0.022, ...
    "DualCostA1", 1.0, ...             % 资源积分：单位 A1 合成通量代价
    "DualCostA2", 1.0, ...
    "DualCostB1", 0.35, ...
    "DualCostB2", 0.35, ...
    "DualResultsMat", "dual_community_deception_results.mat", ...
    "DualAinflux1", 0.014, ...   % 外源/渗漏 A1 通量
    "DualAinflux2", 0.014, ...
    "DualUseHysteresis", true, ...  % 双菌 ode45：true=dual_qs_community_rhs_hyst（10 维 y）；false=原版 8 维
    "DualHystRateA1", 3.0, ...     % A1 门控 q1 弛豫速率 k≥0
    "DualHystRateA2", 3.0, ...     % A2 门控 q2
    "DualHystKAonA1", 0, ...       % >0 为显式 KA_on；≤0 则取 1.2*DualK_A1_B1
    "DualHystKAoffA1", 0, ...      % ≤0 则 0.7*DualK_A1_B1；须最终 KA_off < KA_on
    "DualHystKAonA2", 0, ...       % ≤0 则 1.2*DualK_A2_B1
    "DualHystKAoffA2", 0, ...      % ≤0 则 0.7*DualK_A2_B1
    "DualHystq01", 0, ...          % q1(0)∈[0,1]
    "DualHystq02", 0, ...          % q2(0)∈[0,1]
    "DualNtRef", 200, ...           % 与 compare_three_strain_topologies 一致：统一时间栅格点数
    "DualSaveFigures", true, ...    % 双菌扫描：导出 24 张图到文件夹（不弹窗）
    "DualFigureExportDir", "figure_hyst", ...  % 默认与原版 build 的 figure 区分，避免误以为未更新
    "DualFigureResolution", 200, ...
    "DualFigureFormat", "png", ...
    "DualStableEps1", 1e-9, ...      % 论文 Table：d1=|ΔN| 阈值（OD 差分尺度）
    "DualStableEps2", 0.001, ...     % d2=σ(N) 末段振荡阈值
    "DualStableEps3", 1000, ...      % d3=1/N(T) 须 < ε3（论文 N>0.001 OD）
    "DualStableTailFrac", 0.3, ...   % 计算 d2 的末段时间比例（与几何均值窗一致）
    "DeceptionEconThreshMode", "median16", ... % median16 | fixed | none（见文件头「综合评价」）
    "DeceptionThreshGeomMeanN", nan, ...       % fixed：geomMeanN >= 该值算过线；NaN 不参与计数
    "DeceptionThreshGeomMeanB", nan, ...
    "DeceptionThreshResTotal", nan ...        % fixed：resTotal <= 该值算过线（累积资源越小越好）
);
opts = local_parseNameValue(opts, varargin{:});

modelName = char(opts.ModelName);
M = max(2, round(double(opts.NumStrains)));
Ktraits = max(1, round(double(opts.nTraits)));

load_system("simulink");
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
if opts.OpenModel
    open_system(modelName);
end

set_param(modelName, ...
    "StopTime", char(opts.StopTime), ...
    "SolverType", "Variable-step", ...
    "Solver", "ode45", ...
    "MaxStep", char(opts.MaxStep), ...
    "SimulationMode", "normal" ...
);

local_initModelWorkspaceAndCallbacks(modelName, M, Ktraits, opts);

blk = struct();
blk.intX = cell(1, M);
y0 = 80;
dy = 55;
for j = 1:M
    blk.intX{j} = [modelName sprintf('/Int_x%d', j)];
    pos = [120, y0 + (j-1)*dy, 170, y0 + (j-1)*dy + 40];
    local_add_block("simulink/Continuous/Integrator", blk.intX{j}, "Position", pos);
    set_param(blk.intX{j}, "InitialCondition", sprintf("x0_%d", j));
end
blk.intA = [modelName '/Int_A'];
local_add_block("simulink/Continuous/Integrator", blk.intA, "Position", [120, y0 + M*dy + 20, 170, y0 + M*dy + 60]);
set_param(blk.intA, "InitialCondition", "A0");

blk.intQ = [modelName '/Int_q'];
local_add_block("simulink/Continuous/Integrator", blk.intQ, "Position", [120, y0 + (M+1)*dy + 10, 170, y0 + (M+1)*dy + 50]);
set_param(blk.intQ, "InitialCondition", "q0");

% Mux [x1;...;xM;A;q] -> (M+2) 个 MATLAB Fcn 各输出标量导数（避免向量输出宽度在 MATLAB Fcn 上不可靠）
blk.muxU = [modelName '/Mux_u'];
local_add_block("simulink/Signal Routing/Mux", blk.muxU, ...
    "Inputs", sprintf("%d", M+2), "Position", [260, y0 + 30, 280, y0 + 30 + (M+1)*35]);

blk.mlf = cell(1, M+2);
dxW = 125;
dxH = 26;
for k = 1:(M+2)
    blk.mlf{k} = [modelName sprintf('/MSPG_dx%d', k)];
    py = y0 + 32 + (k - 1) * (dxH + 8);
    local_add_block("simulink/User-Defined Functions/MATLAB Fcn", blk.mlf{k}, ...
        "Position", [360, py, 360 + dxW, py + dxH], ...
        "MATLABFcn", sprintf("qs_mspg_rhs_component_hyst(u,%d)", k));
end

for j = 1:M
    add_line(modelName, sprintf("Int_x%d/1", j), sprintf("Mux_u/%d", j), "autorouting", "on");
end
add_line(modelName, "Int_A/1", sprintf("Mux_u/%d", M+1), "autorouting", "on");
add_line(modelName, "Int_q/1", sprintf("Mux_u/%d", M+2), "autorouting", "on");

for k = 1:(M+2)
    add_line(modelName, "Mux_u/1", sprintf("MSPG_dx%d/1", k), "autorouting", "on");
    if k <= M
        add_line(modelName, sprintf("MSPG_dx%d/1", k), sprintf("Int_x%d/1", k), "autorouting", "on");
    elseif k == M+1
        add_line(modelName, sprintf("MSPG_dx%d/1", k), "Int_A/1", "autorouting", "on");
    else
        add_line(modelName, sprintf("MSPG_dx%d/1", k), "Int_q/1", "autorouting", "on");
    end
end

% Readout
blk.readout = [modelName '/Readout'];
local_add_block("simulink/Ports & Subsystems/Subsystem", blk.readout, "Position", [620, y0 + 20, 790, y0 + 120]);
local_buildReadoutSubsystem(blk.readout);

blk.muxPop = [modelName '/Mux_Pop'];
blk.scopePop = [modelName '/Scope_Pop'];
blk.scopeA = [modelName '/Scope_A'];
blk.scopeQ = [modelName '/Scope_q'];
blk.scopeOut = [modelName '/Scope_Output'];
local_add_block("simulink/Signal Routing/Mux", blk.muxPop, "Inputs", sprintf("%d", M), "Position", [820, y0, 840, y0 + 40 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopePop, "Position", [880, y0 - 15, 930, y0 + 45 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopeA, "Position", [880, y0 + 120 + M*15, 930, y0 + 180 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopeQ, "Position", [880, y0 + 200 + M*15, 930, y0 + 260 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopeOut, "Position", [880, y0 + 260 + M*30, 930, y0 + 320 + M*30]);

for j = 1:M
    add_line(modelName, sprintf("Int_x%d/1", j), sprintf("Mux_Pop/%d", j), "autorouting", "on");
end
add_line(modelName, "Mux_Pop/1", "Scope_Pop/1", "autorouting", "on");
add_line(modelName, "Int_A/1", "Scope_A/1", "autorouting", "on");
add_line(modelName, "Int_q/1", "Scope_q/1", "autorouting", "on");
add_line(modelName, "Int_A/1", "Readout/1", "autorouting", "on");
add_line(modelName, "Readout/1", "Scope_Output/1", "autorouting", "on");

% To Workspace：总种群向量（Structure With Time，signals.values 为 M 列）
blk.twPop = [modelName '/ToWorkspace_Pop'];
local_add_block("simulink/Sinks/To Workspace", blk.twPop, ...
    "VariableName", "qs_sim_pop", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820, y0 + 70 + M*10, 880, y0 + 90 + M*10]);
add_line(modelName, "Mux_Pop/1", "ToWorkspace_Pop/1", "autorouting", "on");

blk.twA = [modelName '/ToWorkspace_A'];
local_add_block("simulink/Sinks/To Workspace", blk.twA, ...
    "VariableName", "qs_sim_A", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820, y0 + 150 + M*15, 880, y0 + 170 + M*15]);
add_line(modelName, "Int_A/1", "ToWorkspace_A/1", "autorouting", "on");

blk.twQ = [modelName '/ToWorkspace_q'];
local_add_block("simulink/Sinks/To Workspace", blk.twQ, ...
    "VariableName", "qs_sim_q", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820, y0 + 190 + M*15, 880, y0 + 210 + M*15]);
add_line(modelName, "Int_q/1", "ToWorkspace_q/1", "autorouting", "on");

try
    set_param(modelName, "SimulationCommand", "update");
catch ME %#ok<NASGU>
end

if opts.SaveModel
    save_system(modelName);
end
if opts.RunDecepSweep
    local_runDecepSweep(modelName, opts.DecepSweepValues, M);
end
if opts.RunNpopSweep
    local_runNpopSweep(modelName, opts.NpopSweepValues, M);
end
if ~opts.OpenModel
    close_system(modelName, 0);
end
if opts.RunSim
    sim(modelName);
end
if opts.RunDualCommunityDeceptionSweep
    local_runDualCommunityDeceptionSweep(opts, scriptDir);
end
end

function local_buildReadoutSubsystem(subsysPath)
% 端口：In1 = A, Out1 = Output（Hill）
Simulink.SubSystem.deleteContents(subsysPath);

inA  = [subsysPath '/A'];
outY = [subsysPath '/Output'];
local_add_block("simulink/Ports & Subsystems/In1",  inA,  "Position", [60 90 90 110]);
local_add_block("simulink/Ports & Subsystems/Out1", outY, "Position", [520 90 550 110]);

c_KA = [subsysPath '/c_KA'];
c_n  = [subsysPath '/c_n'];
local_add_block("simulink/Sources/Constant", c_KA, "Value", "KA", "Position", [60 20 110 40]);
local_add_block("simulink/Sources/Constant", c_n,  "Value", "n",  "Position", [60 50 110 70]);

powA = [subsysPath '/A_pow_n'];
powKA = [subsysPath '/KA_pow_n'];
local_add_block("simulink/Math Operations/Math Function", powA,  "Operator", "pow", "Position", [160 80 210 120]);
local_add_block("simulink/Math Operations/Math Function", powKA, "Operator", "pow", "Position", [160 20 210 60]);

sumDen = [subsysPath '/Sum_den'];
local_add_block("simulink/Math Operations/Sum", sumDen, "Inputs", "++", "Position", [260 55 295 85]);

div = [subsysPath '/Divide'];
local_add_block("simulink/Math Operations/Divide", div, "Position", [400 80 450 120]);

rel = [subsysPath '/A_gt_KA'];
dispAct = [subsysPath '/Display_Activation'];
local_add_block("simulink/Logic and Bit Operations/Relational Operator", rel, "Operator", ">", "Position", [260 140 310 170]);
local_add_block("simulink/Sinks/Display", dispAct, "Position", [360 138 430 172]);

add_line(subsysPath, "A/1", "A_pow_n/1", "autorouting", "on");
add_line(subsysPath, "c_n/1", "A_pow_n/2", "autorouting", "on");
add_line(subsysPath, "c_KA/1", "KA_pow_n/1", "autorouting", "on");
add_line(subsysPath, "c_n/1",  "KA_pow_n/2", "autorouting", "on");
add_line(subsysPath, "KA_pow_n/1", "Sum_den/1", "autorouting", "on");
add_line(subsysPath, "A_pow_n/1",  "Sum_den/2", "autorouting", "on");
add_line(subsysPath, "A_pow_n/1", "Divide/1", "autorouting", "on");
add_line(subsysPath, "Sum_den/1", "Divide/2", "autorouting", "on");
add_line(subsysPath, "Divide/1", "Output/1", "autorouting", "on");
add_line(subsysPath, "A/1", "A_gt_KA/1", "autorouting", "on");
add_line(subsysPath, "c_KA/1", "A_gt_KA/2", "autorouting", "on");
add_line(subsysPath, "A_gt_KA/1", "Display_Activation/1", "autorouting", "on");
end

function h = local_add_block(src, dst, varargin)
try
    h = add_block(src, dst, varargin{:});
catch ME
    srcC = char(string(src));
    dstC = char(string(dst));
    msgC = ME.message;
    if isstring(msgC); msgC = char(msgC); end
    if ~ischar(msgC);  msgC = char(string(msgC)); end
    idC = ME.identifier;
    if isstring(idC); idC = char(idC); end
    if ~ischar(idC);  idC = char(string(idC)); end
    srcC = reshape(srcC(:), 1, []);
    dstC = reshape(dstC(:), 1, []);
    idC  = reshape(idC(:),  1, []);
    msgLines = cellstr(msgC);
    headLines = {
        'add_block 失败。'
        sprintf('  src(源库路径) = %s', srcC)
        sprintf('  dst(目标块路径) = %s', dstC)
        sprintf('  原始错误(%s):', idC)
    };
    fullMsg = strjoin([headLines; msgLines(:)], newline);
    error('build_modular_qs_simulink_model_hyst:add_block_failed', '%s', fullMsg);
end
end

function opts = local_parseNameValue(opts, varargin)
if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error("参数必须为 Name-Value 成对传入。");
end
for i = 1:2:numel(varargin)
    name = string(varargin{i});
    val = varargin{i+1};
    if ~isfield(opts, name)
        error("未知参数名：%s", name);
    end
    opts.(name) = val;
end
end

function local_initModelWorkspaceAndCallbacks(modelName, M, nTraits, opts)
mw = get_param(modelName, "ModelWorkspace");
try
    mw.clear;
catch
end

local_modelWorkspaceAssign(mw, "M", M);
local_modelWorkspaceAssign(mw, "nTraits", nTraits);
local_modelWorkspaceAssign(mw, "r", 0.65);
local_modelWorkspaceAssign(mw, "K", 1.0);
local_modelWorkspaceAssign(mw, "eta_game", 0.35);
local_modelWorkspaceAssign(mw, "omega0", 1.0);
local_modelWorkspaceAssign(mw, "epsN", 1e-9);

local_modelWorkspaceAssign(mw, "enableFoodLimit", logical(opts.enableFoodLimit));
local_modelWorkspaceAssign(mw, "foodAmbient", double(opts.foodAmbient));
local_modelWorkspaceAssign(mw, "foodAccessMin", min(1, max(0, double(opts.foodAccessMin))));
local_modelWorkspaceAssign(mw, "need_floor", double(opts.need_floor));
if isempty(opts.need_vec)
    n0 = ones(1, M);
else
    n0 = reshape(double(opts.need_vec), 1, []);
    if numel(n0) ~= M
        error("build_modular_qs_simulink_model_hyst:BadNeed", "need_vec 长度须等于 NumStrains (%d)。", M);
    end
end
local_modelWorkspaceAssign(mw, "need_vec", n0);

if isempty(opts.b_vec)
    % 默认略不对称：见文件头「备注」；nTraits>2 时用 linspace 拉开相邻性状权重
    if nTraits == 2
        b0 = [0.58, 0.36];
    else
        b0 = linspace(0.54, 0.36, nTraits);
    end
else
    b0 = reshape(double(opts.b_vec), 1, []);
    if numel(b0) ~= nTraits
        error("build_modular_qs_simulink_model_hyst:BadB", "b_vec 长度须等于 nTraits (%d)。", nTraits);
    end
end
if isempty(opts.c_vec)
    if nTraits == 2
        c0 = [0.24, 0.16];
    else
        c0 = linspace(0.23, 0.15, nTraits);
    end
else
    c0 = reshape(double(opts.c_vec), 1, []);
    if numel(c0) ~= nTraits
        error("build_modular_qs_simulink_model_hyst:BadC", "c_vec 长度须等于 nTraits (%d)。", nTraits);
    end
end
local_modelWorkspaceAssign(mw, "b_vec", b0);
local_modelWorkspaceAssign(mw, "c_vec", c0);
local_modelWorkspaceAssign(mw, "decepStrength", 1.0);

if isempty(opts.ProduceMatrix)
    produce = local_defaultProduceMatrix(M, nTraits);
else
    produce = double(opts.ProduceMatrix);
    if ~isequal(size(produce), [M, nTraits])
        error("build_modular_qs_simulink_model_hyst:BadProduce", ...
            "ProduceMatrix 须为 %d×%d（NumStrains×nTraits）。", M, nTraits);
    end
end
local_modelWorkspaceAssign(mw, "produce", produce);

if isempty(opts.kA_vec)
    kA = zeros(1, M);
    kA(1) = 0.1;
else
    kA = reshape(double(opts.kA_vec), 1, []);
    if numel(kA) ~= M
        error("build_modular_qs_simulink_model_hyst:BadKA", "kA_vec 长度须等于 NumStrains (%d)。", M);
    end
end
local_modelWorkspaceAssign(mw, "kA_vec", kA);

local_modelWorkspaceAssign(mw, "dA", 0.05);
local_modelWorkspaceAssign(mw, "delta_qs", 0.01);
local_modelWorkspaceAssign(mw, "KA", max(1e-6, double(opts.KA)));
local_modelWorkspaceAssign(mw, "n", max(1, round(double(opts.hillN))));
local_modelWorkspaceAssign(mw, "A0", 0);
local_modelWorkspaceAssign(mw, "qsBoost", double(opts.qsBoost));
local_modelWorkspaceAssign(mw, "c_signal", double(opts.c_signal));

KAbase = max(1e-6, double(opts.KA));
if double(opts.KA_on) > 0
    KAonV = max(1e-9, double(opts.KA_on));
else
    KAonV = 1.2 * KAbase;
end
if double(opts.KA_off) > 0
    KAoffV = max(1e-9, double(opts.KA_off));
else
    KAoffV = 0.7 * KAbase;
end
if KAoffV >= KAonV
    error("build_modular_qs_simulink_model_hyst:BadHystKA", ...
        "迟滞参数须满足 KA_off < KA_on；当前 KA_off=%g, KA_on=%g。", KAoffV, KAonV);
end
local_modelWorkspaceAssign(mw, "KA_on", KAonV);
local_modelWorkspaceAssign(mw, "KA_off", KAoffV);
local_modelWorkspaceAssign(mw, "k_hyst", max(0, double(opts.k_hyst)));
local_modelWorkspaceAssign(mw, "q0", min(1, max(0, double(opts.q0))));

local_modelWorkspaceAssign(mw, "N_pop", 0.2);
if isempty(opts.FracInit)
    frac = ones(1, M) / M;
else
    frac = reshape(double(opts.FracInit), 1, []);
    if numel(frac) ~= M
        error("build_modular_qs_simulink_model_hyst:BadFrac", "FracInit 长度须等于 NumStrains (%d)。", M);
    end
end
local_modelWorkspaceAssign(mw, "frac_init", frac);

xq = 0.2 * (frac / sum(frac));
for j = 1:M
    local_modelWorkspaceAssign(mw, sprintf("x0_%d", j), xq(j));
end

initParts = {
    'mw = get_param(bdroot,''ModelWorkspace''); '
    'evalin(mw,''xq = N_pop .* (frac_init ./ sum(frac_init));''); '
    };
for j = 1:M
    initParts{end+1} = sprintf('evalin(mw,''x0_%d = xq(%d);''); ', j, j); %#ok<AGROW>
end
set_param(modelName, "InitFcn", [initParts{:}]);
end

function produce = local_defaultProduceMatrix(M, nTraits)
% 默认：菌株 1 全合作；菌株 2..(nTraits+1) 对应「只欺骗性状 i」；其余为全不生产（纯搭便车）
produce = zeros(M, nTraits);
produce(1, :) = 1;
for i = 1:min(nTraits, M - 1)
    produce(i + 1, :) = 1;
    produce(i + 1, i) = 0;
end
for j = (nTraits + 2):M
    produce(j, :) = 0;
end
end

function local_modelWorkspaceAssign(mw, name, value)
nameC = char(string(name));
try
    mw.assignin(nameC, value);
catch
    if isnumeric(value) && isreal(value)
        evalin(mw, sprintf("%s = %s;", nameC, mat2str(value)));
    else
        evalin(mw, sprintf("%s = %s;", nameC, mat2str(value)));
    end
end
end

function [t, Ymat] = local_structPopToMatrix(s, M)
if ~isstruct(s) || ~isfield(s, "time") || ~isfield(s, "signals")
    t = [];
    Ymat = [];
    return;
end
t = s.time(:);
sig = s.signals;
if ~(isstruct(sig) && isfield(sig, "values"))
    Ymat = [];
    return;
end
y = squeeze(sig.values);
nt = numel(t);
if size(y, 1) == nt && size(y, 2) == M
    Ymat = y;
elseif numel(y) == nt * M
    Ymat = reshape(y, nt, M);
else
    Ymat = [];
end
end

function local_runDecepSweep(modelName, sweepVals, M)
sweepVals = sweepVals(:).';
mw = get_param(modelName, "ModelWorkspace");
n = numel(sweepVals);
stdN = nan(1, n);
meanFrac = nan(M, n);
for k = 1:n
    local_modelWorkspaceAssign(mw, "decepStrength", sweepVals(k));
    sim(modelName);
    if ~evalin("base", "exist('qs_sim_pop','var')")
        warning("build_modular_qs_simulink_model_hyst:NoLog", ...
            "未找到 qs_sim_pop。跳过 decepStrength=%g。", sweepVals(k));
        continue;
    end
    [t, Y] = local_structPopToMatrix(evalin("base", "qs_sim_pop"), M);
    if isempty(t) || size(Y, 2) ~= M
        warning("build_modular_qs_simulink_model_hyst:BadLog", "qs_sim_pop 维度异常，跳过。");
        continue;
    end
    if numel(t) < 5
        continue;
    end
    i0 = max(1, floor(0.7 * numel(t)));
    N = sum(Y, 2);
    stdN(k) = std(N(i0:end));
    Ns = sum(Y(i0:end, :), 1);
    meanFrac(:, k) = (Ns / max(sum(Ns), eps)).';
end
figure("Name", "QS 欺骗强度扫描（公共物品适应度）", "Color", "w");
subplot(2, 1, 1);
plot(sweepVals, stdN, "-o", "LineWidth", 1.5);
grid on;
xlabel("decepStrength（有效成本 c \times decepStrength）");
ylabel("末段 std(N)（N=\Sigma x_j）");
title("欺骗强度 vs 总种群波动");

subplot(2, 1, 2);
hold on;
cols = lines(M);
for j = 1:M
    plot(sweepVals, meanFrac(j, :), "-", "Color", cols(j,:), "LineWidth", 1.5, "DisplayName", sprintf("菌株 %d", j));
end
hold off;
ylim([0 1]);
grid on;
xlabel("decepStrength");
ylabel("稳态段平均频率");
title("各菌株相对占比");
legend("Location", "best");
sgtitle("公共物品博弈-多菌群：欺骗强度扫描");
end

function local_runNpopSweep(modelName, sweepVals, M)
sweepVals = sweepVals(:).';
mw = get_param(modelName, "ModelWorkspace");
n = numel(sweepVals);
stdN = nan(1, n);
meanFrac = nan(M, n);
for k = 1:n
    local_modelWorkspaceAssign(mw, "N_pop", sweepVals(k));
    sim(modelName);
    if ~evalin("base", "exist('qs_sim_pop','var')")
        warning("build_modular_qs_simulink_model_hyst:NoLog", "未找到 qs_sim_pop，跳过 N_pop=%g。", sweepVals(k));
        continue;
    end
    [t, Y] = local_structPopToMatrix(evalin("base", "qs_sim_pop"), M);
    if isempty(t) || size(Y, 2) ~= M
        continue;
    end
    if numel(t) < 5
        continue;
    end
    i0 = max(1, floor(0.7 * numel(t)));
    N = sum(Y, 2);
    stdN(k) = std(N(i0:end));
    Ns = sum(Y(i0:end, :), 1);
    meanFrac(:, k) = (Ns / max(sum(Ns), eps)).';
end
figure("Name", "QS N_{pop} 扫描（多菌群）", "Color", "w");
subplot(2, 1, 1);
plot(sweepVals, stdN, "-o", "LineWidth", 1.5);
grid on;
xlabel("N_{pop}");
ylabel("末段 std(N)");
title("总种群规模 vs 波动");

subplot(2, 1, 2);
hold on;
cols = lines(M);
for j = 1:M
    plot(sweepVals, meanFrac(j, :), "-", "Color", cols(j,:), "LineWidth", 1.5, "DisplayName", sprintf("菌株 %d", j));
end
hold off;
ylim([0 1]);
grid on;
xlabel("N_{pop}");
ylabel("稳态段平均频率");
legend("Location", "best");
sgtitle("公共物品博弈-多菌群：N_{pop} 扫描");
end

function local_runDualCommunityDeceptionSweep(opts, scriptDir)
%LOCAL_RUNDUALCOMMUNITYDECEPTIONSWEEP 四种交叉假设 × 4×4 产信号策略，双菌-双信号-双产物扫描
if ~isempty(scriptDir)
    addpath(scriptDir);
end

stratTick = {'无', '仅A1', '仅A2', 'A1+A2'};
Tend = max(5, double(opts.DualStopTime));
N0 = max(1e-6, double(opts.DualN0));
kBase = max(0, double(opts.DualBaseKA));
nH = max(1, round(double(opts.hillN)));
S0 = max(1e-9, double(opts.DualS0));
if isempty(opts.DualSInit) || ~(isnumeric(opts.DualSInit) || islogical(opts.DualSInit))
    Sinit = S0;
else
    Sinit = max(1e-9, double(opts.DualSInit));
end
Ainit = max(0, double(opts.DualAInit));
Binit = max(0, double(opts.DualBInit));

hypMat = [
    +1, +1
    +1, -1
    -1, +1
    -1, -1
    ];
hypLabels = {
    'H1: A2→B1促进 & A1→B2促进'
    'H2: A2→B1促进 & A1→B2抑制'
    'H3: A2→B1抑制 & A1→B2促进'
    'H4: A2→B1抑制 & A1→B2抑制'
    };

nHyp = size(hypMat, 1);
nStrat = 4;
nRun = nHyp * nStrat * nStrat;
Nt_ref = max(30, round(double(opts.DualNtRef)));
t_ref = linspace(0, Tend, Nt_ref).';
GnMat = nan(Nt_ref, nRun);
GbMat = nan(Nt_ref, nRun);
ResDotMat = nan(Nt_ref, nRun);
codeLabels = cell(nRun, 1);
d1_N1v = nan(nRun, 1);
d1_N2v = nan(nRun, 1);
d2_N1v = nan(nRun, 1);
d2_N2v = nan(nRun, 1);
d3_N1v = nan(nRun, 1);
d3_N2v = nan(nRun, 1);
passCntv = zeros(nRun, 1);
normMaxv = inf(nRun, 1);
stableAllv = false(nRun, 1);
tailFracStab = min(0.95, max(0.05, double(opts.DualStableTailFrac)));
eps1s = double(opts.DualStableEps1);
eps2s = double(opts.DualStableEps2);
eps3s = double(opts.DualStableEps3);
rows = table( ...
    zeros(nRun, 1), zeros(nRun, 1), zeros(nRun, 1), zeros(nRun, 1), ...
    zeros(nRun, 1), nan(nRun, 1), nan(nRun, 1), nan(nRun, 1), nan(nRun, 1), ...
    nan(nRun, 1), ...
    'VariableNames', {'hypothesis', 'stratN1', 'stratN2', 'signA2_B1', 'signA1_B2', ...
    'geomMeanN', 'geomMeanB', 'resTotal', 'stdNtot', 'lexRank'});

idx = 0;
for hi = 1:nHyp
    sA2B1 = hypMat(hi, 1);
    sA1B2 = hypMat(hi, 2);
    for a = 1:nStrat
        [kA1_N1, kA2_N1] = local_dualStratToRates(a, kBase);
        for b = 1:nStrat
            [kA1_N2, kA2_N2] = local_dualStratToRates(b, kBase);
            idx = idx + 1;
            p = local_dualBuildParamStruct(sA2B1, sA1B2, kA1_N1, kA2_N1, kA1_N2, kA2_N2, nH, opts);
            useHy = logical(opts.DualUseHysteresis);
            if useHy
                q01 = min(1, max(0, double(opts.DualHystq01)));
                q02 = min(1, max(0, double(opts.DualHystq02)));
                y0 = [N0; N0; Sinit; Ainit; Ainit; Binit; Binit; 0; q01; q02];
                odefun = @(t, y) dual_qs_community_rhs_hyst(t, y, p);
            else
                y0 = [N0; N0; Sinit; Ainit; Ainit; Binit; Binit; 0];
                odefun = @(t, y) dual_qs_community_rhs(t, y, p);
            end
            [t, y] = ode45(odefun, [0, Tend], y0, odeset("RelTol", 1e-4, "AbsTol", 1e-9));
            codeLabels{idx} = sprintf("H%d·%s·%s", hi, stratTick{a}, stratTick{b});
            if size(y, 1) < 5
                gmN = NaN;
                gmB = NaN;
                resT = NaN;
                stdNt = NaN;
            else
                smSt = local_dualPaperStabilityFromTrajectory(t, y, eps1s, eps2s, eps3s, tailFracStab);
                d1_N1v(idx) = smSt.d1_N1;
                d1_N2v(idx) = smSt.d1_N2;
                d2_N1v(idx) = smSt.d2_N1;
                d2_N2v(idx) = smSt.d2_N2;
                d3_N1v(idx) = smSt.d3_N1;
                d3_N2v(idx) = smSt.d3_N2;
                passCntv(idx) = smSt.passCountStable;
                normMaxv(idx) = smSt.normMaxPaper;
                stableAllv(idx) = smSt.stableAllPaper;
                i0 = max(1, floor(0.65 * size(y, 1))):size(y, 1);
                N1s = max(1e-12, y(i0, 1));
                N2s = max(1e-12, y(i0, 2));
                B1s = max(1e-12, y(i0, 6));
                B2s = max(1e-12, y(i0, 7));
                gmN = mean(sqrt(N1s .* N2s));
                gmB = mean(sqrt(B1s .* B2s));
                resT = y(end, 8);
                Ntot = y(i0, 1) + y(i0, 2);
                stdNt = std(Ntot);
                tcol = t(:);
                gn_t = sqrt(max(y(:, 1), 1e-12) .* max(y(:, 2), 1e-12));
                gb_t = sqrt(max(y(:, 6), 1e-12) .* max(y(:, 7), 1e-12));
                GnMat(:, idx) = interp1(tcol, gn_t(:), t_ref, "linear", NaN);
                GbMat(:, idx) = interp1(tcol, gb_t(:), t_ref, "linear", NaN);
                nT = numel(tcol);
                rd = zeros(nT, 1);
                for ii = 1:nT
                    if useHy
                        du = dual_qs_community_rhs_hyst(tcol(ii), y(ii, :).', p);
                    else
                        du = dual_qs_community_rhs(tcol(ii), y(ii, :).', p);
                    end
                    rd(ii) = du(8);
                end
                ResDotMat(:, idx) = interp1(tcol, rd, t_ref, "linear", NaN);
            end
            rows.hypothesis(idx) = hi;
            rows.stratN1(idx) = a;
            rows.stratN2(idx) = b;
            rows.signA2_B1(idx) = sA2B1;
            rows.signA1_B2(idx) = sA1B2;
            rows.geomMeanN(idx) = gmN;
            rows.geomMeanB(idx) = gmB;
            rows.resTotal(idx) = resT;
            rows.stdNtot(idx) = stdNt;
        end
    end
end

rows.d1_N1 = d1_N1v;
rows.d1_N2 = d1_N2v;
rows.d2_N1 = d2_N1v;
rows.d2_N2 = d2_N2v;
rows.d3_N1 = d3_N1v;
rows.d3_N2 = d3_N2v;
rows.passCountStable = passCntv;
rows.normMaxPaper = normMaxv;
rows.stableAllPaper = stableAllv;

i0ref = max(1, floor(0.7 * Nt_ref));
tailGn = mean(GnMat(i0ref:end, :), 1, "omitnan").';
tailGb = mean(GbMat(i0ref:end, :), 1, "omitnan").';
tailResDot = mean(ResDotMat(i0ref:end, :), 1, "omitnan").';
rows.geomMeanN = tailGn;
rows.geomMeanB = tailGb;

rows.geomMeanN_h = nan(nRun, 1);
rows.geomMeanB_h = nan(nRun, 1);
rows.resTotal_h = nan(nRun, 1);
for hi = 1:nHyp
    ix = find(rows.hypothesis == hi);
    if isempty(ix)
        continue;
    end
    rows.geomMeanN_h(ix) = local_minmax01(rows.geomMeanN(ix));
    rows.geomMeanB_h(ix) = local_minmax01(rows.geomMeanB(ix));
    rows.resTotal_h(ix) = 1 - local_minmax01(rows.resTotal(ix));
end
rows.econGeomScore = (rows.geomMeanN_h + rows.geomMeanB_h + rows.resTotal_h) / 3;

threshMode = char(lower(strtrim(string(opts.DeceptionEconThreshMode))));
if isempty(threshMode)
    threshMode = 'median16';
end
passThreshGeomN = false(nRun, 1);
passThreshGeomB = false(nRun, 1);
passThreshRes = false(nRun, 1);
passCountEcon = zeros(nRun, 1);
econThreshByHypothesis = repmat(struct("thGeomN", nan, "thGeomB", nan, "thResTotal", nan), nHyp, 1);
switch threshMode
    case 'none'
        passThreshGeomN(:) = true;
        passThreshGeomB(:) = true;
        passThreshRes(:) = true;
        passCountEcon(:) = 3;
    case 'median16'
        for hi = 1:nHyp
            ix = find(rows.hypothesis == hi);
            if isempty(ix)
                continue;
            end
            thN = median(rows.geomMeanN(ix), "omitnan");
            thB = median(rows.geomMeanB(ix), "omitnan");
            thR = median(rows.resTotal(ix), "omitnan");
            econThreshByHypothesis(hi).thGeomN = thN;
            econThreshByHypothesis(hi).thGeomB = thB;
            econThreshByHypothesis(hi).thResTotal = thR;
            for k = 1:numel(ix)
                j = ix(k);
                gnj = rows.geomMeanN(j);
                gbj = rows.geomMeanB(j);
                rj = rows.resTotal(j);
                passThreshGeomN(j) = isfinite(thN) && isfinite(gnj) && gnj >= thN;
                passThreshGeomB(j) = isfinite(thB) && isfinite(gbj) && gbj >= thB;
                passThreshRes(j) = isfinite(thR) && isfinite(rj) && rj <= thR;
                passCountEcon(j) = passThreshGeomN(j) + passThreshGeomB(j) + passThreshRes(j);
            end
        end
    case 'fixed'
        thN0 = double(opts.DeceptionThreshGeomMeanN);
        thB0 = double(opts.DeceptionThreshGeomMeanB);
        thR0 = double(opts.DeceptionThreshResTotal);
        actN = isfinite(thN0);
        actB = isfinite(thB0);
        actR = isfinite(thR0);
        if ~(actN || actB || actR)
            warning("build_modular_qs_simulink_model_hyst:DeceptionThresh", ...
                "DeceptionEconThreshMode=fixed 但三门坎均为 NaN，退回 none（仅用组内归一字典序）。");
            threshMode = 'none';
            passThreshGeomN(:) = true;
            passThreshGeomB(:) = true;
            passThreshRes(:) = true;
            passCountEcon(:) = 3;
        else
            for j = 1:nRun
                c = 0;
                gnj = rows.geomMeanN(j);
                gbj = rows.geomMeanB(j);
                rj = rows.resTotal(j);
                if actN
                    passThreshGeomN(j) = isfinite(gnj) && gnj >= thN0;
                    c = c + passThreshGeomN(j);
                else
                    passThreshGeomN(j) = true;
                end
                if actB
                    passThreshGeomB(j) = isfinite(gbj) && gbj >= thB0;
                    c = c + passThreshGeomB(j);
                else
                    passThreshGeomB(j) = true;
                end
                if actR
                    passThreshRes(j) = isfinite(rj) && rj <= thR0;
                    c = c + passThreshRes(j);
                else
                    passThreshRes(j) = true;
                end
                passCountEcon(j) = c;
            end
        end
    otherwise
        error("build_modular_qs_simulink_model_hyst:BadDeceptionEconThreshMode", ...
            "DeceptionEconThreshMode 须为 median16、fixed 或 none。");
end

rows.passThreshGeomN = passThreshGeomN;
rows.passThreshGeomB = passThreshGeomB;
rows.passThreshRes = passThreshRes;
rows.passCountEcon = passCountEcon;

gmN = rows.geomMeanN;
gmB = rows.geomMeanB;
resC = rows.resTotal;
ok = isfinite(gmN) & isfinite(gmB) & isfinite(resC) ...
    & isfinite(rows.geomMeanN_h) & isfinite(rows.geomMeanB_h) & isfinite(rows.resTotal_h) ...
    & isfinite(rows.econGeomScore);
if ~any(ok)
    warning("build_modular_qs_simulink_model_hyst:DualSweepEmpty", "双菌扫描无有效解，跳过保存与作图。");
    return;
end

sortVars = {'econGeomScore', 'stratN1', 'stratN2'};
sortDirs = {'descend', 'ascend', 'ascend'};
rows.lexRank = nan(height(rows), 1);
for hi = 1:nHyp
    ix = find(rows.hypothesis == hi);
    if isempty(ix)
        continue;
    end
    valid = ok(ix);
    ixGood = ix(valid);
    ixBad = ix(~valid);
    if ~isempty(ixBad)
        rows.lexRank(ixBad) = nStrat * nStrat + 1;
    end
    if isempty(ixGood)
        continue;
    end
    Tg = rows(ixGood, :);
    [~, I] = sortrows(Tg, sortVars, sortDirs);
    for j = 1:numel(I)
        rows.lexRank(ixGood(I(j))) = j;
    end
end

matPath = char(string(opts.DualResultsMat));
if isempty(strtrim(matPath))
    matPath = "dual_community_deception_results.mat";
end
if ~local_isAbsolutePath(matPath) && ~isempty(strtrim(scriptDir))
    matPath = fullfile(scriptDir, matPath);
end
nPerHyp = nStrat * nStrat;
stratPairLabels = cell(nPerHyp, 1);
idxB = 0;
for a = 1:nStrat
    for b = 1:nStrat
        idxB = idxB + 1;
        stratPairLabels{idxB} = sprintf("%s|%s", stratTick{a}, stratTick{b});
    end
end
if logical(opts.DualUseHysteresis)
    dualRhsIdStr = "dual_qs_community_rhs_hyst";
else
    dualRhsIdStr = "dual_qs_community_rhs";
end
dualSweepMeta = struct( ...
    "nRun", nRun, "nHyp", nHyp, "nStrat", nStrat, ...
    "Nt_ref", Nt_ref, "Tend", Tend, "tailFrac", 0.3, ...
    "i0ref", i0ref, ...
    "stabilityEps1", eps1s, "stabilityEps2", eps2s, "stabilityEps3", eps3s, ...
    "stabilityTailFrac", tailFracStab, ...
    "stabilityNote", "Table1: d1=|N(tL)-N(tL-1)|<e1; d2=std(N tail)<e2; d3=1/N(tL)<e3（仅诊断，不参与 lexRank）", ...
    "econThreshMode", threshMode, ...
    "econThreshByHypothesis", econThreshByHypothesis, ...
    "evaluationRank", "per-H: econGeomScore=(N_h+B_h+res_h)/3 desc, strat asc; passCountEcon 仅诊断", ...
    "usedHysteresisDual", logical(opts.DualUseHysteresis), ...
    "dualRhsId", char(dualRhsIdStr) ...
    );
n16 = sprintf("策略索引（1-%d）", nPerHyp);
xLabBarStrat = "策略编码（N1|N2）";
figPaths = local_exportDualSweepFigures24(scriptDir, opts, hypLabels, nHyp, nPerHyp, ...
    t_ref, GnMat, GbMat, ResDotMat, tailGn, tailGb, tailResDot, stratPairLabels, n16, xLabBarStrat);
if numel(figPaths.files) > 0
    dualSweepMeta.figureExportDir = figPaths.exportDir;
    dualSweepMeta.exportedFigureFiles = figPaths.files;
end
bestPaper = [];
for hi = 1:nHyp
    ix = find(rows.hypothesis == hi);
    if isempty(ix)
        continue;
    end
    subP = rows(ix, :);
    localOk = ok(ix);
    subV = subP(localOk, :);
    if height(subV) < 1
        continue;
    end
    subSorted = sortrows(subV, sortVars, sortDirs);
    if hi == 1
        bestPaper = subSorted(1, :);
    else
        bestPaper = [bestPaper; subSorted(1, :)]; %#ok<AGROW>
    end
end
dualSweepMeta.stabilityBestByHypothesis = bestPaper;

save(char(matPath), "rows", "hypLabels", "stratTick", "stratPairLabels", "Tend", "kBase", "nH", "S0", "opts", ...
    "t_ref", "GnMat", "GbMat", "ResDotMat", "codeLabels", ...
    "tailGn", "tailGb", "tailResDot", "dualSweepMeta", "-v7.3");
fprintf("双菌欺骗扫描已写入：%s\n", char(matPath));
if numel(figPaths.files) > 0
    fprintf("图表已导出（共 %d 个文件）：%s\n", numel(figPaths.files), char(figPaths.exportDir));
    fprintf("  （双菌 ODE：%s；迟滞=%d）\n", dualSweepMeta.dualRhsId, dualSweepMeta.usedHysteresisDual);
end

fprintf("\n=== 综合评价（组内归一三项的算术平均 econGeomScore）：各假设 lexRank=1 ===\n");
fprintf("原始指标：geomMeanN、geomMeanB、resTotal；门槛模式「%s」（passCountEcon 仅诊断）\n", threshMode);
if strcmp(threshMode, 'median16')
    fprintf("门槛：各假设 16 组内中位数（N、B 为 ≥；累积资源为 ≤）→ passCountEcon=0..3\n");
elseif strcmp(threshMode, 'fixed')
    fprintf("门槛：固定 DeceptionThresh*（NaN 条目不参与 passCountEcon 计数）\n");
else
    fprintf("模式 none：不过门槛比较；passCountEcon=3\n");
end
fprintf("排序：econGeomScore↓（=(N_h+B_h+res_h)/3）→ strat↑\n");
fprintf("（每假设 16 组内：N_h、B_h 为 min-max(geomMeanN/geomMeanB)；res_h=1−minmax(resTotal)）\n");
fprintf("（稳态诊断 d1/d2/d3 仍写入 mat，不参与 lexRank；论文阈 d1<%.1e；d2(末%.0f%%)<%.1e；d3<%.0f）\n", ...
    eps1s, 100 * tailFracStab, eps2s, eps3s);
nEconGates = 3;
if strcmp(threshMode, 'fixed')
    nEconGates = sum([isfinite(double(opts.DeceptionThreshGeomMeanN)), ...
        isfinite(double(opts.DeceptionThreshGeomMeanB)), ...
        isfinite(double(opts.DeceptionThreshResTotal))]);
    if nEconGates < 1
        nEconGates = 3;
    end
end
for hi = 1:nHyp
    ix = find(rows.hypothesis == hi);
    if isempty(ix)
        continue;
    end
    subP = rows(ix, :);
    localOk = ok(ix);
    subV = subP(localOk, :);
    if height(subV) < 1
        continue;
    end
    subSorted = sortrows(subV, sortVars, sortDirs);
    r = subSorted(1, :);
    if strcmp(threshMode, 'none')
        fprintf("%s\n  -> 最优：N1=%s N2=%s | lexRank=1/%d | econGeomScore=%.4g\n", ...
            hypLabels{hi}, stratTick{r.stratN1}, stratTick{r.stratN2}, height(subV), r.econGeomScore);
    else
        fprintf("%s\n  -> 最优：N1=%s N2=%s | lexRank=1/%d | econGeomScore=%.4g | 经济过线=%d/%d [N=%d B=%d res=%d]\n", ...
            hypLabels{hi}, stratTick{r.stratN1}, stratTick{r.stratN2}, height(subV), r.econGeomScore, ...
            r.passCountEcon, nEconGates, logical(r.passThreshGeomN), logical(r.passThreshGeomB), logical(r.passThreshRes));
    end
    if strcmp(threshMode, 'median16') && hi <= numel(econThreshByHypothesis)
        eth = econThreshByHypothesis(hi);
        fprintf("     本假设门槛：geomN≥%.4g geomB≥%.4g res≤%.4g\n", eth.thGeomN, eth.thGeomB, eth.thResTotal);
    end
    fprintf("     原始 geomN=%.4g geomB=%.4g res=%.4g | 归一 h: N_h=%.3f B_h=%.3f res_h=%.3f | econGeom=%.4g\n", ...
        r.geomMeanN, r.geomMeanB, r.resTotal, r.geomMeanN_h, r.geomMeanB_h, r.resTotal_h, r.econGeomScore);
    fprintf("     稳态诊断 passStable=%d/6 stableAll=%d（不参与排序）\n", ...
        r.passCountStable, logical(r.stableAllPaper));
end
fprintf("（无效/缺数据策略 lexRank=%d）\n", nStrat * nStrat + 1);

end

function [k1, k2] = local_dualStratToRates(stratId, base)
switch stratId
    case 1
        k1 = 0;
        k2 = 0;
    case 2
        k1 = base;
        k2 = 0;
    case 3
        k1 = 0;
        k2 = base;
    case 4
        k1 = base;
        k2 = base;
    otherwise
        error("build_modular_qs_simulink_model_hyst:BadStrat", "stratId 须为 1..4。");
end
end

function p = local_dualBuildParamStruct(sA2B1, sA1B2, kA1_N1, kA2_N1, kA1_N2, kA2_N2, nH, opts)
p.D = max(0, double(opts.DualD));
p.S0 = max(1e-12, double(opts.DualS0));
p.KS = max(1e-9, double(opts.DualKS));
p.mu_max1 = max(0, double(opts.DualMuMax1));
p.mu_max2 = max(0, double(opts.DualMuMax2));
p.gamma1 = max(1e-9, double(opts.DualGamma1));
p.gamma2 = max(1e-9, double(opts.DualGamma2));
p.KB_max1 = max(0, double(opts.DualKBmax1));
p.KB_max2 = max(0, double(opts.DualKBmax2));
p.omega_max = max(0, double(opts.DualOmegaMax));
p.K_omega = max(1e-9, double(opts.DualKOmega));
p.n_omega = max(1, round(double(opts.DualNOmega)));
p.K_A1_B1 = max(1e-12, double(opts.DualK_A1_B1));
p.K_A2_B1 = max(1e-12, double(opts.DualK_A2_B1));
p.K_A1_B2 = max(1e-12, double(opts.DualK_A1_B2));
p.n = nH;
p.delta_qs = 0.01;
p.epsN = 1e-9;
p.sign_A2_on_B1 = sA2B1;
p.sign_A1_on_B2 = sA1B2;
p.kA1_N1 = kA1_N1;
p.kA2_N1 = kA2_N1;
p.kA1_N2 = kA1_N2;
p.kA2_N2 = kA2_N2;
p.metCostA = max(0, double(opts.DualMetCostA));
p.metCostB1 = max(0, double(opts.DualMetCostB1));
p.metCostB2 = max(0, double(opts.DualMetCostB2));
p.costA1 = double(opts.DualCostA1);
p.costA2 = double(opts.DualCostA2);
p.costB1 = double(opts.DualCostB1);
p.costB2 = double(opts.DualCostB2);
p.Ainflux1 = max(0, double(opts.DualAinflux1));
p.Ainflux2 = max(0, double(opts.DualAinflux2));

Kr1 = max(1e-12, p.K_A1_B1);
Kr2 = max(1e-12, p.K_A2_B1);
on1 = double(opts.DualHystKAonA1);
off1 = double(opts.DualHystKAoffA1);
on2 = double(opts.DualHystKAonA2);
off2 = double(opts.DualHystKAoffA2);
if on1 > 0
    KAon1 = max(1e-12, on1);
else
    KAon1 = 1.2 * Kr1;
end
if off1 > 0
    KAoff1 = max(1e-12, off1);
else
    KAoff1 = 0.7 * Kr1;
end
if on2 > 0
    KAon2 = max(1e-12, on2);
else
    KAon2 = 1.2 * Kr2;
end
if off2 > 0
    KAoff2 = max(1e-12, off2);
else
    KAoff2 = 0.7 * Kr2;
end
if KAoff1 >= KAon1
    error("build_modular_qs_simulink_model_hyst:BadDualHystA1", ...
        "A1 迟滞须 KA_off < KA_on；当前 KA_off=%g, KA_on=%g。", KAoff1, KAon1);
end
if KAoff2 >= KAon2
    error("build_modular_qs_simulink_model_hyst:BadDualHystA2", ...
        "A2 迟滞须 KA_off < KA_on；当前 KA_off=%g, KA_on=%g。", KAoff2, KAon2);
end
p.k_hyst_A1 = max(0, double(opts.DualHystRateA1));
p.k_hyst_A2 = max(0, double(opts.DualHystRateA2));
p.KA_on_A1 = KAon1;
p.KA_off_A1 = KAoff1;
p.KA_on_A2 = KAon2;
p.KA_off_A2 = KAoff2;
end

function z = local_minmax01(x)
x = x(:);
xf = x(isfinite(x));
if isempty(xf)
    z = NaN(size(x));
    return;
end
mn = min(xf);
mx = max(xf);
if (~(isfinite(mn) && isfinite(mx))) || abs(mx - mn) < 1e-15
    z = 0.5 * ones(size(x));
else
    z = (x - mn) ./ (mx - mn);
    z(~isfinite(x)) = NaN;
end
end

function tf = local_isAbsolutePath(p)
p = char(string(p));
if isempty(p)
    tf = false;
    return;
end
if p(1) == "/" || p(1) == "\"
    tf = true;
    return;
end
if ispc && numel(p) >= 2 && p(2) == ":"
    tf = true;
    return;
end
if strncmp(p, '\\', 2)
    tf = true;
    return;
end
tf = false;
end

function local_plotHeatBarDual(figName, argv)
%LOCAL_PLOTHEATBARDUAL 与 compare_three_strain_topologies.local_plotHeatBar 相同版式：
%   上图 imagesc(时间 × 情形)；下图末段均值柱状图。
%   argv = {t_ref, Zmat, tailVec, codeLabels, xlab, ylabHeat, cbLabel, ylabBar [, xlabelBar]}
if nargin < 2 || ~iscell(argv) || numel(argv) < 8 %#ok<*ISCELL>
    error("build_modular_qs_simulink_model_hyst:HeatBarArgs", ...
        "local_plotHeatBarDual 至少需要 (figName, {t_ref, Zmat, tailVec, codeLabels, xlab, ylabHeat, cbLabel, ylabBar})。");
end
[t_ref, Zmat, tailVec, codeLabels, xlabTxt, ylabHeatTxt, cbLabelTxt, ylabBarTxt] = argv{1:8};
if numel(argv) >= 9
    xlabelBarTxt = argv{9};
else
    xlabelBarTxt = "策略（N1|N2）";
end
figure("Name", figName, "Color", "w", "Position", [40 40 1120 700]);
subplot(2, 1, 1);
imagesc(t_ref, 1:size(Zmat, 2), Zmat.');
axis xy;
try %#ok<TRYNC>
    colormap(gca, parula);
catch %#ok<CTCH>
    colormap(gca, jet);
end
cb = colorbar;
cb.Label.String = char(string(cbLabelTxt));
xlabel(char(string(xlabTxt)));
ylabel(char(string(ylabHeatTxt)));
title("热图（纵轴：策略索引；横轴：时间）");

subplot(2, 1, 2);
try %#ok<TRYNC>
    bar(tailVec, "FaceColor", [0.38 0.55 0.78]);
catch %#ok<CTCH>
    bar(tailVec);
end
nB = numel(tailVec);
try %#ok<TRYNC>
    set(gca, "XTick", 1:nB, "XTickLabel", codeLabels, "XTickLabelRotation", 90);
catch %#ok<CTCH>
    set(gca, "XTick", 1:nB, "XTickLabel", codeLabels, "XTickLabelRotation", 90);
end
grid on;
xlabel(char(string(xlabelBarTxt)));
ylabel(char(string(ylabBarTxt)));
title("末段均值（后 30% 时间窗）");
sgtitle(figName);
end

function figPaths = local_exportDualSweepFigures24(scriptDir, opts, hypLabels, nHyp, nPerHyp, ...
    t_ref, GnMat, GbMat, ResDotMat, tailGn, tailGb, tailResDot, stratPairLabels, ylabIdxStr, xLabBarStrat)
%LOCAL_EXPORTDUALSWEEPFIGURES24 4×6 张图：每假设 3 指标 ×（热图+柱图），Invisible，写入 figure 目录
figPaths = struct("exportDir", "", "files", {{}});
if ~logical(opts.DualSaveFigures)
    return;
end
dirRel = char(string(opts.DualFigureExportDir));
if isempty(strtrim(dirRel))
    dirRel = "figure";
end
if local_isAbsolutePath(dirRel)
    figRoot = dirRel;
else
    if isempty(strtrim(scriptDir))
        figRoot = dirRel;
    else
        figRoot = fullfile(scriptDir, dirRel);
    end
end
if ~isfolder(figRoot)
    mkdir(figRoot);
end
res = max(72, round(double(opts.DualFigureResolution)));
fmt = lower(char(string(opts.DualFigureFormat)));
if isempty(fmt)
    fmt = "png";
end
oldVis = get(0, "DefaultFigureVisible");
set(0, "DefaultFigureVisible", "off");
filesOut = {};
try
    for hi = 1:nHyp
        j0 = (hi - 1) * nPerHyp;
        cols = j0 + (1:nPerHyp);
        GnS = GnMat(:, cols);
        GbS = GbMat(:, cols);
        RdS = ResDotMat(:, cols);
        tg = tailGn(cols);
        tb = tailGb(cols);
        tr = tailResDot(cols);
        hypTitle = hypLabels{hi};
        filesOut{end+1} = local_dualExportOneHeatmap(figRoot, hi, "geomN", t_ref, GnS, ylabIdxStr, ...
            "sqrt(N1·N2)", "几何平均菌量 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneBar(figRoot, hi, "geomN", tg, stratPairLabels, xLabBarStrat, ...
            "mean(sqrt(N1·N2)) 后30%", "几何平均菌量 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneHeatmap(figRoot, hi, "geomB", t_ref, GbS, ylabIdxStr, ...
            "sqrt(B1·B2)", "几何平均产物 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneBar(figRoot, hi, "geomB", tb, stratPairLabels, xLabBarStrat, ...
            "mean(sqrt(B1·B2)) 后30%", "几何平均产物 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneHeatmap(figRoot, hi, "resRate", t_ref, RdS, ylabIdxStr, ...
            "dR/dt", "资源消耗率 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneBar(figRoot, hi, "resRate", tr, stratPairLabels, xLabBarStrat, ...
            "mean(dR/dt) 后30%", "资源消耗率 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
    end
catch ME
    set(0, "DefaultFigureVisible", oldVis);
    rethrow(ME);
end
set(0, "DefaultFigureVisible", oldVis);
figPaths.exportDir = figRoot;
figPaths.files = filesOut(:);
end

function outPath = local_dualExportOneHeatmap(figRoot, hi, tag, t_ref, Zmat, ylabIdxStr, cbLabel, ttlLine, hypTitle, res, fmt)
f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [80 80 1000 440]);
try %#ok<TRYNC>
    ax = axes(f);
    imagesc(ax, t_ref, 1:size(Zmat, 2), Zmat.');
    axis(ax, "xy");
    try %#ok<TRYNC>
        colormap(ax, parula);
    catch %#ok<CTCH>
        colormap(ax, jet);
    end
    cb = colorbar(ax);
    cb.Label.String = char(string(cbLabel));
    xlabel(ax, "时间");
    ylabel(ax, ylabIdxStr);
    title(ax, {char(string(hypTitle)), ttlLine}, "Interpreter", "none");
    outPath = fullfile(figRoot, sprintf("H%d_%s_heatmap.%s", hi, tag, fmt));
    local_dualTryExportgraphics(f, outPath, res);
catch ME %#ok<NASGU>
    close(f);
    rethrow(ME);
end
close(f);
end

function outPath = local_dualExportOneBar(figRoot, hi, tag, tailVec, stratPairLabels, xLabBarStrat, ylabBar, ttlLine, hypTitle, res, fmt)
f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [80 80 1200 480]);
try %#ok<TRYNC>
    ax = axes(f);
    bar(ax, tailVec, "FaceColor", [0.38 0.55 0.78]);
    nB = numel(tailVec);
    set(ax, "XTick", 1:nB, "XTickLabel", stratPairLabels, "XTickLabelRotation", 90);
    grid(ax, "on");
    xlabel(ax, char(string(xLabBarStrat)));
    ylabel(ax, ylabBar);
    title(ax, {char(string(hypTitle)), ttlLine}, "Interpreter", "none");
    outPath = fullfile(figRoot, sprintf("H%d_%s_bar.%s", hi, tag, fmt));
    local_dualTryExportgraphics(f, outPath, res);
catch ME %#ok<NASGU>
    close(f);
    rethrow(ME);
end
close(f);
end

function local_dualTryExportgraphics(f, outPath, res)
try %#ok<TRYNC>
    exportgraphics(f, outPath, "Resolution", res, "BackgroundColor", "w");
catch %#ok<CTCH>
    saveas(f, outPath);
end
end

function sm = local_dualPaperStabilityFromTrajectory(t, y, eps1, eps2, eps3, tailFrac)
%LOCAL_DUALPAPERSTABILITYFROMTRAJECTORY Nat Commun 2021 Table 1 风格距离（两菌 N1、N2）
%   d1,x = |Nx(tL) - Nx(tL-1)|,  d2,x = std(Nx 末段),  d3,x = 1/Nx(tL)
sm = struct( ...
    "d1_N1", NaN, "d1_N2", NaN, "d2_N1", NaN, "d2_N2", NaN, "d3_N1", NaN, "d3_N2", NaN, ...
    "passCountStable", 0, "normMaxPaper", Inf, "stableAllPaper", false);
if isempty(t) || isempty(y) || size(y, 1) < 3
    return;
end
nt = size(y, 1);
N1 = y(:, 1);
N2 = y(:, 2);
d1_N1 = abs(N1(end) - N1(end - 1));
d1_N2 = abs(N2(end) - N2(end - 1));
i0 = max(2, min(nt - 1, floor((1 - tailFrac) * nt)));
idxTail = i0:nt;
d2_N1 = std(N1(idxTail), 0, "omitnan");
d2_N2 = std(N2(idxTail), 0, "omitnan");
if ~(isfinite(d2_N1) && isfinite(d2_N2))
    d2_N1 = 0;
    d2_N2 = 0;
end
d3_N1 = 1 / max(real(N1(end)), 1e-30);
d3_N2 = 1 / max(real(N2(end)), 1e-30);
e1 = max(eps1, 1e-30);
e2 = max(eps2, 1e-30);
e3 = max(eps3, 1e-30);
r = [d1_N1 / e1, d1_N2 / e1, d2_N1 / e2, d2_N2 / e2, d3_N1 / e3, d3_N2 / e3];
pass = [d1_N1 < eps1, d1_N2 < eps1, d2_N1 < eps2, d2_N2 < eps2, d3_N1 < eps3, d3_N2 < eps3];
sm.d1_N1 = d1_N1;
sm.d1_N2 = d1_N2;
sm.d2_N1 = d2_N1;
sm.d2_N2 = d2_N2;
sm.d3_N1 = d3_N1;
sm.d3_N2 = d3_N2;
sm.passCountStable = sum(pass);
sm.normMaxPaper = max(r);
sm.stableAllPaper = all(pass);
end
