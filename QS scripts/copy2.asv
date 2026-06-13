function modelName = build_modular_qs_simulink_model(varargin)
%BUILD_MODULAR_QS_SIMULINK_MODEL 用 MATLAB 代码搭建 Simulink 模型（多菌群 + 公共物品适应度）
%
% 欺骗/合作以「多性状公共物品」适应度量化（可推广到 M 菌株 × nTraits 性状）：
%   p_ch(i) = Σ_j f_j·(1 - produce_{j,i})，f_j = x_j/N
%   ω_j = ω0 + Σ_i b_i(1 - p_ch(i)) - Σ_i c_i·produce_{j,i}·decepStrength
%   dx_j/dt = x_j·r·(1-N/K) + η·x_j·(ω_j - \bar{ω})
%   dA/dt = Σ_j kA_j·x_j - dA·A - δ·N·A
% 默认 produce（nTraits=2, M=4）：合作者 / 只欺瞒性状1 / 只欺瞒性状2 / 两性状均不生产（纯搭便车）。
% 形状1 形状2
% 欺骗 不欺骗 3个菌的所有拓扑结构 菌群稳定性指标 菌株的个数 
% 【备注】默认经济参数（演示用，打破对称）
%   若 b1=b2 且 c1=c2，且初值比例相同，则「只欺瞒性状1」与「只欺瞒性状2」两株有 ω2=B−c2、
%   ω3=B−c1 恒相等，复制子方程对称，Mux_Pop(2) 与 Mux_Pop(3) 会完全重合。
%   下列为脚本内置默认（未传入 b_vec/c_vec 时写入 Model Workspace）：
%     nTraits=2 ： b_vec = [0.58, 0.36]  （性状1 公共收益权重高于性状2）
%                c_vec = [0.24, 0.16]  （承担性状1 成本高于性状2，故欺骗株 2、3 不再等价）
%     nTraits>2 ： b_vec、c_vec 用 linspace 在相近量级上略单调变化，避免多株偶然全对称。
%   论文定标时请按实验/文献替换，或通过 Name-Value「b_vec」「c_vec」覆盖。
%
% 依赖同目录下 qs_mspg_rhs_impl.m、qs_mspg_rhs_component.m（每状态一个 MATLAB Fcn 标量输出）；
% 构建时会 addpath 本脚本目录。
%
% 用法：
%   build_modular_qs_simulink_model
%   build_modular_qs_simulink_model("ModelName","qs_modular_mspg")
%   build_modular_qs_simulink_model("OpenModel",true,"RunSim",true)
%   build_modular_qs_simulink_model("RunDecepSweep",true)
%   build_modular_qs_simulink_model("RunNpopSweep",true)
%   build_modular_qs_simulink_model("NumStrains",3,"nTraits",2, ...)  % 若不要「全隐瞒」株可改回 M=3
%
% 说明：求解器 variable-step/ode45；参数在 Model Workspace；InitFcn 根据 N_pop、frac_init 写 x0_1..x0_M

scriptDir = fileparts(mfilename("fullpath"));
if ~isempty(scriptDir)
    addpath(scriptDir);
end

opts = struct( ...
    "ModelName", "qs_modular_mspg", ...  % 避免与路径上 qs_modular_sys.* 同名遮蔽
    "OpenModel", true, ...
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
    "kA_vec", [] ...         % 空则仅菌株 1 产 AHL
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
open_system(modelName);

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
        error("build_modular_qs_simulink_model:BadB", "b_vec 长度须等于 nTraits (%d)。", nTraits);
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
        error("build_modular_qs_simulink_model:BadC", "c_vec 长度须等于 nTraits (%d)。", nTraits);
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
        error("build_modular_qs_simulink_model:BadProduce", ...
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
        error("build_modular_qs_simulink_model:BadKA", "kA_vec 长度须等于 NumStrains (%d)。", M);
    end
end
local_modelWorkspaceAssign(mw, "kA_vec", kA);

local_modelWorkspaceAssign(mw, "dA", 0.05);
local_modelWorkspaceAssign(mw, "delta_qs", 0.01);
local_modelWorkspaceAssign(mw, "KA", 5);
local_modelWorkspaceAssign(mw, "n", 2);
local_modelWorkspaceAssign(mw, "A0", 0);

local_modelWorkspaceAssign(mw, "N_pop", 0.2);
if isempty(opts.FracInit)
    frac = ones(1, M) / M;
else
    frac = reshape(double(opts.FracInit), 1, []);
    if numel(frac) ~= M
        error("build_modular_qs_simulink_model:BadFrac", "FracInit 长度须等于 NumStrains (%d)。", M);
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
        warning("build_modular_qs_simulink_model:NoLog", ...
            "未找到 qs_sim_pop。跳过 decepStrength=%g。", sweepVals(k));
        continue;
    end
    [t, Y] = local_structPopToMatrix(evalin("base", "qs_sim_pop"), M);
    if isempty(t) || size(Y, 2) ~= M
        warning("build_modular_qs_simulink_model:BadLog", "qs_sim_pop 维度异常，跳过。");
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
        warning("build_modular_qs_simulink_model:NoLog", "未找到 qs_sim_pop，跳过 N_pop=%g。", sweepVals(k));
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
