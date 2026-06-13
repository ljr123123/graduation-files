function modelName = build_modular_qs_simulink_model(varargin)
%BUILD_MODULAR_QS_SIMULINK_MODEL 用纯 MATLAB 代码搭建对应的 Simulink 模型
%
% 生成的模型复现 modular_qs_simulation.m 中的 3 状态 ODE + Hill 输出，并支持：
%
% **欺骗强度 decepStrength（定量）**  
%   采用「两策略复制子动态 + 雪堆博弈（Snowdrift）收益」刻画合作者(NI/LuxI)与欺骗者(NR/LuxR)
%   的相对适应度，而不再把欺骗仅写进 dA 的 NR 权重。令 rho = NI/(NI+NR)，
%     d(rho)/dt = eta_game * rho*(1-rho) * (U_C - U_D)
%   其中合作者、欺骗者期望收益（随机配对，交互规模 z_int）为
%     U_C = z_int * ( R*rho + S*(1-rho) ),  U_D = z_int * ( T*rho + P*(1-rho) )
%   雪堆支付：R=b-c/2, S=b-c, T=b, P=0，有效成本 c_eff = c_snow * decepStrength。
%   decepStrength 越大 → 合作者承担的有效成本越高 → 通常有利于 NR 频率上升。
%   总种群仍用 dN/dt = rI*NI*g + rR*NR*g（g=1-(NI+NR)/K），并由链式法则得到
%     dNI = N*d(rho)/dt + rho*dN/dt,  dNR = (1-rho)*dN/dt - N*d(rho)/dt。
%   dA 中群体感应消耗改为对称项：delta_qs * (NI+NR) * A。
%
% **种群规模 N_pop**  
%   NI0 = N_pop*fracLuxI，NR0 = N_pop*(1-fracLuxI)，在模型 InitFcn 中每步仿真前更新，  
%   便于扫描总种群规模对收敛/振荡的影响，寻找近似“临界”种群水平。
%
% 用法：
%   build_modular_qs_simulink_model
%   build_modular_qs_simulink_model("ModelName","qs_modular_sys")
%   build_modular_qs_simulink_model("OpenModel",true,"RunSim",true)
%   build_modular_qs_simulink_model("RunDecepSweep",true)   % 欺骗强度扫描并绘图
%   build_modular_qs_simulink_model("RunNpopSweep",true)    % N_pop 扫描并绘图
%
% 说明：
% - 动力学参数在模型工作区(Model Workspace)中初始化，InitFcn 同步 NI0/NR0
% - 求解器设置为 variable-step/ode45，StopTime=24

opts = struct( ...
    "ModelName", "qs_modular_sys", ...
    "OpenModel", true, ...
    "RunSim", false, ...
    "SaveModel", true, ...
    "StopTime", "24", ...
    "MaxStep", "0.1", ...
    "RunDecepSweep", false, ...
    "RunNpopSweep", false, ...
    "DecepSweepValues", [0.25 0.5 1.0 1.5 2.0], ...
    "NpopSweepValues", [0.05 0.1 0.2 0.35 0.5 0.8] ...
);
opts = local_parseNameValue(opts, varargin{:});

modelName = char(opts.ModelName);
% 确保 Simulink 库已加载（某些环境下可避免 add_block 的库解析问题）
load_system("simulink");
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
open_system(modelName);

% 基本仿真参数（对齐脚本）
set_param(modelName, ...
    "StopTime", char(opts.StopTime), ...
    "SolverType", "Variable-step", ...
    "Solver", "ode45", ...
    "MaxStep", char(opts.MaxStep), ...
    "SimulationMode", "normal" ...
);

% 须先于 add_block/set_param（含 Gain 为变量名）：否则 Simulink 校验 Gain 等工作区名会失败
local_initModelWorkspaceAndCallbacks(modelName);

% --------------------------
% 1) 顶层：放置 3 个积分器 + 导数计算子系统(Dynamics) + 输出 Readout
%    说明：为避免依赖 Stateflow（MATLAB Function 块），Dynamics 使用纯 Simulink 基础块搭建
% --------------------------
blk = struct();

% Integrators
blk.intNI = [modelName '/Int_NI'];
blk.intNR = [modelName '/Int_NR'];
blk.intA  = [modelName '/Int_A'];

local_add_block("simulink/Continuous/Integrator", blk.intNI, "Position", [120 80  170 120]);
local_add_block("simulink/Continuous/Integrator", blk.intNR, "Position", [120 150 170 190]);
local_add_block("simulink/Continuous/Integrator", blk.intA,  "Position", [120 220 170 260]);
set_param(blk.intNI, "InitialCondition", "NI0");
set_param(blk.intNR, "InitialCondition", "NR0");
set_param(blk.intA,  "InitialCondition", "A0");

% Dynamics（用 Subsystem + 基础块实现，避免 MATLAB Function/Stateflow 依赖）
blk.dyn = [modelName '/Dynamics'];
local_add_block("simulink/Ports & Subsystems/Subsystem", blk.dyn, "Position", [320 95 520 245]);

% Readout: Hill output & activation（用模块直接搭）
blk.readout = [modelName '/Readout'];
local_add_block("simulink/Ports & Subsystems/Subsystem", blk.readout, "Position", [620 130 790 230]);

% Scope（3个）
blk.muxPop = [modelName '/Mux_Pop'];
blk.scopePop = [modelName '/Scope_Pop_NI_NR'];
blk.scopeA = [modelName '/Scope_A'];
blk.scopeOut = [modelName '/Scope_Output'];
local_add_block("simulink/Signal Routing/Mux", blk.muxPop, "Inputs", "2", "Position", [820 70 840 110]);
local_add_block("simulink/Sinks/Scope", blk.scopePop, "Position", [880 55 930 115]);
local_add_block("simulink/Sinks/Scope", blk.scopeA,   "Position", [880 150 930 210]);
local_add_block("simulink/Sinks/Scope", blk.scopeOut, "Position", [880 240 930 300]);

% --------------------------
% 2) 先构建子系统内部（生成正确端口数量），再做顶层连线
% --------------------------
local_buildDynamicsSubsystem(blk.dyn);
local_buildReadoutSubsystem(blk.readout);

% 记录状态便于参数扫描（To Workspace）
blk.twNI = [modelName '/ToWorkspace_NI'];
blk.twNR = [modelName '/ToWorkspace_NR'];
blk.twA  = [modelName '/ToWorkspace_A'];
local_add_block("simulink/Sinks/To Workspace", blk.twNI, ...
    "VariableName", "qs_sim_NI", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820 125 880 145]);
local_add_block("simulink/Sinks/To Workspace", blk.twNR, ...
    "VariableName", "qs_sim_NR", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820 165 880 185]);
local_add_block("simulink/Sinks/To Workspace", blk.twA, ...
    "VariableName", "qs_sim_A", "SaveFormat", "Structure With Time", "Decimation", "1", ...
    "Position", [820 205 880 225]);

% --------------------------
% 3) 连线：Integrator -> Dynamics -> Integrator
% --------------------------
% Integrator outputs to Dynamics inputs (NI,NR,A)
add_line(modelName, "Int_NI/1", "Dynamics/1", "autorouting", "on");
add_line(modelName, "Int_NR/1", "Dynamics/2", "autorouting", "on");
add_line(modelName, "Int_A/1",  "Dynamics/3", "autorouting", "on");

% Dynamics outputs to Integrator inputs (dNI,dNR,dA)
add_line(modelName, "Dynamics/1", "Int_NI/1", "autorouting", "on");
add_line(modelName, "Dynamics/2", "Int_NR/1", "autorouting", "on");
add_line(modelName, "Dynamics/3", "Int_A/1",  "autorouting", "on");

% 连接到 Scope
add_line(modelName, "Int_NI/1", "Mux_Pop/1", "autorouting", "on");
add_line(modelName, "Int_NR/1", "Mux_Pop/2", "autorouting", "on");
add_line(modelName, "Mux_Pop/1", "Scope_Pop_NI_NR/1", "autorouting", "on");
add_line(modelName, "Int_A/1", "Scope_A/1", "autorouting", "on");

% Readout 子系统连接：A -> Readout
add_line(modelName, "Int_A/1", "Readout/1", "autorouting", "on");
add_line(modelName, "Readout/1", "Scope_Output/1", "autorouting", "on");

% To Workspace（与 Scope 并行取自积分器输出）
add_line(modelName, "Int_NI/1", "ToWorkspace_NI/1", "autorouting", "on");
add_line(modelName, "Int_NR/1", "ToWorkspace_NR/1", "autorouting", "on");
add_line(modelName, "Int_A/1", "ToWorkspace_A/1", "autorouting", "on");

% 美化布局（可选：自动排布）
try
    set_param(modelName, "SimulationCommand", "update");
catch ME %#ok<NASGU>
    % 未完全连线或参数未就绪时 update 可能失败，不中断建膜；调试时可查看 ME
end

if opts.SaveModel
    save_system(modelName);
end
if opts.RunDecepSweep
    local_runDecepSweep(modelName, opts.DecepSweepValues);
end
if opts.RunNpopSweep
    local_runNpopSweep(modelName, opts.NpopSweepValues);
end
if ~opts.OpenModel
    close_system(modelName, 0);
end
if opts.RunSim
    sim(modelName);
end
end

function local_buildDynamicsSubsystem(subsysPath)
% 端口：
% Inports:  NI, NR, A
% Outports: dNI, dNR, dA
%
% 方程（N = NI+NR, rho = NI/(N+rho_eps) 视为合作者/LuxI 频率）：
%   g      = 1 - N/K
%   dN/dt  = rI*NI*g + rR*NR*g
%   c_eff  = c_snow * decepStrength
%   雪堆：R=b_snow-c_eff/2, S=b_snow-c_eff, T=b_snow, P=0
%   U_C    = z_int * (R*rho + S*(1-rho)),  U_D = z_int * (T*rho + P*(1-rho))
%   drho   = eta_game * rho*(1-rho) * (U_C - U_D)
%   dNI    = N*drho + rho*dN/dt,   dNR = (1-rho)*dN/dt - N*drho
%   dA     = kA*NI - dA*A - delta_qs * N * A

Simulink.SubSystem.deleteContents(subsysPath);

% Inports/Outports（使用 In1/Out1 模板块，但以块名决定端口名）
inNI = [subsysPath '/NI'];
inNR = [subsysPath '/NR'];
inA  = [subsysPath '/A'];
outDNI = [subsysPath '/dNI'];
outDNR = [subsysPath '/dNR'];
outDA  = [subsysPath '/dA'];

local_add_block("simulink/Ports & Subsystems/In1",  inNI, "Position", [20 70 50 90]);
local_add_block("simulink/Ports & Subsystems/In1",  inNR, "Position", [20 120 50 140]);
local_add_block("simulink/Ports & Subsystems/In1",  inA,  "Position", [20 360 50 380]);
local_add_block("simulink/Ports & Subsystems/Out1", outDNI, "Position", [920 70 950 90]);
local_add_block("simulink/Ports & Subsystems/Out1", outDNR, "Position", [920 120 950 140]);
local_add_block("simulink/Ports & Subsystems/Out1", outDA,  "Position", [920 360 950 380]);

% ---------- N = NI+NR, rho = NI/(N+rho_eps), g = 1 - N/K ----------
sumN = [subsysPath '/Sum_NI_NR'];
local_add_block("simulink/Math Operations/Sum", sumN, "Inputs", "++", "Position", [100 92 135 128]);
add_line(subsysPath, "NI/1", "Sum_NI_NR/1", "autorouting", "on");
add_line(subsysPath, "NR/1", "Sum_NI_NR/2", "autorouting", "on");

cEps = [subsysPath '/c_rho_eps'];
sumNE = [subsysPath '/Sum_N_rho_eps'];
local_add_block("simulink/Sources/Constant", cEps, "Value", "rho_eps", "Position", [100 20 155 40]);
local_add_block("simulink/Math Operations/Sum", sumNE, "Inputs", "++", "Position", [180 85 215 125]);
add_line(subsysPath, "Sum_NI_NR/1", "Sum_N_rho_eps/1", "autorouting", "on");
add_line(subsysPath, "c_rho_eps/1", "Sum_N_rho_eps/2", "autorouting", "on");

divRho = [subsysPath '/Divide_rho'];
local_add_block("simulink/Math Operations/Divide", divRho, "Position", [260 85 305 125]);
add_line(subsysPath, "NI/1", "Divide_rho/1", "autorouting", "on");
add_line(subsysPath, "Sum_N_rho_eps/1", "Divide_rho/2", "autorouting", "on");

c1rho = [subsysPath '/c_one_rho'];
sumOmRho = [subsysPath '/one_minus_rho'];
local_add_block("simulink/Sources/Constant", c1rho, "Value", "1", "Position", [260 20 305 40]);
local_add_block("simulink/Math Operations/Sum", sumOmRho, "Inputs", "+-", "Position", [340 85 375 125]);
add_line(subsysPath, "c_one_rho/1", "one_minus_rho/1", "autorouting", "on");
add_line(subsysPath, "Divide_rho/1", "one_minus_rho/2", "autorouting", "on");

cK = [subsysPath '/c_K'];
divNK = [subsysPath '/Nsum_div_K'];
local_add_block("simulink/Sources/Constant", cK, "Value", "K", "Position", [400 20 450 40]);
local_add_block("simulink/Math Operations/Divide", divNK, "Position", [400 85 445 125]);
add_line(subsysPath, "Sum_NI_NR/1", "Nsum_div_K/1", "autorouting", "on");
add_line(subsysPath, "c_K/1", "Nsum_div_K/2", "autorouting", "on");

c1g = [subsysPath '/c_one'];
sumG = [subsysPath '/g_1_minus_frac'];
local_add_block("simulink/Sources/Constant", c1g, "Value", "1", "Position", [480 20 525 40]);
local_add_block("simulink/Math Operations/Sum", sumG, "Inputs", "+-", "Position", [480 85 515 125]);
add_line(subsysPath, "c_one/1", "g_1_minus_frac/1", "autorouting", "on");
add_line(subsysPath, "Nsum_div_K/1", "g_1_minus_frac/2", "autorouting", "on");

% dN/dt = rI*NI*g + rR*NR*g
gRI = [subsysPath '/Gain_rI'];
prodNIg = [subsysPath '/Prod_rI_NI_g'];
gRR = [subsysPath '/Gain_rR'];
prodNRg = [subsysPath '/Prod_rR_NR_g'];
sumDN = [subsysPath '/Sum_dN_dt'];
local_add_block("simulink/Math Operations/Gain", gRI, "Gain", "rI", "Position", [560 55 600 95]);
local_add_block("simulink/Math Operations/Product", prodNIg, "Position", [640 55 680 95]);
local_add_block("simulink/Math Operations/Gain", gRR, "Gain", "rR", "Position", [560 110 600 150]);
local_add_block("simulink/Math Operations/Product", prodNRg, "Position", [640 110 680 150]);
local_add_block("simulink/Math Operations/Sum", sumDN, "Inputs", "++", "Position", [720 75 755 125]);
add_line(subsysPath, "NI/1", "Gain_rI/1", "autorouting", "on");
add_line(subsysPath, "Gain_rI/1", "Prod_rI_NI_g/1", "autorouting", "on");
add_line(subsysPath, "g_1_minus_frac/1", "Prod_rI_NI_g/2", "autorouting", "on");
add_line(subsysPath, "NR/1", "Gain_rR/1", "autorouting", "on");
add_line(subsysPath, "Gain_rR/1", "Prod_rR_NR_g/1", "autorouting", "on");
add_line(subsysPath, "g_1_minus_frac/1", "Prod_rR_NR_g/2", "autorouting", "on");
add_line(subsysPath, "Prod_rI_NI_g/1", "Sum_dN_dt/1", "autorouting", "on");
add_line(subsysPath, "Prod_rR_NR_g/1", "Sum_dN_dt/2", "autorouting", "on");

% ---------- Snowdrift payoffs & drho ----------
cDecep = [subsysPath '/c_decepStrength'];
gCeff = [subsysPath '/Gain_c_snow_decep'];
local_add_block("simulink/Sources/Constant", cDecep, "Value", "decepStrength", "Position", [560 180 615 200]);
local_add_block("simulink/Math Operations/Gain", gCeff, "Gain", "c_snow", "Position", [640 175 680 205]);
add_line(subsysPath, "c_decepStrength/1", "Gain_c_snow_decep/1", "autorouting", "on");

gHalf = [subsysPath '/Gain_half_ceff'];
sumR = [subsysPath '/Sum_R_pay'];
cB = [subsysPath '/c_b_snow'];
sumS = [subsysPath '/Sum_S_pay'];
local_add_block("simulink/Math Operations/Gain", gHalf, "Gain", "0.5", "Position", [720 175 755 205]);
local_add_block("simulink/Math Operations/Sum", sumR, "Inputs", "+-", "Position", [800 165 835 205]);
local_add_block("simulink/Sources/Constant", cB, "Value", "b_snow", "Position", [720 220 775 240]);
local_add_block("simulink/Math Operations/Sum", sumS, "Inputs", "+-", "Position", [800 215 835 255]);
add_line(subsysPath, "Gain_c_snow_decep/1", "Gain_half_ceff/1", "autorouting", "on");
add_line(subsysPath, "c_b_snow/1", "Sum_R_pay/1", "autorouting", "on");
add_line(subsysPath, "Gain_half_ceff/1", "Sum_R_pay/2", "autorouting", "on");
add_line(subsysPath, "c_b_snow/1", "Sum_S_pay/1", "autorouting", "on");
add_line(subsysPath, "Gain_c_snow_decep/1", "Sum_S_pay/2", "autorouting", "on");

prodRrho = [subsysPath '/Prod_R_rho'];
prodSom = [subsysPath '/Prod_S_omr'];
sumUC0 = [subsysPath '/Sum_UC_terms'];
gZ = [subsysPath '/Gain_z_UC'];
prodTrho = [subsysPath '/Prod_T_rho'];
gZd = [subsysPath '/Gain_z_UD'];
sumDelta = [subsysPath '/Sum_payoff_diff'];
local_add_block("simulink/Math Operations/Product", prodRrho, "Position", [560 250 600 290]);
local_add_block("simulink/Math Operations/Product", prodSom, "Position", [560 300 600 340]);
local_add_block("simulink/Math Operations/Sum", sumUC0, "Inputs", "++", "Position", [640 265 675 305]);
local_add_block("simulink/Math Operations/Gain", gZ, "Gain", "z_int", "Position", [700 270 740 300]);
local_add_block("simulink/Math Operations/Product", prodTrho, "Position", [560 355 600 395]);
local_add_block("simulink/Math Operations/Gain", gZd, "Gain", "z_int", "Position", [640 360 680 390]);
local_add_block("simulink/Math Operations/Sum", sumDelta, "Inputs", "+-", "Position", [760 310 795 350]);
add_line(subsysPath, "Sum_R_pay/1", "Prod_R_rho/1", "autorouting", "on");
add_line(subsysPath, "Divide_rho/1", "Prod_R_rho/2", "autorouting", "on");
add_line(subsysPath, "Sum_S_pay/1", "Prod_S_omr/1", "autorouting", "on");
add_line(subsysPath, "one_minus_rho/1", "Prod_S_omr/2", "autorouting", "on");
add_line(subsysPath, "Prod_R_rho/1", "Sum_UC_terms/1", "autorouting", "on");
add_line(subsysPath, "Prod_S_omr/1", "Sum_UC_terms/2", "autorouting", "on");
add_line(subsysPath, "Sum_UC_terms/1", "Gain_z_UC/1", "autorouting", "on");
add_line(subsysPath, "c_b_snow/1", "Prod_T_rho/1", "autorouting", "on");
add_line(subsysPath, "Divide_rho/1", "Prod_T_rho/2", "autorouting", "on");
add_line(subsysPath, "Prod_T_rho/1", "Gain_z_UD/1", "autorouting", "on");
add_line(subsysPath, "Gain_z_UC/1", "Sum_payoff_diff/1", "autorouting", "on");
add_line(subsysPath, "Gain_z_UD/1", "Sum_payoff_diff/2", "autorouting", "on");

prodRhoOm = [subsysPath '/Prod_rho_omrho'];
prodCore = [subsysPath '/Prod_repl_core'];
gEta = [subsysPath '/Gain_eta_drho'];
local_add_block("simulink/Math Operations/Product", prodRhoOm, "Position", [820 250 860 290]);
local_add_block("simulink/Math Operations/Product", prodCore, "Position", [880 270 920 310]);
local_add_block("simulink/Math Operations/Gain", gEta, "Gain", "eta_game", "Position", [940 275 980 305]);
add_line(subsysPath, "Divide_rho/1", "Prod_rho_omrho/1", "autorouting", "on");
add_line(subsysPath, "one_minus_rho/1", "Prod_rho_omrho/2", "autorouting", "on");
add_line(subsysPath, "Prod_rho_omrho/1", "Prod_repl_core/1", "autorouting", "on");
add_line(subsysPath, "Sum_payoff_diff/1", "Prod_repl_core/2", "autorouting", "on");
add_line(subsysPath, "Prod_repl_core/1", "Gain_eta_drho/1", "autorouting", "on");

% dNI = N*drho + rho*dN,  dNR = (1-rho)*dN - N*drho
prodNdRho = [subsysPath '/Prod_N_drho'];
prodRhoDN = [subsysPath '/Prod_rho_dN'];
sumDNI = [subsysPath '/Sum_dNI'];
prodOmDN = [subsysPath '/Prod_omrho_dN'];
sumDNR = [subsysPath '/Sum_dNR'];
local_add_block("simulink/Math Operations/Product", prodNdRho, "Position", [720 30 760 70]);
local_add_block("simulink/Math Operations/Product", prodRhoDN, "Position", [800 30 840 70]);
local_add_block("simulink/Math Operations/Sum", sumDNI, "Inputs", "++", "Position", [880 40 915 80]);
local_add_block("simulink/Math Operations/Product", prodOmDN, "Position", [720 140 760 180]);
local_add_block("simulink/Math Operations/Sum", sumDNR, "Inputs", "+-", "Position", [880 140 915 180]);
add_line(subsysPath, "Sum_NI_NR/1", "Prod_N_drho/1", "autorouting", "on");
add_line(subsysPath, "Gain_eta_drho/1", "Prod_N_drho/2", "autorouting", "on");
add_line(subsysPath, "Divide_rho/1", "Prod_rho_dN/1", "autorouting", "on");
add_line(subsysPath, "Sum_dN_dt/1", "Prod_rho_dN/2", "autorouting", "on");
add_line(subsysPath, "Prod_N_drho/1", "Sum_dNI/1", "autorouting", "on");
add_line(subsysPath, "Prod_rho_dN/1", "Sum_dNI/2", "autorouting", "on");
add_line(subsysPath, "one_minus_rho/1", "Prod_omrho_dN/1", "autorouting", "on");
add_line(subsysPath, "Sum_dN_dt/1", "Prod_omrho_dN/2", "autorouting", "on");
add_line(subsysPath, "Prod_omrho_dN/1", "Sum_dNR/1", "autorouting", "on");
add_line(subsysPath, "Prod_N_drho/1", "Sum_dNR/2", "autorouting", "on");
add_line(subsysPath, "Sum_dNI/1", "dNI/1", "autorouting", "on");
add_line(subsysPath, "Sum_dNR/1", "dNR/1", "autorouting", "on");

% ---------- dA ----------
gkA = [subsysPath '/Gain_kA'];
local_add_block("simulink/Math Operations/Gain", gkA, "Gain", "kA", "Position", [180 330 220 370]);
add_line(subsysPath, "NI/1", "Gain_kA/1", "autorouting", "on");

gdA = [subsysPath '/Gain_dA'];
local_add_block("simulink/Math Operations/Gain", gdA, "Gain", "dA", "Position", [180 385 220 425]);
add_line(subsysPath, "A/1", "Gain_dA/1", "autorouting", "on");

prodNA = [subsysPath '/Prod_Nsum_A'];
gDelta = [subsysPath '/Gain_delta'];
local_add_block("simulink/Math Operations/Product", prodNA, "Position", [280 350 320 390]);
local_add_block("simulink/Math Operations/Gain", gDelta, "Gain", "delta_qs", "Position", [360 350 400 390]);
add_line(subsysPath, "Sum_NI_NR/1", "Prod_Nsum_A/1", "autorouting", "on");
add_line(subsysPath, "A/1", "Prod_Nsum_A/2", "autorouting", "on");
add_line(subsysPath, "Prod_Nsum_A/1", "Gain_delta/1", "autorouting", "on");

sumDA = [subsysPath '/Sum_dA'];
local_add_block("simulink/Math Operations/Sum", sumDA, "Inputs", "+--", "Position", [440 345 475 395]);
add_line(subsysPath, "Gain_kA/1",   "Sum_dA/1", "autorouting", "on");
add_line(subsysPath, "Gain_dA/1",   "Sum_dA/2", "autorouting", "on");
add_line(subsysPath, "Gain_delta/1","Sum_dA/3", "autorouting", "on");
add_line(subsysPath, "Sum_dA/1", "dA/1", "autorouting", "on");
end

function local_buildReadoutSubsystem(subsysPath)
% 端口：In1 = A, Out1 = Output
% 还额外计算 Activation，但这里不作为 outport；如需要可自行加 Outport

% 清空子系统默认内容（保留 Inport/Outport 的话更复杂；这里直接新建并连线）
Simulink.SubSystem.deleteContents(subsysPath);

% Inport/Outport
inA  = [subsysPath '/A'];
outY = [subsysPath '/Output'];
local_add_block("simulink/Ports & Subsystems/In1",  inA,  "Position", [60 90 90 110]);
local_add_block("simulink/Ports & Subsystems/Out1", outY, "Position", [520 90 550 110]);

% 常量：KA, n
c_KA = [subsysPath '/c_KA'];
c_n  = [subsysPath '/c_n'];
local_add_block("simulink/Sources/Constant", c_KA, "Value", "KA", "Position", [60 20 110 40]);
local_add_block("simulink/Sources/Constant", c_n,  "Value", "n",  "Position", [60 50 110 70]);

% A^n：Math Function (pow) 或 Function block
powA = [subsysPath '/A_pow_n'];
powKA = [subsysPath '/KA_pow_n'];
local_add_block("simulink/Math Operations/Math Function", powA,  "Operator", "pow", "Position", [160 80 210 120]);
local_add_block("simulink/Math Operations/Math Function", powKA, "Operator", "pow", "Position", [160 20 210 60]);

% KA^n + A^n
sumDen = [subsysPath '/Sum_den'];
local_add_block("simulink/Math Operations/Sum", sumDen, "Inputs", "++", "Position", [260 55 295 85]);

% Divide
div = [subsysPath '/Divide'];
local_add_block("simulink/Math Operations/Divide", div, "Position", [400 80 450 120]);

% Activation：A > KA（可视化用 Display）
rel = [subsysPath '/A_gt_KA'];
dispAct = [subsysPath '/Display_Activation'];
local_add_block("simulink/Logic and Bit Operations/Relational Operator", rel, "Operator", ">", "Position", [260 140 310 170]);
local_add_block("simulink/Sinks/Display", dispAct, "Position", [360 138 430 172]);

% 连线：pow 块的第二端口是指数
add_line(subsysPath, "A/1", "A_pow_n/1", "autorouting", "on");
add_line(subsysPath, "c_n/1", "A_pow_n/2", "autorouting", "on");

add_line(subsysPath, "c_KA/1", "KA_pow_n/1", "autorouting", "on");
add_line(subsysPath, "c_n/1",  "KA_pow_n/2", "autorouting", "on");

add_line(subsysPath, "KA_pow_n/1", "Sum_den/1", "autorouting", "on");
add_line(subsysPath, "A_pow_n/1",  "Sum_den/2", "autorouting", "on");

add_line(subsysPath, "A_pow_n/1", "Divide/1", "autorouting", "on");
add_line(subsysPath, "Sum_den/1", "Divide/2", "autorouting", "on");
add_line(subsysPath, "Divide/1", "Output/1", "autorouting", "on");

% Activation
add_line(subsysPath, "A/1", "A_gt_KA/1", "autorouting", "on");
add_line(subsysPath, "c_KA/1", "A_gt_KA/2", "autorouting", "on");
add_line(subsysPath, "A_gt_KA/1", "Display_Activation/1", "autorouting", "on");
end

function h = local_add_block(src, dst, varargin)
%LOCAL_ADD_BLOCK 包装 add_block：失败时给出更明确的 src/dst 信息
try
    h = add_block(src, dst, varargin{:});
catch ME
    % MATLAB 的 error/sprintf 对 string 的兼容性在不同版本/设置下可能不一致；
    % 这里统一转成 char，保证报错信息一定能打印出来。
    srcC = char(string(src));
    dstC = char(string(dst));
    msgC = ME.message;
    if isstring(msgC); msgC = char(msgC); end
    if ~ischar(msgC);  msgC = char(string(msgC)); end

    % 避免 horzcat 维度不一致：按“行”拼接，再用 newline 连接
    % 彻底避开 string/vertcat：用 cell + strjoin，兼容多行 message
    idC = ME.identifier;
    if isstring(idC); idC = char(idC); end
    if ~ischar(idC);  idC = char(string(idC)); end

    % 强制压成“单行字符”，避免 horzcat/vertcat 维度问题
    % 注意：某些情况下 char(...) 可能返回 N 维数组，不能直接用转置 .'。
    srcC = reshape(srcC(:), 1, []);
    dstC = reshape(dstC(:), 1, []);
    idC  = reshape(idC(:),  1, []);

    % msgC 已在上方规范为 char，此处不再重复判断（避免 Code Analyzer 报“无法到达”）
    % ME.message 可能是多行 char 矩阵，cellstr 可安全拆成多行 cell
    msgLines = cellstr(msgC);

    headLines = {
        'add_block 失败。'
        sprintf('  src(源库路径) = %s', srcC)
        sprintf('  dst(目标块路径) = %s', dstC)
        sprintf('  原始错误(%s):', idC)
    };

    fullMsg = strjoin([headLines; msgLines(:)], newline);
    error('build_modular_qs_simulink_model:add_block_failed', '%s', fullMsg);
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

function local_initModelWorkspaceAndCallbacks(modelName)
%LOCAL_INITMODELWORKSPACEANDCALLBACKS 写入模型工作区并设置 InitFcn（N_pop -> NI0/NR0）
mw = get_param(modelName, "ModelWorkspace");
try
    mw.clear;
catch
    % 旧版或无 clear 时忽略
end

local_modelWorkspaceAssign(mw, "rI", 0.7);
local_modelWorkspaceAssign(mw, "rR", 0.6);
local_modelWorkspaceAssign(mw, "K", 1.0);
local_modelWorkspaceAssign(mw, "kA", 0.1);
local_modelWorkspaceAssign(mw, "dA", 0.05);
local_modelWorkspaceAssign(mw, "delta_qs", 0.01);
local_modelWorkspaceAssign(mw, "KA", 5);
local_modelWorkspaceAssign(mw, "n", 2);
local_modelWorkspaceAssign(mw, "A0", 0);
% 雪堆博弈 + 复制子（见 local_buildDynamicsSubsystem 头注释）
local_modelWorkspaceAssign(mw, "b_snow", 1.0);
local_modelWorkspaceAssign(mw, "c_snow", 0.4);
local_modelWorkspaceAssign(mw, "z_int", 1.0);
local_modelWorkspaceAssign(mw, "eta_game", 0.35);
local_modelWorkspaceAssign(mw, "rho_eps", 1e-9);
local_modelWorkspaceAssign(mw, "decepStrength", 1.0);
local_modelWorkspaceAssign(mw, "N_pop", 0.2);
local_modelWorkspaceAssign(mw, "fracLuxI", 0.5);
Npop = 0.2;
frac = 0.5;
local_modelWorkspaceAssign(mw, "NI0", Npop * frac);
local_modelWorkspaceAssign(mw, "NR0", Npop * (1 - frac));

% InitFcn 默认在 base 工作区执行，直接写 NI0=... 会找不到模型工作区里的 N_pop。
% 用 evalin(ModelWorkspace) 在模型工作区内更新 NI0/NR0，与积分器 IC 引用的变量一致。
set_param(modelName, "InitFcn", ...
    "mw = get_param(bdroot,'ModelWorkspace'); evalin(mw,'NI0 = N_pop*fracLuxI; NR0 = N_pop*(1-fracLuxI);');");
end

function local_modelWorkspaceAssign(mw, name, value)
nameC = char(string(name));
try
    mw.assignin(nameC, value);
catch
    if isnumeric(value) && isscalar(value) && isreal(value)
        evalin(mw, sprintf("%s = %.16g;", nameC, double(value)));
    else
        evalin(mw, sprintf("%s = %s;", nameC, mat2str(value)));
    end
end
end

function [t, y] = local_structWithTime2ty(s)
%LOCAL_STRUCTWITHTIME2TY 从 To Workspace 的 Structure With Time 取出时间与标量序列
if ~isstruct(s) || ~isfield(s, "time") || ~isfield(s, "signals")
    t = [];
    y = [];
    return;
end
t = s.time(:);
sig = s.signals;
if isstruct(sig) && isfield(sig, "values")
    y = sig.values;
else
    y = [];
    return;
end
y = squeeze(y);
if size(y, 2) > 1
    y = y(:, 1);
end
y = y(:);
end

function local_runDecepSweep(modelName, sweepVals)
%LOCAL_RUNDEEPSWEEP 扫描欺骗强度：末段振荡强度（std）与 LuxI 占比（探索分岔/周期征兆）
sweepVals = sweepVals(:).';
mw = get_param(modelName, "ModelWorkspace");
n = numel(sweepVals);
stdNI = nan(1, n);
fracI = nan(1, n);
for k = 1:n
    local_modelWorkspaceAssign(mw, "decepStrength", sweepVals(k));
    sim(modelName);
    if evalin("base", "exist('qs_sim_NI','var')")
        [t, yNI] = local_structWithTime2ty(evalin("base", "qs_sim_NI"));
        [~, yNR] = local_structWithTime2ty(evalin("base", "qs_sim_NR"));
    else
        warning("build_modular_qs_simulink_model:NoLog", ...
            "未找到 qs_sim_NI（To Workspace 是否写入 base？）。跳过 decepStrength=%g。", sweepVals(k));
        continue;
    end
    if numel(t) < 5
        continue;
    end
    i0 = max(1, floor(0.7 * numel(t)));
    stdNI(k) = std(yNI(i0:end));
    mI = mean(yNI(i0:end));
    mR = mean(yNR(i0:end));
    fracI(k) = mI / (mI + mR + eps);
end
figure("Name", "QS 欺骗强度扫描", "Color", "w");
subplot(2, 1, 1);
plot(sweepVals, stdNI, "-o", "LineWidth", 1.5);
grid on;
xlabel("decepStrength（c_eff = c_snow * decepStrength，雪堆支付）");
ylabel("末段 std(NI)（越大表示振荡/非稳态越强）");
title("欺骗强度 vs 种群动态波动指标");

subplot(2, 1, 2);
plot(sweepVals, fracI, "-s", "LineWidth", 1.5);
ylim([0 1]);
grid on;
xlabel("decepStrength");
ylabel("稳态段 mean(NI)/(mean(NI)+mean(NR))");
title("欺骗强度 vs LuxI 相对占比（复制子+雪堆）");
sgtitle("参数扫描：欺骗强度（雪堆-复制子耦合；可延长 StopTime 并做相图/分岔）");
end

function local_runNpopSweep(modelName, sweepVals)
%LOCAL_RUNNPOPSWEEP 扫描总种群 N_pop：同样用末段 std 与占比衡量“稳定性/结构”
sweepVals = sweepVals(:).';
mw = get_param(modelName, "ModelWorkspace");
n = numel(sweepVals);
stdNI = nan(1, n);
fracI = nan(1, n);
for k = 1:n
    local_modelWorkspaceAssign(mw, "N_pop", sweepVals(k));
    sim(modelName);
    if ~evalin("base", "exist('qs_sim_NI','var')")
        warning("build_modular_qs_simulink_model:NoLog", "未找到 qs_sim_NI，跳过 N_pop=%g。", sweepVals(k));
        continue;
    end
    [t, yNI] = local_structWithTime2ty(evalin("base", "qs_sim_NI"));
    [~, yNR] = local_structWithTime2ty(evalin("base", "qs_sim_NR"));
    if numel(t) < 5
        continue;
    end
    i0 = max(1, floor(0.7 * numel(t)));
    stdNI(k) = std(yNI(i0:end));
    mI = mean(yNI(i0:end));
    mR = mean(yNR(i0:end));
    fracI(k) = mI / (mI + mR + eps);
end
figure("Name", "QS N_pop 扫描", "Color", "w");
subplot(2, 1, 1);
plot(sweepVals, stdNI, "-o", "LineWidth", 1.5);
grid on;
xlabel("N_{pop}（总初始种群 NI0+NR0）");
ylabel("末段 std(NI)");
title("种群规模 vs 动态波动（寻找 std 突变的临界区）");

subplot(2, 1, 2);
plot(sweepVals, fracI, "-s", "LineWidth", 1.5);
ylim([0 1]);
grid on;
xlabel("N_{pop}");
ylabel("mean(NI)/(mean(NI)+mean(NR))");
title("种群规模 vs 稳态结构");
sgtitle("参数扫描：N_{pop}（可在 Model Explorer 中同时调 K 与 N_{pop} 做对比）");
end

