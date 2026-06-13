function modelName = build_modular_qs_simulink_model_triple(varargin)
%BUILD_MODULAR_QS_SIMULINK_MODEL_TRIPLE 本文件为 build_modular_qs_simulink_model 的副本：Simulink MSPG 同原版；
% 三菌群落扫描使用 triple_qs_community_rhs（见 triple_qs_community_rhs.m）。
%
% 【三信号 A1–A3、三群体 D1–D3（产物 B1–B3）】群落欺骗扫描：枚举 triple_qs_topology18.m 中 **18 种**调控拓扑（A1 行对 B1–B3 的 ±1/0 母库）。
%   每种拓扑下 (N1,N2,N3) 产信号策略各取 strat∈{1..8}，即 (kA1,kA2,kA3)∈{无,仅A1,仅A2,仅A3,A1+A2,A1+A3,A2+A3,全产}×DualBaseKA，
%   默认 TripleProductionSweepMode='constrained138'：仅扫 **138** 条标号策略/拓扑 → 18×138，写入 rows.prodOrbit8(1..8)；
%   并导出横轴为 **T1–T8**（= prodOrbit8 轨）的聚合热图 `*_orbit8T_heatmap`。
%   全空间 8^3=512 时传 TripleProductionSweepMode='full512'；随机子集用 'random512'（见文件头）。
%   Name-Value「TripleOwnBPromotesNi」,true：本菌产物 B_i 对 N_i 为 +ω(B_i) 促进项（默认 −ω 为抑制/代价）；**非迟滞**扫描时启用「超速档」：RelTol 5e-2、Tend×0.32、Nt_ref≤48、ResDot≤120、**ode15s**、MaxStep≈Tend/28。
%   「TripleSweepOdeFastWhenOwnBPromotesNi」,true（默认）：促进扫描时启用上述激进档（可关则退回慢积分）。
%   「TripleSweepFastApprox」,false（默认）：true 时**无论是否** OwnBPromotesNi，均启用与「仅 FastApprox」相同的快速近似
%     （RelTol 8e-3、Tend×0.5、Nt_ref≤72、ResDot≤256、MaxStep≈Tend/28、ode45）；与 OwnBPromotesNi 同时为 true 时以**超速促进档**为准。
%   「TripleSweepEchoCmd」,true（默认）：扫描时在命令行打印与 waitbar 同步的进度；无图形或 waitbar 失败时仍可看到推进。
%   组内字典序仍输出 lexRank=1 的最优「欺骗结构」；控制台另打印各拓扑最优摘要。
%
% 【兼容旧版 iv】Name-Value「TripleSweepLegacyIv」,true 时恢复：A1⊣B1B2、A2⊣B3、仅 kA1/kA2、4^3=64 组。
%
% 【欺骗结构（默认 138 组 constrained138；full512 为 8^3）】紧凑码 **i-j-k**（i,j,k∈0..7 为 A1/A2/A3 的 bitmask）；旧 64 组为 0..3。
%
% 可能的生物学欺骗类型（列举）：(1) N1 停产 A2→A2 不足，B3 合成少被抑制弱，N3 易受益但 N2 负担可能上升；
% (2) N2 停 A1 或停 A2 或全停（搭便车）；(3) N3 停 A1；(4) 组合型社会欺骗（多菌同时减产）。
% 最优策略按组内标量 **econGeomScore** = (geomMeanN_h + geomMeanB_h + resTotal_h) / 3（三项算术平均）降序，平局 strat 升序；
% geomMeanN/B 为三菌末段几何平均 (N1·N2·N3)^(1/3)、(B1·B2·B3)^(1/3)；_h 为同拓扑组内 min-max，resTotal_h=1−minmax(res)。
% passCountEcon（门槛过线数）仍写入结果，仅诊断，不参与 lexRank。
%
%   调用：build_modular_qs_simulink_model_triple("RunTripleCommunityDeceptionSweep",true)
%   定标：沿用 Dual* 名前缀参数；三菌第三通道用 DualMuMax3、DualGamma3、DualKBmax3、DualMetCostB3、
%   DualCostB3、DualK_A2_B3（A2 抑制 B3 的 Hill 半饱和）；结果默认 triple_community_deception_results.mat。
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
%
% 依赖同目录下 qs_mspg_rhs_impl.m、qs_mspg_rhs_component.m（每状态一个 MATLAB Fcn 标量输出）；
% 构建时会 addpath 本脚本目录。
%
% 用法：
%   build_modular_qs_simulink_model_triple
%   build_modular_qs_simulink_model_triple("ModelName","qs_modular_mspg_triple")
%   build_modular_qs_simulink_model_triple("OpenModel",true,"RunSim",true)
%   build_modular_qs_simulink_model_triple("RunTripleCommunityDeceptionSweep",true,"OpenModel",false,"SaveModel",false)
%
% 说明：求解器 variable-step/ode45；参数在 Model Workspace；InitFcn 根据 N_pop、frac_init 写 x0_1..x0_M

scriptDir = fileparts(mfilename("fullpath"));
if ~isempty(scriptDir)
    addpath(scriptDir);
end

opts = struct( ...
    "ModelName", "qs_modular_mspg_triple", ...  % 与原版 Simulink 模型名区分
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
    "RunTripleCommunityDeceptionSweep", false, ...
    "DualStopTime", 120, ...
    "DualN0", 0.12, ...                % N1、N2、N3 初值（各，无量纲丰度）
    "DualS0", 1.0, ...                 % 恒化器无量纲营养上界 S0（入流浓度 / 尺度）
    "DualSInit", [], ...               % 空则 = DualS0
    "DualAInit", 0.02, ...             % A1、A2 初值（与 Hill 半饱和同量级便于辨识）
    "DualBInit", 1e-6, ...             % B1、B2、B3 初值
    "DualBaseKA", 0.09, ...            % 开启某信号通道时的 per-capita 合成系数（写入 kA*_N*）
    "DualD", 0.07, ...                 % 稀释率 D（与论文 D h^{-1} 同角色；此处与 t 无量纲一致）
    "DualKS", 0.22, ...                 % Monod 半饱和（无量纲 S）
    "DualMuMax1", 0.52, ...
    "DualMuMax2", 0.48, ...
    "DualMuMax3", 0.46, ...
    "DualGamma1", 1.1, ...             % 产量系数 gamma（越大则同等 mu 耗 S 越少）
    "DualGamma2", 1.1, ...
    "DualGamma3", 1.1, ...
    "DualKBmax1", 0.32, ...            % B1 最大合成率尺度 KB_max,1
    "DualKBmax2", 0.28, ...
    "DualKBmax3", 0.26, ...
    "DualOmegaMax", 0.28, ...          % omega_max（杀伤强度）
    "DualKOmega", 0.55, ...              % K_omega（杀伤 Hill 半饱和）
    "DualNOmega", 2, ...               % n_omega 杀伤 Hill 指数
    "DualK_A1_B1", 0.12, ...           % A1→B1 诱导半饱和（与 DualAInit 同量级）
    "DualK_A2_B1", 0.12, ...           % A2→B1 交叉调节半饱和
    "DualK_A1_B2", 0.12, ...           % A1→B2 抑制半饱和
    "DualK_A1_B3", 0.12, ...           % A1→B3 Hill 半饱和（三信号全矩阵用）
    "DualK_A2_B2", 0.12, ...
    "DualK_A2_B3", 0.12, ...           % A2→B3 抑制半饱和
    "DualK_A3_B1", 0.12, ...
    "DualK_A3_B2", 0.12, ...
    "DualK_A3_B3", 0.12, ...
    "DualMetCostA", 0.018, ...         % 生长负担：对 (kA1+kA2) 线性计价
    "DualMetCostB1", 0.022, ...
    "DualMetCostB2", 0.022, ...
    "DualMetCostB3", 0.022, ...
    "DualCostA1", 1.0, ...             % 资源积分：单位 A1 合成通量代价
    "DualCostA2", 1.0, ...
    "DualCostA3", 1.0, ...
    "DualCostB1", 0.35, ...
    "DualCostB2", 0.35, ...
    "DualCostB3", 0.35, ...
    "DualResultsMat", "triple_community_deception_results.mat", ...
    "DualAinflux1", 0.014, ...   % 外源/渗漏 A1 通量
    "DualAinflux2", 0.014, ...
    "DualAinflux3", 0.014, ...
    "DualA3Init", [], ...              % 空则 = DualAInit（A3 初值）
    "TripleSweepLegacyIv", false, ...  % true：仅旧 iv、两信号、4^3=64 组
    "TripleOwnBPromotesNi", false, ... % true：B_i 对同菌 N_i 为 +ω(B) 促进；默认 false 为 −ω
    "TripleSweepOdeRelTol", nan, ... % NaN：未指定；促进+FastWhen 时约 3e-3
    "TripleSweepOdeAbsTol", nan, ... % NaN：未指定；促进+FastWhen 时约 3e-8
    "TripleSweepOdeFastWhenOwnBPromotesNi", true, ... % B_i 促进 N_i 时启用快速扫描档（容差+栅格+ResDot+Tend 缩放）
    "TripleSweepFastApprox", false, ... % true：默认 B 抑制 N 时也用快速近似（见文件头说明）
    "TripleSweepTendScale", nan, ... % NaN：OwnBPromotesNi 时 Tend×0.32，仅 FastApprox 时×0.5；标量∈(0,1] 显式乘 DualStopTime；1=不缩
    "TripleLargeSweepHeatmapOnly", true, ... % nStrat^3>64 时仅导出热图；与 TripleSweepBarsP8Only 互斥见导出函数
    "TripleSweepBarsP8Only", true, ... % nHyp=8 且表含 hypothesis：仅 4 张 P1–P8 汇总柱图（本副本早退条件，与主目录 triple 的 P 前缀版一致时可触发）
    "TripleShowWaitbar", true, ...  % 三菌欺骗扫描时显示 waitbar（约每 nRun/200 步刷新，免拖慢）
    "TripleSweepEchoCmd", true, ... % 同步在命令行打印进度（无图形/首次 ode 很慢时仍可见）
    "TripleProductionSweepMode", "constrained138", ... % 默认 138+T1–T8 热图；full512 | random512
    "TripleRandomStratTrials", 0, ...            % random512 时每拓扑随机策略条数；0 表示未启用随机档
    "TripleRandomStratSeed", 0, ...              % >0 时 rng(seed)；否则 shuffle
    "DualNtRef", 200, ...           % 与 compare_three_strain_topologies 一致：统一时间栅格点数
    "DualSaveFigures", true, ...    % 双菌扫描：导出 24 张图到文件夹（不弹窗）
    "DualFigureExportDir", "figure_triple", ...  % 与双菌 figure/ 区分
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

% Mux [x1;...;xM;A] -> (M+1) 个 MATLAB Fcn 各输出标量导数（避免向量输出宽度在 MATLAB Fcn 上不可靠）
blk.muxU = [modelName '/Mux_u'];
local_add_block("simulink/Signal Routing/Mux", blk.muxU, ...
    "Inputs", sprintf("%d", M+1), "Position", [260, y0 + 30, 280, y0 + 30 + M*35]);

blk.mlf = cell(1, M+1);
dxW = 125;
dxH = 26;
for k = 1:(M+1)
    blk.mlf{k} = [modelName sprintf('/MSPG_dx%d', k)];
    py = y0 + 32 + (k - 1) * (dxH + 8);
    local_add_block("simulink/User-Defined Functions/MATLAB Fcn", blk.mlf{k}, ...
        "Position", [360, py, 360 + dxW, py + dxH], ...
        "MATLABFcn", sprintf("qs_mspg_rhs_component(u,%d)", k));
end

for j = 1:M
    add_line(modelName, sprintf("Int_x%d/1", j), sprintf("Mux_u/%d", j), "autorouting", "on");
end
add_line(modelName, "Int_A/1", sprintf("Mux_u/%d", M+1), "autorouting", "on");

for k = 1:(M+1)
    add_line(modelName, "Mux_u/1", sprintf("MSPG_dx%d/1", k), "autorouting", "on");
    if k <= M
        add_line(modelName, sprintf("MSPG_dx%d/1", k), sprintf("Int_x%d/1", k), "autorouting", "on");
    else
        add_line(modelName, sprintf("MSPG_dx%d/1", k), "Int_A/1", "autorouting", "on");
    end
end

% Readout
blk.readout = [modelName '/Readout'];
local_add_block("simulink/Ports & Subsystems/Subsystem", blk.readout, "Position", [620, y0 + 20, 790, y0 + 120]);
local_buildReadoutSubsystem(blk.readout);

blk.muxPop = [modelName '/Mux_Pop'];
blk.scopePop = [modelName '/Scope_Pop'];
blk.scopeA = [modelName '/Scope_A'];
blk.scopeOut = [modelName '/Scope_Output'];
local_add_block("simulink/Signal Routing/Mux", blk.muxPop, "Inputs", sprintf("%d", M), "Position", [820, y0, 840, y0 + 40 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopePop, "Position", [880, y0 - 15, 930, y0 + 45 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopeA, "Position", [880, y0 + 120 + M*15, 930, y0 + 180 + M*15]);
local_add_block("simulink/Sinks/Scope", blk.scopeOut, "Position", [880, y0 + 220 + M*30, 930, y0 + 280 + M*30]);

for j = 1:M
    add_line(modelName, sprintf("Int_x%d/1", j), sprintf("Mux_Pop/%d", j), "autorouting", "on");
end
add_line(modelName, "Mux_Pop/1", "Scope_Pop/1", "autorouting", "on");
add_line(modelName, "Int_A/1", "Scope_A/1", "autorouting", "on");
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
if opts.RunTripleCommunityDeceptionSweep
    local_runTripleCommunityDeceptionSweep(opts, scriptDir);
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
    error('build_modular_qs_simulink_model_triple:add_block_failed', '%s', fullMsg);
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
        error("build_modular_qs_simulink_model_triple:BadNeed", "need_vec 长度须等于 NumStrains (%d)。", M);
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
        error("build_modular_qs_simulink_model_triple:BadB", "b_vec 长度须等于 nTraits (%d)。", nTraits);
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
        error("build_modular_qs_simulink_model_triple:BadC", "c_vec 长度须等于 nTraits (%d)。", nTraits);
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
        error("build_modular_qs_simulink_model_triple:BadProduce", ...
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
        error("build_modular_qs_simulink_model_triple:BadKA", "kA_vec 长度须等于 NumStrains (%d)。", M);
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

local_modelWorkspaceAssign(mw, "N_pop", 0.2);
if isempty(opts.FracInit)
    frac = ones(1, M) / M;
else
    frac = reshape(double(opts.FracInit), 1, []);
    if numel(frac) ~= M
        error("build_modular_qs_simulink_model_triple:BadFrac", "FracInit 长度须等于 NumStrains (%d)。", M);
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
        warning("build_modular_qs_simulink_model_triple:NoLog", ...
            "未找到 qs_sim_pop。跳过 decepStrength=%g。", sweepVals(k));
        continue;
    end
    [t, Y] = local_structPopToMatrix(evalin("base", "qs_sim_pop"), M);
    if isempty(t) || size(Y, 2) ~= M
        warning("build_modular_qs_simulink_model_triple:BadLog", "qs_sim_pop 维度异常，跳过。");
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
        warning("build_modular_qs_simulink_model_triple:NoLog", "未找到 qs_sim_pop，跳过 N_pop=%g。", sweepVals(k));
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

function local_runTripleCommunityDeceptionSweep(opts, scriptDir)
%LOCAL_RUNTRIPLECOMMUNITYDECEPTIONSWEEP 18 种调控拓扑 × 产率策略（默认 8^3=512，可选 constrained138 / random512）；triple_qs_community_rhs（11 维）
if ~isempty(scriptDir)
    addpath(scriptDir);
end

topologyReductionStr = "full18";

legacyIv = logical(opts.TripleSweepLegacyIv);
if legacyIv
    topologyReductionStr = "legacy_iv";
    stratTick = {'无', '仅A1', '仅A2', 'A1+A2'};
    nStrat = 4;
    effLegacy = [-1, -1, 0; 0, 0, -1; 0, 0, 0];
    effMats = {effLegacy};
    hypLabels = {'Legacy iv: N1→B1,N2→B2,N3→B3; A1⊣B1B2; A2⊣B3; kA1/kA2; 4^3'};
    nHyp = 1;
else
    stratTick = {'无', '仅A1', '仅A2', '仅A3', 'A1+A2', 'A1+A3', 'A2+A3', 'A1+A2+A3'};
    nStrat = 8;
    [effMats, hypLabels] = triple_qs_topology18();
    nHyp = numel(effMats);
end

Tend0 = max(5, double(opts.DualStopTime));
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
if isempty(opts.DualA3Init) || ~(isnumeric(opts.DualA3Init) || islogical(opts.DualA3Init))
    A3i = Ainit;
else
    A3i = max(0, double(opts.DualA3Init));
end

% --- 产信号子集扫描：full512 | constrained138（8 轨母集 138 条）| random512 ---
prodSweepMode = "full512";
if isfield(opts, 'TripleProductionSweepMode')
    prodSweepMode = lower(strtrim(string(opts.TripleProductionSweepMode)));
end
randomTrials = 0;
if isfield(opts, 'TripleRandomStratTrials')
    randomTrials = max(0, round(double(opts.TripleRandomStratTrials)));
end
useConstrained138 = strcmp(prodSweepMode, "constrained138") && ~legacyIv;
useRandom512 = strcmp(prodSweepMode, "random512") && ~legacyIv && randomTrials > 0;
T138 = zeros(0, 3);
randABC = zeros(0, 3);
if legacyIv
    nPerHyp = nStrat * nStrat * nStrat;
elseif useConstrained138
    T138 = triple_qs_production_orbit8('triples');
    nPerHyp = size(T138, 1);
elseif useRandom512
    nPerHyp = randomTrials;
    rngSeed = 0;
    if isfield(opts, 'TripleRandomStratSeed') && isnumeric(opts.TripleRandomStratSeed) ...
            && isscalar(opts.TripleRandomStratSeed) && opts.TripleRandomStratSeed > 0
        rngSeed = double(opts.TripleRandomStratSeed);
    end
    if rngSeed > 0
        rng(uint32(rngSeed));
    else
        rng('shuffle');
    end
    randABC = randi(nStrat, nHyp * nPerHyp, 3);
else
    nPerHyp = nStrat * nStrat * nStrat;
end
nRun = nHyp * nPerHyp;
ownBPromotes = isfield(opts, 'TripleOwnBPromotesNi') && logical(opts.TripleOwnBPromotesNi);
fastOdeIfProm = ~isfield(opts, 'TripleSweepOdeFastWhenOwnBPromotesNi') || logical(opts.TripleSweepOdeFastWhenOwnBPromotesNi);
fastApprox = isfield(opts, 'TripleSweepFastApprox') && logical(opts.TripleSweepFastApprox);
useSweepFastOde = (ownBPromotes && fastOdeIfProm) || fastApprox;
% 非迟滞 11 维、本菌 B 促进 N：与 triple_hyst 中「迟滞+促进」扫描档同量级（更松容差、更短 Tend、稀栅格），显著快于旧版仅 3e-3 档
useSweepPromote11dAggressive = ownBPromotes && fastOdeIfProm;
relTolSweep = 1e-4;
absTolSweep = 1e-9;
if isfield(opts, 'TripleSweepOdeRelTol') && isnumeric(opts.TripleSweepOdeRelTol) && isscalar(opts.TripleSweepOdeRelTol) ...
        && isfinite(opts.TripleSweepOdeRelTol) && opts.TripleSweepOdeRelTol > 0
    relTolSweep = double(opts.TripleSweepOdeRelTol);
elseif useSweepPromote11dAggressive
    relTolSweep = 5e-2;
elseif useSweepFastOde
    relTolSweep = 8e-3;
end
if isfield(opts, 'TripleSweepOdeAbsTol') && isnumeric(opts.TripleSweepOdeAbsTol) && isscalar(opts.TripleSweepOdeAbsTol) ...
        && isfinite(opts.TripleSweepOdeAbsTol) && opts.TripleSweepOdeAbsTol > 0
    absTolSweep = double(opts.TripleSweepOdeAbsTol);
elseif useSweepPromote11dAggressive
    absTolSweep = 2e-6;
elseif useSweepFastOde
    absTolSweep = 1e-7;
end
if useSweepPromote11dAggressive
    resDotMaxSamples = 120;
elseif useSweepFastOde
    resDotMaxSamples = 256;
else
    resDotMaxSamples = 1200;
end
Nt_ref = max(30, round(double(opts.DualNtRef)));
if useSweepPromote11dAggressive
    Nt_ref = max(28, min(Nt_ref, 48));
elseif useSweepFastOde
    Nt_ref = max(36, min(Nt_ref, 72));
end
tendScUsed = 1;
if isfield(opts, 'TripleSweepTendScale') && isnumeric(opts.TripleSweepTendScale) && isscalar(opts.TripleSweepTendScale) ...
        && isfinite(opts.TripleSweepTendScale) && opts.TripleSweepTendScale > 0
    tendScUsed = min(1, max(0.2, double(opts.TripleSweepTendScale)));
elseif useSweepPromote11dAggressive
    tendScUsed = 0.32;
elseif useSweepFastOde
    tendScUsed = 0.5;
end
Tend = max(3, Tend0 * tendScUsed);
t_ref = linspace(0, Tend, Nt_ref).';
odeOptsSweep = odeset("RelTol", relTolSweep, "AbsTol", absTolSweep);
if useSweepFastOde
    odeOptsSweep = odeset(odeOptsSweep, 'MaxStep', max(0.25, Tend / 28));
end
tripSweepSolver = 'ode45';
if useSweepPromote11dAggressive
    tripSweepSolver = 'ode15s';
end
GnMat = nan(Nt_ref, nRun);
GbMat = nan(Nt_ref, nRun);
ResDotMat = nan(Nt_ref, nRun);
codeLabels = cell(nRun, 1);
d1_N1v = nan(nRun, 1);
d1_N2v = nan(nRun, 1);
d1_N3v = nan(nRun, 1);
d2_N1v = nan(nRun, 1);
d2_N2v = nan(nRun, 1);
d2_N3v = nan(nRun, 1);
d3_N1v = nan(nRun, 1);
d3_N2v = nan(nRun, 1);
d3_N3v = nan(nRun, 1);
passCntv = zeros(nRun, 1);
normMaxv = inf(nRun, 1);
stableAllv = false(nRun, 1);
tailFracStab = min(0.95, max(0.05, double(opts.DualStableTailFrac)));
eps1s = double(opts.DualStableEps1);
eps2s = double(opts.DualStableEps2);
eps3s = double(opts.DualStableEps3);
rows = table( ...
    ones(nRun, 1), zeros(nRun, 1), zeros(nRun, 1), zeros(nRun, 1), ...
    nan(nRun, 1), nan(nRun, 1), nan(nRun, 1), nan(nRun, 1), nan(nRun, 1), ...
    zeros(nRun, 1), ...
    'VariableNames', {'hypothesis', 'stratN1', 'stratN2', 'stratN3', ...
    'geomMeanN', 'geomMeanB', 'resTotal', 'stdNtot', 'lexRank', 'prodOrbit8'});

showWb = logical(opts.TripleShowWaitbar);
echoCmd = ~isfield(opts, 'TripleSweepEchoCmd') || logical(opts.TripleSweepEchoCmd);
if echoCmd && useSweepPromote11dAggressive
    fprintf(1, '[triple sweep] 促进+非迟滞（超速档 %s）：RelTol=%.4g AbsTol=%.4g Tend=%.4g/%.4g Nt_ref=%d ResDot≤%d MaxStep=%.3g\n', ...
        tripSweepSolver, relTolSweep, absTolSweep, Tend, Tend0, Nt_ref, resDotMaxSamples, odeget(odeOptsSweep, 'MaxStep'));
elseif echoCmd && useSweepFastOde
    fprintf(1, '[triple sweep] 快速档 ODE（%s）：RelTol=%.4g AbsTol=%.4g Tend=%.4g/%.4g Nt_ref=%d ResDot≤%d MaxStep=%.3g\n', ...
        tripSweepSolver, relTolSweep, absTolSweep, Tend, Tend0, Nt_ref, resDotMaxSamples, odeget(odeOptsSweep, 'MaxStep'));
end
if echoCmd && (useConstrained138 || useRandom512)
    fprintf(1, '[triple sweep] 产率扫描模式=%s | 每拓扑策略数=%d | 总 ODE=%d\n', char(prodSweepMode), nPerHyp, nRun);
end
wbH = [];
wbStep = max(1, min(50, floor(double(nRun) / 200)));
if showWb
    try %#ok<TRYNC>
        wbH = waitbar(0, sprintf('三菌欺骗扫描 0/%d …', nRun), 'Name', 'Triple sweep');
        if isgraphics(wbH)
            set(wbH, "Visible", "on");
            figure(wbH);
        end
        drawnow;
    catch %#ok<CTCH>
        wbH = [];
    end
end

idx = 0;
for hi = 1:nHyp
    effA_B = effMats{hi};
    for ri = 1:nPerHyp
        if legacyIv
            k0 = ri - 1;
            c = mod(k0, nStrat) + 1;
            k0 = floor(k0 / nStrat);
            b = mod(k0, nStrat) + 1;
            a = floor(k0 / nStrat) + 1;
        elseif useConstrained138
            a = double(T138(ri, 1));
            b = double(T138(ri, 2));
            c = double(T138(ri, 3));
        elseif useRandom512
            off = (hi - 1) * nPerHyp + ri;
            a = double(randABC(off, 1));
            b = double(randABC(off, 2));
            c = double(randABC(off, 3));
        else
            k0 = ri - 1;
            c = mod(k0, nStrat) + 1;
            k0 = floor(k0 / nStrat);
            b = mod(k0, nStrat) + 1;
            a = floor(k0 / nStrat) + 1;
        end
        idx = idx + 1;
        if echoCmd && (idx == 1 || idx == nRun || mod(idx, wbStep) == 0)
            fprintf(1, '[triple sweep] %d/%d (%.1f%%) 拓扑 H%d 策略 (%d,%d,%d) 积分中…\n', ...
                idx, nRun, 100 * idx / nRun, hi, a, b, c);
        end
        if showWb && ~isempty(wbH) && (idx == 1 || idx == nRun || mod(idx, wbStep) == 0)
            try %#ok<TRYNC>
                waitbar(idx / nRun, wbH, sprintf('三菌扫描 %d/%d（%.1f%%）| 拓扑 H%d 策略 (%d,%d,%d)', ...
                    idx, nRun, 100 * idx / nRun, hi, a, b, c));
                drawnow;
            catch %#ok<CTCH>
            end
        end
        if legacyIv
            [kA1_N1, kA2_N1] = local_dualStratToRates(a, kBase);
            kA3_N1 = 0;
            [kA1_N2, kA2_N2] = local_dualStratToRates(b, kBase);
            kA3_N2 = 0;
            [kA1_N3, kA2_N3] = local_dualStratToRates(c, kBase);
            kA3_N3 = 0;
        else
            [kA1_N1, kA2_N1, kA3_N1] = local_tripleStratToRates8(a, kBase);
            [kA1_N2, kA2_N2, kA3_N2] = local_tripleStratToRates8(b, kBase);
            [kA1_N3, kA2_N3, kA3_N3] = local_tripleStratToRates8(c, kBase);
        end
        p = local_tripleBuildParamStruct(kA1_N1, kA2_N1, kA3_N1, kA1_N2, kA2_N2, kA3_N2, kA1_N3, kA2_N3, kA3_N3, effA_B, nH, opts);
        y0 = [N0; N0; N0; Sinit; Ainit; Ainit; A3i; Binit; Binit; Binit; 0];
        odefun = @(t, y) triple_qs_community_rhs(t, y, p);
        if strcmp(tripSweepSolver, 'ode15s')
            [t, y] = ode15s(odefun, [0, Tend], y0, odeOptsSweep);
        else
            [t, y] = ode45(odefun, [0, Tend], y0, odeOptsSweep);
        end
        codeLabels{idx} = local_tripleStratCodeLabel(a, b, c);
        if size(y, 1) < 5
            gmN = NaN;
            gmB = NaN;
            resT = NaN;
            stdNt = NaN;
        else
            smSt = local_triplePaperStabilityFromTrajectory(t, y, eps1s, eps2s, eps3s, tailFracStab);
            d1_N1v(idx) = smSt.d1_N1;
            d1_N2v(idx) = smSt.d1_N2;
            d1_N3v(idx) = smSt.d1_N3;
            d2_N1v(idx) = smSt.d2_N1;
            d2_N2v(idx) = smSt.d2_N2;
            d2_N3v(idx) = smSt.d2_N3;
            d3_N1v(idx) = smSt.d3_N1;
            d3_N2v(idx) = smSt.d3_N2;
            d3_N3v(idx) = smSt.d3_N3;
            passCntv(idx) = smSt.passCountStable;
            normMaxv(idx) = smSt.normMaxPaper;
            stableAllv(idx) = smSt.stableAllPaper;
            i0 = max(1, floor(0.65 * size(y, 1))):size(y, 1);
            N1s = max(1e-12, y(i0, 1));
            N2s = max(1e-12, y(i0, 2));
            N3s = max(1e-12, y(i0, 3));
            B1s = max(1e-12, y(i0, 8));
            B2s = max(1e-12, y(i0, 9));
            B3s = max(1e-12, y(i0, 10));
            gmN = mean((N1s .* N2s .* N3s) .^ (1 / 3));
            gmB = mean((B1s .* B2s .* B3s) .^ (1 / 3));
            resT = y(end, 11);
            Ntot = y(i0, 1) + y(i0, 2) + y(i0, 3);
            stdNt = std(Ntot);
            tcol = t(:);
            gn_t = (max(y(:, 1), 1e-12) .* max(y(:, 2), 1e-12) .* max(y(:, 3), 1e-12)) .^ (1 / 3);
            gb_t = (max(y(:, 8), 1e-12) .* max(y(:, 9), 1e-12) .* max(y(:, 10), 1e-12)) .^ (1 / 3);
            GnMat(:, idx) = interp1(tcol, gn_t(:), t_ref, "linear", NaN);
            GbMat(:, idx) = interp1(tcol, gb_t(:), t_ref, "linear", NaN);
            nT = numel(tcol);
            if nT <= resDotMaxSamples
                iiVec = (1:nT).';
            else
                iiVec = unique(round(linspace(1, nT, resDotMaxSamples))).';
            end
            nRd = numel(iiVec);
            rd_s = nan(nRd, 1);
            t_s = tcol(iiVec);
            for k = 1:nRd
                ii = iiVec(k);
                du = triple_qs_community_rhs(tcol(ii), y(ii, :).', p);
                rd_s(k) = du(11);
            end
            ResDotMat(:, idx) = interp1(t_s, rd_s, t_ref, "linear", NaN);
        end
        rows.hypothesis(idx) = hi;
        rows.stratN1(idx) = a;
        rows.stratN2(idx) = b;
        rows.stratN3(idx) = c;
        rows.geomMeanN(idx) = gmN;
        rows.geomMeanB(idx) = gmB;
        rows.resTotal(idx) = resT;
        rows.stdNtot(idx) = stdNt;
        if legacyIv
            rows.prodOrbit8(idx) = 0;
        else
            rows.prodOrbit8(idx) = double(triple_qs_production_orbit8('id', a, b, c));
        end
    end
end

if showWb && ~isempty(wbH)
    try %#ok<TRYNC>
        close(wbH);
    catch %#ok<CTCH>
    end
    wbH = [];
end

scCell = cell(nRun, 1);
for idx = 1:nRun
    scCell{idx} = sprintf("%d-%d-%d", rows.stratN1(idx) - 1, rows.stratN2(idx) - 1, rows.stratN3(idx) - 1);
end
rows.stratCode = scCell;

rows.d1_N1 = d1_N1v;
rows.d1_N2 = d1_N2v;
rows.d1_N3 = d1_N3v;
rows.d2_N1 = d2_N1v;
rows.d2_N2 = d2_N2v;
rows.d2_N3 = d2_N3v;
rows.d3_N1 = d3_N1v;
rows.d3_N2 = d3_N2v;
rows.d3_N3 = d3_N3v;
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
            warning("build_modular_qs_simulink_model_triple:DeceptionThresh", ...
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
        error("build_modular_qs_simulink_model_triple:BadDeceptionEconThreshMode", ...
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
    warning("build_modular_qs_simulink_model_triple:TripleSweepEmpty", "三菌扫描无有效解，跳过保存与作图。");
    return;
end

sortVars = {'econGeomScore', 'stratN1', 'stratN2', 'stratN3'};
sortDirs = {'descend', 'ascend', 'ascend', 'ascend'};
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
        rows.lexRank(ixBad) = nRun + 1;
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

bestCell = cell(nHyp, 8);
bestScore = nan(nHyp, 8);
bestStratN = nan(nHyp, 8, 3);
if ~legacyIv
    oLab = triple_qs_production_orbit8('labels');
    for hi = 1:nHyp
        for oid = 1:8
            ix = find(rows.hypothesis == hi & rows.prodOrbit8 == oid);
            if isempty(ix)
                continue;
            end
            subP = rows(ix, :);
            localOk = ok(ix);
            subV = subP(localOk, :);
            if height(subV) < 1
                continue;
            end
            subS = sortrows(subV, sortVars, sortDirs);
            r = subS(1, :);
            sc0 = r.stratCode;
            if iscell(sc0)
                sc0 = sc0{1};
            end
            bestCell{hi, oid} = char(string(sc0));
            bestScore(hi, oid) = double(r.econGeomScore(1));
            bestStratN(hi, oid, 1) = double(r.stratN1(1));
            bestStratN(hi, oid, 2) = double(r.stratN2(1));
            bestStratN(hi, oid, 3) = double(r.stratN3(1));
        end
    end
else
    oLab = {};
end

matPath = char(string(opts.DualResultsMat));
if isempty(strtrim(matPath))
    matPath = "triple_community_deception_results.mat";
end
if ~local_isAbsolutePath(matPath) && ~isempty(strtrim(scriptDir))
    matPath = fullfile(scriptDir, matPath);
end
stratPairLabels = codeLabels;
tripleSweepMeta = struct( ...
    "nRun", nRun, "nHyp", nHyp, "nStrat", nStrat, ...
    "Nt_ref", Nt_ref, "Tend", Tend, "tailFrac", 0.3, ...
    "i0ref", i0ref, ...
    "stabilityEps1", eps1s, "stabilityEps2", eps2s, "stabilityEps3", eps3s, ...
    "stabilityTailFrac", tailFracStab, ...
    "stabilityNote", "Table1: d1=|N(tL)-N(tL-1)|<e1; d2=std(N tail)<e2; d3=1/N(tL)<e3（仅诊断，不参与 lexRank）", ...
    "econThreshMode", threshMode, ...
    "econThreshByHypothesis", econThreshByHypothesis, ...
    "evaluationRank", "per-topology: econGeomScore=(N_h+B_h+res_h)/3 desc, strat asc; passCountEcon 仅诊断", ...
    "legacyIv", legacyIv, ...
    "topologyReduction", char(topologyReductionStr), ...
    "tripleOwnBPromotesNi", isfield(opts, 'TripleOwnBPromotesNi') && logical(opts.TripleOwnBPromotesNi), ...
    "tripleSweepOdeRelTol", relTolSweep, ...
    "tripleSweepOdeAbsTol", absTolSweep, ...
    "tripleSweepResDotMaxSamples", resDotMaxSamples, ...
    "tripleSweepFastOdeApplied", useSweepFastOde, ...
    "tripleSweepFastApprox", fastApprox, ...
    "tripleSweepPromote11dAggressive", useSweepPromote11dAggressive, ...
    "tripleSweepOdeSolverUsed", tripSweepSolver, ...
    "tripleSweepTend0", Tend0, ...
    "tripleSweepTendScale", tendScUsed, ...
    "tripleProductionSweepMode", char(prodSweepMode), ...
    "tripleRandomStratTrials", randomTrials, ...
    "nPerHyp", nPerHyp ...
    );
tripleSweepMeta.bestByProdOrbit8Strat = bestCell;
tripleSweepMeta.bestByProdOrbit8Score = bestScore;
tripleSweepMeta.bestByProdOrbit8StratN = bestStratN;
tripleSweepMeta.prodOrbit8Labels = oLab;
n16 = sprintf("策略码 i-j-k（纵轴 1-%d）", nPerHyp);
if nStrat <= 4
    xLabBarStrat = "策略码 i-j-k（依次为 N1,N2,N3；0无 1仅A1 2仅A2 3双产）";
else
    xLabBarStrat = "策略码 i-j-k（N1,N2,N3；每位 0..7 为 A1/A2/A3 的 bitmask）";
end
figPaths = local_exportTripleSweepFigures6(scriptDir, opts, hypLabels, nHyp, nPerHyp, ...
    t_ref, GnMat, GbMat, ResDotMat, tailGn, tailGb, tailResDot, stratPairLabels, n16, xLabBarStrat, nStrat, rows);
if numel(figPaths.files) > 0
    tripleSweepMeta.figureExportDir = figPaths.exportDir;
    tripleSweepMeta.exportedFigureFiles = figPaths.files;
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
tripleSweepMeta.stabilityBestByHypothesis = bestPaper;
if height(bestPaper) >= 1
    bestCross = sortrows(bestPaper, sortVars, sortDirs);
    rX = bestCross(1, :);
    hiX = double(rX.hypothesis(1));
    if hiX >= 1 && hiX <= numel(hypLabels)
        labX = hypLabels{hiX};
    else
        labX = sprintf('H%d', hiX);
    end
    scX = rX.stratCode;
    if iscell(scX)
        codeX = char(scX{1});
    else
        codeX = char(string(scX));
    end
    tripleSweepMeta.globalBestAmongTopologies = struct( ...
        'hypothesis', hiX, ...
        'topologyLabel', labX, ...
        'stratCode', codeX, ...
        'stratN1', double(rX.stratN1(1)), ...
        'stratN2', double(rX.stratN2(1)), ...
        'stratN3', double(rX.stratN3(1)), ...
        'passCountEcon', double(rX.passCountEcon(1)), ...
        'econGeomScore', double(rX.econGeomScore(1)), ...
        'geomMeanN_h', double(rX.geomMeanN_h(1)), ...
        'geomMeanB_h', double(rX.geomMeanB_h(1)), ...
        'resTotal_h', double(rX.resTotal_h(1)), ...
        'geomMeanN', double(rX.geomMeanN(1)), ...
        'geomMeanB', double(rX.geomMeanB(1)), ...
        'resTotal', double(rX.resTotal(1)), ...
        'rankAmongBest', 1, ...
        'nCandidates', height(bestPaper), ...
        'sortRule', strjoin(strcat(sortVars, '(', sortDirs, ')'), ' -> ') ...
        );
else
    tripleSweepMeta.globalBestAmongTopologies = struct('hypothesis', []);
end

if ~legacyIv && numel(oLab) >= 8
    fprintf("\n=== 产率结构 8 轨：各轨在 18 拓扑中的「最优点」——跨拓扑比较 econGeomScore ===\n");
    for oid = 1:8
        colSc = bestScore(:, oid);
        [mx, hiStar] = max(colSc, [], 'omitnan');
        if ~isfinite(mx) || isempty(bestCell{hiStar, oid})
            continue;
        end
        if hiStar >= 1 && hiStar <= numel(hypLabels)
            labH = char(string(hypLabels{hiStar}));
        else
            labH = sprintf("H%d", hiStar);
        end
        fprintf("P%d | %s | 最优拓扑=%s | score=%.4g | 策略码 %s\n", ...
            oid, char(string(oLab{oid})), labH, mx, bestCell{hiStar, oid});
    end
end

topologyLabelsMat = hypLabels;
save(char(matPath), "rows", "hypLabels", "stratTick", "stratPairLabels", "Tend", "kBase", "nH", "S0", "opts", ...
    "t_ref", "GnMat", "GbMat", "ResDotMat", "codeLabels", ...
    "tailGn", "tailGb", "tailResDot", "tripleSweepMeta", "topologyLabelsMat", "effMats", "-v7.3");
fprintf("三菌欺骗扫描已写入：%s\n", char(matPath));
if numel(figPaths.files) > 0
    fprintf("图表已导出（共 %d 个文件）：%s\n", numel(figPaths.files), char(figPaths.exportDir));
end

fprintf("\n=== 综合评价（组内归一三项的算术平均 econGeomScore）：各假设 lexRank=1 ===\n");
fprintf("原始指标：geomMeanN、geomMeanB、resTotal；门槛模式「%s」（passCountEcon 仅诊断）\n", threshMode);
if strcmp(threshMode, 'median16')
    fprintf("门槛：各假设组内中位数（N、B 为 ≥；累积资源为 ≤）→ passCountEcon=0..3\n");
elseif strcmp(threshMode, 'fixed')
    fprintf("门槛：固定 DeceptionThresh*（NaN 条目不参与 passCountEcon 计数）\n");
else
    fprintf("模式 none：不过门槛比较；passCountEcon=3\n");
end
fprintf("排序：econGeomScore↓（=(N_h+B_h+res_h)/3）→ strat↑\n");
fprintf("（每组内：N_h、B_h 为 min-max(geomMeanN/geomMeanB)；res_h=1−minmax(resTotal)）\n");
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
    s1 = stratTick{r.stratN1};
    s2 = stratTick{r.stratN2};
    s3 = stratTick{r.stratN3};
    scv = r.stratCode;
    if iscell(scv)
        stratCodeDisp = scv{1};
    else
        stratCodeDisp = char(scv);
    end
    if strcmp(threshMode, 'none')
        fprintf("H%d %s\n  -> 最优：N1=%s N2=%s N3=%s | 码 %s | lexRank=1/%d | econGeomScore=%.4g\n", ...
            hi, hypLabels{hi}, s1, s2, s3, stratCodeDisp, height(subV), r.econGeomScore);
    else
        fprintf("H%d %s\n  -> 最优：N1=%s N2=%s N3=%s | 码 %s | lexRank=1/%d | econGeomScore=%.4g | 经济过线=%d/%d [N=%d B=%d res=%d]\n", ...
            hi, hypLabels{hi}, s1, s2, s3, stratCodeDisp, height(subV), r.econGeomScore, ...
            r.passCountEcon, nEconGates, logical(r.passThreshGeomN), logical(r.passThreshGeomB), logical(r.passThreshRes));
    end
    if strcmp(threshMode, 'median16') && hi <= numel(econThreshByHypothesis)
        eth = econThreshByHypothesis(hi);
        fprintf("     本假设门槛：geomN≥%.4g geomB≥%.4g res≤%.4g\n", eth.thGeomN, eth.thGeomB, eth.thResTotal);
    end
    fprintf("     原始 geomN=%.4g geomB=%.4g res=%.4g | 归一 h: N_h=%.3f B_h=%.3f res_h=%.3f | econGeom=%.4g\n", ...
        r.geomMeanN, r.geomMeanB, r.resTotal, r.geomMeanN_h, r.geomMeanB_h, r.resTotal_h, r.econGeomScore);
    fprintf("     稳态诊断 passStable=%d/9 stableAll=%d（不参与排序）\n", ...
        r.passCountStable, logical(r.stableAllPaper));
end
gb = tripleSweepMeta.globalBestAmongTopologies;
if isfield(gb, 'nCandidates') && gb.nCandidates >= 1
    s1g = stratTick{gb.stratN1};
    s2g = stratTick{gb.stratN2};
    s3g = stratTick{gb.stratN3};
    fprintf("\n=== 跨拓扑「最最最优」（在 %d 个各拓扑 lexRank=1 候选中，按 econGeomScore 等规则取第一）===\n", gb.nCandidates);
    fprintf("拓扑编号：H%d\n", gb.hypothesis);
    fprintf("调控说明：%s\n", gb.topologyLabel);
    fprintf("最优欺骗：N1=%s N2=%s N3=%s | 码 %s\n", s1g, s2g, s3g, gb.stratCode);
    if strcmp(threshMode, 'none')
        fprintf("排序键：econGeomScore=%.4g（N_h=%.3f B_h=%.3f res_h=%.3f）\n", ...
            gb.econGeomScore, gb.geomMeanN_h, gb.geomMeanB_h, gb.resTotal_h);
    else
        fprintf("排序键：econGeomScore=%.4g | 经济过线=%d | N_h=%.3f B_h=%.3f res_h=%.3f\n", ...
            gb.econGeomScore, gb.passCountEcon, gb.geomMeanN_h, gb.geomMeanB_h, gb.resTotal_h);
    end
    fprintf("原始：geomN=%.4g geomB=%.4g res=%.4g\n", gb.geomMeanN, gb.geomMeanB, gb.resTotal);
    fprintf("规则摘要：%s\n", gb.sortRule);
end
fprintf("（无效/缺数据策略 lexRank=%d）\n", nRun + 1);

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
        error("build_modular_qs_simulink_model_triple:BadStrat", "stratId 须为 1..4。");
end
end

function [k1, k2, k3] = local_tripleStratToRates8(stratId, base)
%LOCAL_TRIPLESTRATTORATES8 stratId 1..8 → (kA1,kA2,kA3)∈{0,base}^3 的 bitmask 解码
switch stratId
    case 1
        k1 = 0;
        k2 = 0;
        k3 = 0;
    case 2
        k1 = base;
        k2 = 0;
        k3 = 0;
    case 3
        k1 = 0;
        k2 = base;
        k3 = 0;
    case 4
        k1 = 0;
        k2 = 0;
        k3 = base;
    case 5
        k1 = base;
        k2 = base;
        k3 = 0;
    case 6
        k1 = base;
        k2 = 0;
        k3 = base;
    case 7
        k1 = 0;
        k2 = base;
        k3 = base;
    case 8
        k1 = base;
        k2 = base;
        k3 = base;
    otherwise
        error("build_modular_qs_simulink_model_triple:BadStrat8", "stratId 须为 1..8。");
end
end

function p = local_tripleBuildParamStruct(kA1_N1, kA2_N1, kA3_N1, kA1_N2, kA2_N2, kA3_N2, kA1_N3, kA2_N3, kA3_N3, effA_B, nH, opts)
p.D = max(0, double(opts.DualD));
p.S0 = max(1e-12, double(opts.DualS0));
p.KS = max(1e-9, double(opts.DualKS));
p.mu_max1 = max(0, double(opts.DualMuMax1));
p.mu_max2 = max(0, double(opts.DualMuMax2));
p.mu_max3 = max(0, double(opts.DualMuMax3));
p.gamma1 = max(1e-9, double(opts.DualGamma1));
p.gamma2 = max(1e-9, double(opts.DualGamma2));
p.gamma3 = max(1e-9, double(opts.DualGamma3));
p.KB_max1 = max(0, double(opts.DualKBmax1));
p.KB_max2 = max(0, double(opts.DualKBmax2));
p.KB_max3 = max(0, double(opts.DualKBmax3));
p.omega_max = max(0, double(opts.DualOmegaMax));
p.K_omega = max(1e-9, double(opts.DualKOmega));
p.n_omega = max(1, round(double(opts.DualNOmega)));
p.n = nH;
p.delta_qs = 0.01;
p.epsN = 1e-9;
p.effA_B = effA_B;
p.K_A_B = [ ...
    max(1e-12, double(opts.DualK_A1_B1)), max(1e-12, double(opts.DualK_A1_B2)), max(1e-12, double(opts.DualK_A1_B3)); ...
    max(1e-12, double(opts.DualK_A2_B1)), max(1e-12, double(opts.DualK_A2_B2)), max(1e-12, double(opts.DualK_A2_B3)); ...
    max(1e-12, double(opts.DualK_A3_B1)), max(1e-12, double(opts.DualK_A3_B2)), max(1e-12, double(opts.DualK_A3_B3)) ...
    ];
p.qsBoost = max(0, double(opts.qsBoost));
p.kA1_N1 = kA1_N1;
p.kA2_N1 = kA2_N1;
p.kA3_N1 = kA3_N1;
p.kA1_N2 = kA1_N2;
p.kA2_N2 = kA2_N2;
p.kA3_N2 = kA3_N2;
p.kA1_N3 = kA1_N3;
p.kA2_N3 = kA2_N3;
p.kA3_N3 = kA3_N3;
p.metCostA = max(0, double(opts.DualMetCostA));
p.metCostB1 = max(0, double(opts.DualMetCostB1));
p.metCostB2 = max(0, double(opts.DualMetCostB2));
p.metCostB3 = max(0, double(opts.DualMetCostB3));
p.costA1 = double(opts.DualCostA1);
p.costA2 = double(opts.DualCostA2);
p.costA3 = double(opts.DualCostA3);
p.costB1 = double(opts.DualCostB1);
p.costB2 = double(opts.DualCostB2);
p.costB3 = double(opts.DualCostB3);
p.Ainflux1 = max(0, double(opts.DualAinflux1));
p.Ainflux2 = max(0, double(opts.DualAinflux2));
p.Ainflux3 = max(0, double(opts.DualAinflux3));
p.ownB_promotes_Ni = isfield(opts, 'TripleOwnBPromotesNi') && logical(opts.TripleOwnBPromotesNi);
end

function sm = local_triplePaperStabilityFromTrajectory(t, y, eps1, eps2, eps3, tailFrac)
%LOCAL_TRIPLEPAPERSTABILITYFROMTRAJECTORY 三菌 N1–N3 各 d1/d2/d3，共 9 条判据（与双菌 Table 1 同尺度）
sm = struct( ...
    "d1_N1", NaN, "d1_N2", NaN, "d1_N3", NaN, ...
    "d2_N1", NaN, "d2_N2", NaN, "d2_N3", NaN, ...
    "d3_N1", NaN, "d3_N2", NaN, "d3_N3", NaN, ...
    "passCountStable", 0, "normMaxPaper", Inf, "stableAllPaper", false);
if isempty(t) || isempty(y) || size(y, 1) < 3 || size(y, 2) < 3
    return;
end
nt = size(y, 1);
N1 = y(:, 1);
N2 = y(:, 2);
N3 = y(:, 3);
d1_N1 = abs(N1(end) - N1(end - 1));
d1_N2 = abs(N2(end) - N2(end - 1));
d1_N3 = abs(N3(end) - N3(end - 1));
i0 = max(2, min(nt - 1, floor((1 - tailFrac) * nt)));
idxTail = i0:nt;
d2_N1 = std(N1(idxTail), 0, "omitnan");
d2_N2 = std(N2(idxTail), 0, "omitnan");
d2_N3 = std(N3(idxTail), 0, "omitnan");
if ~all(isfinite([d2_N1, d2_N2, d2_N3]))
    d2_N1 = 0;
    d2_N2 = 0;
    d2_N3 = 0;
end
d3_N1 = 1 / max(real(N1(end)), 1e-30);
d3_N2 = 1 / max(real(N2(end)), 1e-30);
d3_N3 = 1 / max(real(N3(end)), 1e-30);
e1 = max(eps1, 1e-30);
e2 = max(eps2, 1e-30);
e3 = max(eps3, 1e-30);
r = [d1_N1 / e1, d1_N2 / e1, d1_N3 / e1, d2_N1 / e2, d2_N2 / e2, d2_N3 / e2, d3_N1 / e3, d3_N2 / e3, d3_N3 / e3];
pass = [d1_N1 < eps1, d1_N2 < eps1, d1_N3 < eps1, d2_N1 < eps2, d2_N2 < eps2, d2_N3 < eps2, ...
    d3_N1 < eps3, d3_N2 < eps3, d3_N3 < eps3];
sm.d1_N1 = d1_N1;
sm.d1_N2 = d1_N2;
sm.d1_N3 = d1_N3;
sm.d2_N1 = d2_N1;
sm.d2_N2 = d2_N2;
sm.d2_N3 = d2_N3;
sm.d3_N1 = d3_N1;
sm.d3_N2 = d3_N2;
sm.d3_N3 = d3_N3;
sm.passCountStable = sum(pass);
sm.normMaxPaper = max(r);
sm.stableAllPaper = all(pass);
end

function s = local_tripleStratCodeLabel(a, b, c)
%LOCAL_TRIPLESTRATCODELABEL 紧凑策略码：i-j-k，i,j,k∈{0,1,2,3} 对应 无/仅A1/仅A2/A1+A2
s = sprintf("%d-%d-%d", a - 1, b - 1, c - 1);
end

function C = local_tripleTailVecToCube64(v, nS)
%LOCAL_TRIPLETAILVECTOCUBE64 列顺序与扫描三重循环 (N1,N2,N3) 一致：idx=(a-1)n^2+(b-1)n+c
v = v(:);
C = nan(nS, nS, nS);
for ia = 1:nS
    for ib = 1:nS
        for ic = 1:nS
            kk = (ia - 1) * nS * nS + (ib - 1) * nS + ic;
            C(ia, ib, ic) = v(kk);
        end
    end
end
end

function outPath = local_tripleExportOneBar64(figRoot, hi, tag, tailVec, stratPairLabels, xLabBarStrat, ylabBar, ttlLine, hypTitle, res, fmt)
%LOCAL_TRIPLEEXPORTONEBAR64 64 柱：短数字码横轴 + 宽图 + 脚注码本
f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [40 40 2000 620]);
try %#ok<TRYNC>
    ax = axes(f, "Position", [0.07 0.18 0.88 0.68]);
    bar(ax, tailVec(:), "FaceColor", [0.38 0.55 0.78]);
    nB = numel(tailVec);
    set(ax, "XTick", 1:nB, "XTickLabel", stratPairLabels, "XTickLabelRotation", 0, "FontSize", 7);
    grid(ax, "on");
    xlabel(ax, char(string(xLabBarStrat)), "FontSize", 10);
    ylabel(ax, ylabBar, "FontSize", 10);
    title(ax, {char(string(hypTitle)), ttlLine}, "Interpreter", "none", "FontSize", 11);
    annotation(f, "textbox", [0.07 0.02 0.88 0.12], "String", ...
        {'码本：每位 0=不产信号, 1=仅A1, 2=仅A2, 3=A1+A2；', ...
        '三数字依次为 (N1,N2,N3)。例 2-0-1 表示 N1 仅产 A2、N2 不产、N3 仅产 A1。'}, ...
        "EdgeColor", "none", "FontSize", 9, "Interpreter", "none", "VerticalAlignment", "top");
    outPath = fullfile(figRoot, sprintf("H%d_%s_bar.%s", hi, tag, fmt));
    local_dualTryExportgraphics(f, outPath, res);
catch ME %#ok<NASGU>
    close(f);
    rethrow(ME);
end
close(f);
end

function outPath = local_tripleExportCubeMetric(figRoot, hi, tag, tailVec64, hypTitle, res, fmt, ttlLong)
%LOCAL_TRIPLEEXPORTCUBEMETRIC 2×2 子图：固定 N3 码，平面为 N1×N2（均为 0–3）
nS = 4;
C = local_tripleTailVecToCube64(tailVec64(:), nS);
f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [40 40 1100 920]);
tlo = tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
codes = 0:(nS - 1);
for ic = 1:nS
    ax = nexttile(tlo);
    Sl = squeeze(C(:, :, ic));
    imagesc(ax, codes, codes, Sl);
    axis(ax, "xy");
    try %#ok<TRYNC>
        colormap(ax, parula);
    catch %#ok<CTCH>
        colormap(ax, jet);
    end
    colorbar(ax);
    xlabel(ax, "N2 code (0–3)", "FontSize", 9);
    ylabel(ax, "N1 code (0–3)", "FontSize", 9);
    title(ax, sprintf("N3 code = %d", ic - 1), "FontSize", 10);
    set(ax, "XTick", codes, "YTick", codes);
end
sgtitle(f, {char(string(hypTitle)), ttlLong, ...
    "code: 0=none, 1=A1 only, 2=A2 only, 3=both; slice = N3"}, "Interpreter", "none", "FontSize", 11);
outPath = fullfile(figRoot, sprintf("H%d_%s_N1N2slices.%s", hi, tag, fmt));
try %#ok<TRYNC>
    local_dualTryExportgraphics(f, outPath, res);
catch ME %#ok<NASGU>
    close(f);
    rethrow(ME);
end
close(f);
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
    error("build_modular_qs_simulink_model_triple:HeatBarArgs", ...
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

function filesOut = local_tripleExportP1toP8SummaryBars(figRoot, rowsIn, hypFigPref, res, fmt)
%LOCAL_TRIPLEEXPORTP1TOP8SUMMARYBARS 横轴产率类 P1–P8；纵轴为各类内 econGeomScore 字典序最优一行（与 lexRank=1 一致）的标量
filesOut = {};
if ~istable(rowsIn) || isempty(figRoot)
    return;
end
req = {'hypothesis', 'geomMeanN', 'geomMeanB', 'resTotal', 'geomMeanN_h', 'geomMeanB_h', 'resTotal_h', 'econGeomScore', 'stratN1', 'stratN2', 'stratN3'};
for k = 1:numel(req)
    if ~ismember(req{k}, rowsIn.Properties.VariableNames)
        return;
    end
end
hypFigPref = char(string(hypFigPref));
nP = 8;
gmN = rowsIn.geomMeanN;
gmB = rowsIn.geomMeanB;
resC = rowsIn.resTotal;
ok = isfinite(gmN) & isfinite(gmB) & isfinite(resC) ...
    & isfinite(rowsIn.geomMeanN_h) & isfinite(rowsIn.geomMeanB_h) & isfinite(rowsIn.resTotal_h) ...
    & isfinite(rowsIn.econGeomScore);
sortVars = {'econGeomScore', 'stratN1', 'stratN2', 'stratN3'};
sortDirs = {'descend', 'ascend', 'ascend', 'ascend'};
vN = nan(nP, 1);
vB = nan(nP, 1);
vR = nan(nP, 1);
vE = nan(nP, 1);
for hi = 1:nP
    ix = find(rowsIn.hypothesis == hi & ok);
    if isempty(ix)
        continue;
    end
    Ts = sortrows(rowsIn(ix, :), sortVars, sortDirs);
    vN(hi) = Ts.geomMeanN(1);
    vB(hi) = Ts.geomMeanB(1);
    vR(hi) = Ts.resTotal(1);
    vE(hi) = Ts.econGeomScore(1);
end
xtl = cell(nP, 1);
for kk = 1:nP
    xtl{kk} = sprintf('%s%d', hypFigPref, kk);
end
specs = {
    vN, 'geomMeanN', '几何平均丰度', '(N1·N2·N3)^{1/3} 末段时间窗均值'; ...
    vB, 'geomMeanB', '几何平均产物量', '(B1·B2·B3)^{1/3} 末段时间窗均值'; ...
    vR, 'resTotal', '累积资源消耗（物资）', '全程资源积分 resTotal（越小越好）'; ...
    vE, 'econGeomScore', '评价函数 econGeomScore', '组内归一后 (N_h+B_h+res_h)/3，同类内最优策略'
    };
for si = 1:size(specs, 1)
    vals = specs{si, 1};
    tag = char(string(specs{si, 2}));
    ttl1 = char(string(specs{si, 3}));
    ttl2 = char(string(specs{si, 4}));
    f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [80 80 720 420]);
    try %#ok<TRYNC>
        ax = axes(f);
        bar(ax, 1:nP, vals, "FaceColor", [0.38 0.55 0.78]);
        grid(ax, "on");
        set(ax, "XTick", 1:nP, "XTickLabel", xtl);
        xlabel(ax, '产率类（每组内字典序最优）');
        ylabel(ax, ttl1);
        title(ax, {ttl1, ttl2}, "Interpreter", "none");
        outPath = fullfile(figRoot, sprintf('%s1to%s8_summary_%s.%s', hypFigPref, hypFigPref, tag, fmt));
        local_dualTryExportgraphics(f, outPath, res);
        filesOut{end+1} = outPath; %#ok<AGROW>
    catch ME
        close(f);
        rethrow(ME);
    end
    close(f);
end
end

function figPaths = local_exportTripleSweepFigures6(scriptDir, opts, hypLabels, nHyp, nPerHyp, ...
    t_ref, GnMat, GbMat, ResDotMat, tailGn, tailGb, tailResDot, stratPairLabels, ylabIdxStr, xLabBarStrat, nStrat, rowsIn)
%LOCAL_EXPORTTRIPLESWEEPFIGURES6 三菌：每假设 9 张图；nPerHyp>64 且 TripleLargeSweepHeatmapOnly 时仅 3 张热图
% rowsIn：可选；当 nPerHyp==138 且含 prodOrbit8 时，额外导出横轴为 T1–T8 的聚合热图（*_orbit8T_heatmap）
% TripleSweepBarsP8Only 且 nHyp=8、nPerHyp=138：仅 4 张柱图（P1–P8），不导出热图
if nargin < 13 || isempty(nStrat)
    nStrat = 4;
end
if nargin < 14
    rowsIn = [];
end
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
barsP8Only = isfield(opts, 'TripleSweepBarsP8Only') && logical(opts.TripleSweepBarsP8Only);
if barsP8Only && nHyp == 8 && istable(rowsIn) && ismember('hypothesis', rowsIn.Properties.VariableNames) ...
        && height(rowsIn) >= nHyp
    try %#ok<TRYNC>
        filesOut = local_tripleExportP1toP8SummaryBars(figRoot, rowsIn, 'P', res, fmt);
    catch ME
        set(0, "DefaultFigureVisible", oldVis);
        rethrow(ME);
    end
    set(0, "DefaultFigureVisible", oldVis);
    figPaths.exportDir = figRoot;
    figPaths.files = filesOut(:);
    return;
end
heatOnly = logical(opts.TripleLargeSweepHeatmapOnly) && (nPerHyp > 64);
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
            "(N1·N2·N3)^{1/3}", "几何平均菌量 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneHeatmap(figRoot, hi, "geomB", t_ref, GbS, ylabIdxStr, ...
            "(B1·B2·B3)^{1/3}", "几何平均产物 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        filesOut{end+1} = local_dualExportOneHeatmap(figRoot, hi, "resRate", t_ref, RdS, ylabIdxStr, ...
            "dR/dt", "资源消耗率 · 热图", hypTitle, res, fmt); %#ok<AGROW>
        if istable(rowsIn) && ismember('prodOrbit8', rowsIn.Properties.VariableNames) ...
                && height(rowsIn) >= hi * nPerHyp
            gIx = (hi - 1) * nPerHyp + (1:nPerHyp);
            po = double(rowsIn.prodOrbit8(gIx));
            if numel(po) == nPerHyp && all(po >= 1 & po <= 8)
                Gn8 = local_tripleMeanByProdOrbit8Column(GnS, po);
                Gb8 = local_tripleMeanByProdOrbit8Column(GbS, po);
                Rd8 = local_tripleMeanByProdOrbit8Column(RdS, po);
                filesOut{end+1} = local_tripleExportOrbit8Heatmap(figRoot, hi, "geomN", t_ref, Gn8, hypTitle, res, fmt); %#ok<AGROW>
                filesOut{end+1} = local_tripleExportOrbit8Heatmap(figRoot, hi, "geomB", t_ref, Gb8, hypTitle, res, fmt); %#ok<AGROW>
                filesOut{end+1} = local_tripleExportOrbit8Heatmap(figRoot, hi, "resRate", t_ref, Rd8, hypTitle, res, fmt); %#ok<AGROW>
            end
        end
        if ~heatOnly
            filesOut{end+1} = local_tripleExportOneBar64(figRoot, hi, "geomN", tg, stratPairLabels, xLabBarStrat, ...
                "mean((N1·N2·N3)^{1/3}) 后30%", "几何平均菌量 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
            filesOut{end+1} = local_tripleExportOneBar64(figRoot, hi, "geomB", tb, stratPairLabels, xLabBarStrat, ...
                "mean((B1·B2·B3)^{1/3}) 后30%", "几何平均产物 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
            filesOut{end+1} = local_tripleExportOneBar64(figRoot, hi, "resRate", tr, stratPairLabels, xLabBarStrat, ...
                "mean(dR/dt) 后30%", "资源消耗率 · 末段均值", hypTitle, res, fmt); %#ok<AGROW>
            if nStrat == 4
                filesOut{end+1} = local_tripleExportCubeMetric(figRoot, hi, "geomN", tg, hypTitle, res, fmt, ...
                    "几何平均菌量（末段）：4 子图 = N3 码 0–3，子图内横 N2 纵 N1"); %#ok<AGROW>
                filesOut{end+1} = local_tripleExportCubeMetric(figRoot, hi, "geomB", tb, hypTitle, res, fmt, ...
                    "几何平均产物（末段）：4 子图 = N3 码 0–3，子图内横 N2 纵 N1"); %#ok<AGROW>
                filesOut{end+1} = local_tripleExportCubeMetric(figRoot, hi, "resRate", tr, hypTitle, res, fmt, ...
                    "资源消耗率 mean(dR/dt)（末段）：4 子图 = N3 码 0–3，子图内横 N2 纵 N1"); %#ok<AGROW>
            end
        end
    end
catch ME
    set(0, "DefaultFigureVisible", oldVis);
    rethrow(ME);
end
set(0, "DefaultFigureVisible", oldVis);
figPaths.exportDir = figRoot;
figPaths.files = filesOut(:);
end

function Z8 = local_tripleMeanByProdOrbit8Column(Znp, poVec)
%LOCAL_TRIPLEMEANBYPRODORBIT8COLUMN Znp: Nt×nPerHyp；poVec 长度 nPerHyp，取值 1..8
Nt = size(Znp, 1);
Z8 = nan(Nt, 8);
pv = poVec(:).';
for oid = 1:8
    ix = find(pv == oid);
    if isempty(ix)
        continue;
    end
    Z8(:, oid) = mean(Znp(:, ix), 2, 'omitnan');
end
end

function outPath = local_tripleExportOrbit8Heatmap(figRoot, hi, tag, t_ref, Z8, hypTitle, res, fmt)
%LOCAL_TRIPLEEXPORTORBIT8HEATMAP 横轴 T1–T8（产率轨），纵轴时间；同轨内多策略对时间序列取平均
f = figure("Visible", "off", "Color", "w", "Units", "pixels", "Position", [80 80 900 480]);
try %#ok<TRYNC>
    ax = axes(f);
    imagesc(ax, 1:8, t_ref, Z8);
    axis(ax, "xy");
    try %#ok<TRYNC>
        colormap(ax, parula);
    catch %#ok<CTCH>
        colormap(ax, jet);
    end
    cb = colorbar(ax);
    tg = char(string(tag));
    if strcmp(tg, "resRate")
        cb.Label.String = 'dR/dt';
    elseif strcmp(tg, "geomB")
        cb.Label.String = '(B1·B2·B3)^{1/3}';
    else
        cb.Label.String = '(N1·N2·N3)^{1/3}';
    end
    xlabel(ax, '产率轨（T1–T8：同轨内多策略对时间取平均）');
    ylabel(ax, '时间');
    xticks(ax, 1:8);
    xtl = cell(8, 1);
    for kk = 1:8
        xtl{kk} = sprintf('T%d', kk);
    end
    xticklabels(ax, xtl);
    title(ax, {char(string(hypTitle)), sprintf('%s · 按产率轨聚合', tg)}, 'Interpreter', 'none');
    outPath = fullfile(figRoot, sprintf('H%d_%s_orbit8T_heatmap.%s', hi, tg, fmt));
    local_dualTryExportgraphics(f, outPath, res);
catch ME
    close(f);
    rethrow(ME);
end
close(f);
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
