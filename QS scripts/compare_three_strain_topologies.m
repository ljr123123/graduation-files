%% COMPARE_THREE_STRAIN_TOPOLOGIES 三菌株 × 四类型策略 → 4³ 拓扑批仿真与图表（默认 64；可选 20）
%
% 「性状公共」主图：B_trait·(1+qsBoost·φ(A))（与 qs_mspg_rhs_impl 一致；产 A 拓扑与 kA 全 0 拓扑可区分）。
% 辅助图：Σ b_i(1-p_ch) 仅合作结构、不含 QS。
%
% 单株四类（见 topology_catalog_3strain_4types.md：主表 20 种规范序 + 附录 64）。
% 若认为三株无标号（仅 multiset），设 ONLY_UNLABELED_20=true（见下，默认仅在工作区未定义时写入）。
%
% 用法：在本脚本所在目录运行  compare_three_strain_topologies
% 强制重算（忽略 .mat 缓存）：先在命令行执行  FORCE_RERUN_SIM = true  再运行本脚本
% （勿在脚本里写死 false，否则会覆盖命令行设置；本脚本已改为「仅未定义时才赋默认值」。）

clear qs_sim_A qs_sim_pop %#ok<CLSCR>

if ~exist('ONLY_UNLABELED_20', 'var') %#ok<EXIST>
    ONLY_UNLABELED_20 = true;
end
if ~exist('FORCE_RERUN_SIM', 'var') %#ok<EXIST>
    FORCE_RERUN_SIM = false;
end
% 缓存：qs_topology_sim_cache_unlabeled20.mat | qs_topology_sim_cache_full64.mat

scriptDir = fileparts(mfilename("fullpath"));
if ~isempty(scriptDir)
    addpath(scriptDir);
end

M = 3;
K = 2;
modelName = "qs_topo3_compare";

build_modular_qs_simulink_model( ...
    "ModelName", modelName, ...
    "NumStrains", M, ...
    "nTraits", K, ...
    "OpenModel", false, ...
    "RunSim", false, ...
    "SaveModel", true, ...
    "StopTime", "48", ...
    "MaxStep", "0.1" ...
);

% OpenModel=false 时构建函数会 close_system，内存中无模型；仿真前必须重新加载
modelNameC = char(modelName);
if ~bdIsLoaded(modelNameC)
    load_system(modelNameC);
end
% R2019a+ 默认「Single simulation output」时，To Workspace 数据进 SimulationOutput，不进 base
try
    rwo = get_param(modelNameC, "ReturnWorkspaceOutputs");
    if any(strcmpi(string(rwo), ["on", "1"]))
        set_param(modelNameC, "ReturnWorkspaceOutputs", "off");
    end
catch %#ok<CTCH>
end
mw = get_param(modelNameC, "ModelWorkspace");

% 与 qs_mspg_rhs_impl 一致，用于由种群轨迹反算适应度 ω_j、\bar{ω}
% Model Workspace 中变量可能是数值，也可能是 Simulink.Parameter；勿对 evalin 结果直接写 (:)
omega0 = local_mwToDoubleScalar(mw, "omega0");
b_vec_m = local_mwToDoubleVector(mw, "b_vec");
c_vec_m = local_mwToDoubleVector(mw, "c_vec");
decepStrength_m = local_mwToDoubleScalar(mw, "decepStrength");
epsN_m = local_mwToDoubleScalar(mw, "epsN");
KA_m = local_mwToDoubleScalarOr(mw, "KA", 5);
n_m = local_mwToDoubleScalarOr(mw, "n", 2);
qsBoost_m = local_mwToDoubleScalarOr(mw, "qsBoost", 0);
c_signal_m = local_mwToDoubleScalarOr(mw, "c_signal", 0);

% 总产 A 预算 kA_sum；64 种拓扑由 catalog 分配 produce / kA_vec
kA_sum = 0.1;
if isempty(scriptDir)
    mdOut = fullfile(pwd, "topology_catalog_3strain_4types.md");
else
    mdOut = fullfile(scriptDir, "topology_catalog_3strain_4types.md");
end
catalog = topology_catalog_3strain_4type(M, K, kA_sum, mdOut);
fprintf(1, "已生成拓扑说明 Markdown（主表 20 + 附录 64）：%s\n", mdOut);

if ONLY_UNLABELED_20
    keep = arrayfun(@(k) local_typesNonDecreasing(catalog(k)), 1:numel(catalog));
    catalog = catalog(keep);
    fprintf(1, "ONLY_UNLABELED_20=true：保留规范序 t1<=t2<=t3，共 %d 种 multiset 代表。\n", numel(catalog));
end

nTopo = numel(catalog);
codeLabels = arrayfun(@(c) char(c.code), catalog, "UniformOutput", false);

t_stop = str2double(get_param(modelNameC, "StopTime"));
Nt_ref = 200;
t_ref = linspace(0, t_stop, Nt_ref).';
Amat = nan(Nt_ref, nTopo);
OmBmat = nan(Nt_ref, nTopo);
Gmat = nan(Nt_ref, nTopo);
PubMat = nan(Nt_ref, nTopo);
PubBoostMat = nan(Nt_ref, nTopo);
PubDeltaMat = nan(Nt_ref, nTopo);
CostTraitMat = nan(Nt_ref, nTopo);
CostSignalMat = nan(Nt_ref, nTopo);
CostSumMat = nan(Nt_ref, nTopo);
tailMean = nan(nTopo, 1);
tailOmegaBar = nan(nTopo, 1);
tailGeoMean = nan(nTopo, 1);
tailPubMean = nan(nTopo, 1);
tailPubBoostMean = nan(nTopo, 1);
tailPubDeltaMean = nan(nTopo, 1);
tailCostTrait = nan(nTopo, 1);
tailCostSignal = nan(nTopo, 1);
tailCostSum = nan(nTopo, 1);
omegaBarCell = cell(nTopo, 1);
omegaAllCell = cell(nTopo, 1);
tPopCell = cell(nTopo, 1);
geoMeanCell = cell(nTopo, 1);

if isempty(scriptDir)
    cacheDir = pwd;
else
    cacheDir = scriptDir;
end
if ONLY_UNLABELED_20
    cacheTag = "unlabeled20";
else
    cacheTag = "full64";
end
SIM_CACHE_FILE = fullfile(cacheDir, sprintf("qs_topology_sim_cache_%s.mat", cacheTag));

simMeta = struct( ...
    "onlyUnlabeled", ONLY_UNLABELED_20, ...
    "nTopo", nTopo, ...
    "codes", {codeLabels}, ...
    "kA_sum", kA_sum, ...
    "t_stop", t_stop, ...
    "Nt_ref", Nt_ref, ...
    "M", M, ...
    "K", K, ...
    "modelName", modelNameC, ...
    "b_vec", b_vec_m(:).', ...
    "c_vec", c_vec_m(:).', ...
    "decepStrength", decepStrength_m, ...
    "omega0", omega0, ...
    "epsN", epsN_m, ...
    "KA", KA_m, ...
    "n", n_m, ...
    "qsBoost", qsBoost_m, ...
    "c_signal", c_signal_m);

fromCache = false;
if ~FORCE_RERUN_SIM && exist(SIM_CACHE_FILE, 'file') %#ok<EXIST>
    Sd = load(SIM_CACHE_FILE);
    if isfield(Sd, "simMeta") && isfield(Sd, "t_ref") && isfield(Sd, "Amat")
        if local_simMetaMatches(Sd.simMeta, simMeta)
            t_ref = Sd.t_ref;
            Amat = Sd.Amat;
            OmBmat = Sd.OmBmat;
            Gmat = Sd.Gmat;
            tailMean = Sd.tailMean;
            tailOmegaBar = Sd.tailOmegaBar;
            tailGeoMean = Sd.tailGeoMean;
            if isfield(Sd, "PubMat"), PubMat = Sd.PubMat; end
            if isfield(Sd, "tailPubMean"), tailPubMean = Sd.tailPubMean; end
            if isfield(Sd, "PubBoostMat"), PubBoostMat = Sd.PubBoostMat; end
            if isfield(Sd, "tailPubBoostMean"), tailPubBoostMean = Sd.tailPubBoostMean; end
            if isfield(Sd, "PubDeltaMat"), PubDeltaMat = Sd.PubDeltaMat; end
            if isfield(Sd, "tailPubDeltaMean"), tailPubDeltaMean = Sd.tailPubDeltaMean; end
            if isfield(Sd, "CostTraitMat"), CostTraitMat = Sd.CostTraitMat; end
            if isfield(Sd, "CostSignalMat"), CostSignalMat = Sd.CostSignalMat; end
            if isfield(Sd, "CostSumMat"), CostSumMat = Sd.CostSumMat; end
            if isfield(Sd, "tailCostTrait"), tailCostTrait = Sd.tailCostTrait; end
            if isfield(Sd, "tailCostSignal"), tailCostSignal = Sd.tailCostSignal; end
            if isfield(Sd, "tailCostSum"), tailCostSum = Sd.tailCostSum; end
            if isfield(Sd, "omegaBarCell"), omegaBarCell = Sd.omegaBarCell; end
            if isfield(Sd, "omegaAllCell"), omegaAllCell = Sd.omegaAllCell; end
            if isfield(Sd, "tPopCell"), tPopCell = Sd.tPopCell; end
            if isfield(Sd, "geoMeanCell"), geoMeanCell = Sd.geoMeanCell; end
            fromCache = true;
            fprintf(1, "已载入仿真缓存（跳过 Simulink）：%s\n", SIM_CACHE_FILE);
            if ~isfield(Sd, "PubMat") || ~isfield(Sd, "tailPubMean")
                warning("compare_three_strain_topologies:StaleCache", ...
                    "缓存无「性状公共物」字段，性状公共产物图将为空；请设 FORCE_RERUN_SIM=true 后重跑一次以写入新缓存。");
            end
            if ~isfield(Sd, "PubBoostMat")
                warning("compare_three_strain_topologies:StaleCache", ...
                    "缓存无「有效公共收益」字段；请设 FORCE_RERUN_SIM=true 以生成含 φ(A) 的公共收益热图。");
            end
            if ~isfield(Sd, "CostSumMat")
                warning("compare_three_strain_topologies:StaleCache", ...
                    "缓存无「资源消耗」字段；请设 FORCE_RERUN_SIM=true 以生成性状+信号代价图。");
            end
        else
            fprintf(1, "缓存与当前参数/拓扑列表不一致，将重新仿真。删除旧文件可清缓存：%s\n", SIM_CACHE_FILE);
        end
    end
end

% 旧缓存仅有 PubMat+PubBoostMat 时，用差分得到「QS 额外公共收益」（与定义 S_eff−S_raw 一致）
if fromCache && all(isnan(PubDeltaMat(:)))
    if any(~isnan(PubBoostMat(:))) && any(~isnan(PubMat(:)))
        PubDeltaMat = PubBoostMat - PubMat;
        i0d = max(1, floor(0.7 * Nt_ref));
        tailPubDeltaMean = mean(PubDeltaMat(i0d:end, :), 1, 'omitnan').';
    end
end

% 旧缓存无总代价矩阵时由分量相加
if fromCache && all(isnan(CostSumMat(:)))
    if any(~isnan(CostTraitMat(:))) && any(~isnan(CostSignalMat(:)))
        CostSumMat = CostTraitMat + CostSignalMat;
        i0c = max(1, floor(0.7 * Nt_ref));
        tailCostTrait = mean(CostTraitMat(i0c:end, :), 1, 'omitnan').';
        tailCostSignal = mean(CostSignalMat(i0c:end, :), 1, 'omitnan').';
        tailCostSum = mean(CostSumMat(i0c:end, :), 1, 'omitnan').';
    end
end

if ~fromCache
    wbName = sprintf("%d 拓扑批仿真", nTopo);
    hwProgress = waitbar(0, "准备开始…", "Name", wbName);
    try
        for s = 1:nTopo
            waitbar((s - 1) / nTopo, hwProgress, ...
                sprintf("仿真中 %d/%d · ID=%d · %s", s, nTopo, catalog(s).id, catalog(s).code));
            topo_assignProduceKA(mw, catalog(s).produce, catalog(s).kA_vec);
            simOut = sim(modelNameC);
            SA = local_getQsSimA(simOut);
            if isempty(SA)
                warning("compare_three_strain_topologies:NoA", ...
                    "未取得 qs_sim_A，跳过 ID=%d %s", catalog(s).id, catalog(s).code);
                waitbar(s / nTopo, hwProgress, ...
                    sprintf("已处理 %d/%d（缺 qs_sim_A）· %s", s, nTopo, catalog(s).code));
                continue;
            end
            t = SA.time(:);
            a = squeeze(SA.signals.values);
            if ~iscolumn(a)
                if size(a, 2) > 1
                    a = a(:, 1);
                end
                a = a(:);
            end
            Amat(:, s) = interp1(t, a, t_ref, "linear", NaN);
            if numel(t) >= 5
                i0 = max(1, floor(0.7 * numel(t)));
                tailMean(s) = mean(a(i0:end));
            end

            SP = local_getQsSimPop(simOut);
            [tpop, Xpop] = local_structPopToMatrix(SP, M);
            if isempty(tpop) || isempty(Xpop) || size(Xpop, 2) ~= M
                warning("compare_three_strain_topologies:NoPop", ...
                    "未取得 qs_sim_pop，ID=%d %s", catalog(s).id, catalog(s).code);
            else
                AonPop = interp1(t, a, tpop, "linear", 0);
                [omBar, omAll] = local_omegaFromPop(Xpop, catalog(s).produce, ...
                    b_vec_m, c_vec_m, decepStrength_m, omega0, epsN_m, AonPop, ...
                    KA_m, n_m, qsBoost_m, c_signal_m, catalog(s).kA_vec);
                omegaBarCell{s} = omBar;
                omegaAllCell{s} = omAll;
                tPopCell{s} = tpop;
                OmBmat(:, s) = interp1(tpop, omBar, t_ref, "linear", NaN);
                if numel(omBar) >= 5
                    i0o = max(1, floor(0.7 * numel(omBar)));
                    tailOmegaBar(s) = mean(omBar(i0o:end));
                end
                gvec = local_geomMeanAbundance(Xpop);
                geoMeanCell{s} = gvec;
                Gmat(:, s) = interp1(tpop, gvec, t_ref, "linear", NaN);
                if numel(gvec) >= 5
                    ig = max(1, floor(0.7 * numel(gvec)));
                    tailGeoMean(s) = mean(gvec(ig:end));
                end
                Svec = local_traitPublicSupplyFromPop(Xpop, catalog(s).produce, b_vec_m, epsN_m);
                PubMat(:, s) = interp1(tpop, Svec, t_ref, "linear", NaN);
                if numel(Svec) >= 5
                    ips = max(1, floor(0.7 * numel(Svec)));
                    tailPubMean(s) = mean(Svec(ips:end));
                end
                Sboost = local_boostedTraitBenefitFromPop(Xpop, catalog(s).produce, b_vec_m, epsN_m, ...
                    AonPop, KA_m, n_m, qsBoost_m);
                PubBoostMat(:, s) = interp1(tpop, Sboost, t_ref, "linear", NaN);
                if numel(Sboost) >= 5
                    ipb = max(1, floor(0.7 * numel(Sboost)));
                    tailPubBoostMean(s) = mean(Sboost(ipb:end));
                end
                Dvec = Sboost - Svec;
                PubDeltaMat(:, s) = interp1(tpop, Dvec, t_ref, "linear", NaN);
                if numel(Dvec) >= 5
                    ipd = max(1, floor(0.7 * numel(Dvec)));
                    tailPubDeltaMean(s) = mean(Dvec(ipd:end));
                end
                [Ctvec, Csvec, Csumvec] = local_communityWeightedCostFromPop(Xpop, catalog(s).produce, ...
                    c_vec_m, decepStrength_m, epsN_m, c_signal_m, catalog(s).kA_vec);
                CostTraitMat(:, s) = interp1(tpop, Ctvec, t_ref, "linear", NaN);
                CostSignalMat(:, s) = interp1(tpop, Csvec, t_ref, "linear", NaN);
                CostSumMat(:, s) = interp1(tpop, Csumvec, t_ref, "linear", NaN);
                if numel(Csumvec) >= 5
                    icc = max(1, floor(0.7 * numel(Csumvec)));
                    tailCostTrait(s) = mean(Ctvec(icc:end));
                    tailCostSignal(s) = mean(Csvec(icc:end));
                    tailCostSum(s) = mean(Csumvec(icc:end));
                end
            end
            waitbar(s / nTopo, hwProgress, ...
                sprintf("已完成 %d/%d · %s", s, nTopo, catalog(s).code));
        end
    catch ME
        local_safeCloseWaitbar(hwProgress);
        rethrow(ME);
    end
    local_safeCloseWaitbar(hwProgress);

    save(SIM_CACHE_FILE, ...
        "simMeta", "t_ref", "Amat", "OmBmat", "Gmat", "PubMat", "PubBoostMat", "PubDeltaMat", ...
        "CostTraitMat", "CostSignalMat", "CostSumMat", ...
        "tailMean", "tailOmegaBar", "tailGeoMean", "tailPubMean", "tailPubBoostMean", "tailPubDeltaMean", ...
        "tailCostTrait", "tailCostSignal", "tailCostSum", ...
        "omegaBarCell", "omegaAllCell", "tPopCell", "geoMeanCell", "-v7.3");
    fprintf(1, "仿真结果已保存：%s\n", SIM_CACHE_FILE);
end

local_plotHeatBar(sprintf("%d 拓扑：A(t) 热图与末段均值", nTopo), {t_ref, Amat, tailMean, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "A", "mean(A) 后30%"});

local_plotHeatBar(sprintf("%d 拓扑：平均适应度热图与末段均值", nTopo), {t_ref, OmBmat, tailOmegaBar, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "平均适应度", "mean(omega-bar) 后30%"});

local_plotHeatBar(sprintf("%d 拓扑：几何平均丰度热图与末段均值", nTopo), {t_ref, Gmat, tailGeoMean, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "几何平均丰度 G", "mean(G) 后30%"});

% 主图：含 QS 的性状层公共收益（有 A 时 φ>0 倍率>1；无产 A 如 2-2-2 则 φ≈0、倍率≈1）；辅图：无 A 结构量
local_plotHeatBar(sprintf("%d 拓扑：性状层公共收益（含 QS 放大，与动力学一致）", nTopo), {t_ref, PubBoostMat, tailPubBoostMean, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "B_{trait}·(1+qsBoost·φ)", "mean(·) 后30%"});
local_plotHeatBar(sprintf("%d 拓扑：合作结构基准（无 QS，仅 Σ b_i(1-p_ch)）", nTopo), {t_ref, PubMat, tailPubMean, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "S = sum b_i(1-p_ch)", "mean(S) 后30%"});
local_plotHeatBar(sprintf("%d 拓扑：QS 额外公共收益 Δ=B_{trait}·qsBoost·φ(A)", nTopo), {t_ref, PubDeltaMat, tailPubDeltaMean, codeLabels, ...
    "时间", sprintf("拓扑索引（1-%d）", nTopo), "Δ（仅由信号引起）", "mean(Δ) 后30%"});

% 与 qs_mspg_rhs_impl 一致：C_trait=Σ f_j(produce·c)_j，C_signal=Σ f_j(c_signal·kA_j)（适应度 payoff 意义下的代价）
local_plotResourceCostFig(sprintf("%d 拓扑：生产公共性状与信号的资源消耗（种群加权）", nTopo), ...
    t_ref, CostSumMat, CostTraitMat, CostSignalMat, tailCostSum, tailCostTrait, tailCostSignal, codeLabels);

function tf = local_simMetaMatches(a, b)
tf = false;
req = {'onlyUnlabeled', 'nTopo', 'kA_sum', 't_stop', 'Nt_ref', 'M', 'K', ...
    'decepStrength', 'omega0', 'epsN', 'b_vec', 'c_vec', 'KA', 'n', 'qsBoost', 'c_signal'};
for i = 1:numel(req)
    f = req{i};
    if ~isfield(a, f) || ~isfield(b, f)
        return;
    end
    av = a.(f);
    bv = b.(f);
    if strcmp(f, 'onlyUnlabeled')
        if logical(av) ~= logical(bv)
            return;
        end
        continue;
    end
    if isnumeric(av) && isnumeric(bv)
        if ~isequal(double(av(:)), double(bv(:)))
            return;
        end
    else
        if ~isequal(av, bv)
            return;
        end
    end
end
if ~isfield(a, 'codes') || ~isfield(b, 'codes')
    return;
end
ca = a.codes;
cb = b.codes;
if ~iscell(ca), ca = cellstr(ca); end
if ~iscell(cb), cb = cellstr(cb); end
if ~isequal(ca(:), cb(:))
    return;
end
if isfield(a, 'modelName') && isfield(b, 'modelName') && ~isequal(a.modelName, b.modelName)
    return;
end
tf = true;
end

function tf = local_typesNonDecreasing(entry)
v = reshape(double(entry.types), 1, []);
tf = all(diff(v) >= 0);
end

function local_safeCloseWaitbar(h)
if nargin < 1 || isempty(h)
    return;
end
try %#ok<TRYNC>
    close(h);
catch
end
end

function local_plotHeatBar(figName, argv)
% 用 8 元 cell 传参：t_ref, Zmat, tailVec, codeLabels, xlab, ylab热图, cbLabel, ylabBar
if nargin < 2 || ~iscell(argv) || numel(argv) ~= 8 %#ok<*ISCELL>
    error("compare_three_strain_topologies:HeatBarArgs", ...
        "local_plotHeatBar 需要 (figName, {t_ref, Zmat, tailVec, codeLabels, xlab, ylab热图, cbLabel, ylabBar})，共 8 项。");
end
[t_ref, Zmat, tailVec, codeLabels, xlabTxt, ylabHeatTxt, cbLabelTxt, ylabBarTxt] = argv{:};
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
cb.Label.String = cbLabelTxt;
xlabel(xlabTxt);
yla = ylabHeatTxt;
ylabel(yla);
title("热图（纵轴：拓扑 ID；横轴：时间）");

subplot(2, 1, 2);
try %#ok<TRYNC>
    bar(tailVec, "FaceColor", [0.38 0.55 0.78]);
catch
    bar(tailVec);
end
nB = numel(tailVec);
try %#ok<TRYNC>
    set(gca, "XTick", 1:nB, "XTickLabel", codeLabels, "XTickLabelRotation", 90);
catch
    set(gca, 'XTick', 1:nB, 'XTickLabel', codeLabels, 'XTickLabelRotation', 90); %#ok<SETCH>
end
grid on;
xlabel("编码（株1-株2-株3，类型 1–4）");
ylabel(ylabBarTxt);
title("末段均值（后 30% 时间窗）");
sgtitle(figName);
end

function local_plotResourceCostFig(figName, t_ref, CostSum, CostTrait, CostSignal, tailSum, tailTrait, tailSignal, codeLabels)
% 上图：总加权代价热图；下图：末段均值堆叠条（性状成本 + 信号成本），与 qs_mspg_rhs_impl 中 omega 扣减项一致
if nargin < 9
    error("compare_three_strain_topologies:ResourceCostArgs", "参数不足。");
end
nB = numel(codeLabels);
figure("Name", figName, "Color", "w", "Position", [40 40 1120 760]);
subplot(2, 1, 1);
imagesc(t_ref, 1:size(CostSum, 2), CostSum.');
axis xy;
try %#ok<TRYNC>
    colormap(gca, parula);
catch %#ok<CTCH>
    colormap(gca, jet);
end
cb = colorbar;
cb.Label.String = "C_{trait}+C_{signal}（Σ f_j·代价_j）";
xlabel("时间");
ylabel(sprintf("拓扑索引（1-%d）", nB));
title("热图：总资源消耗（纵轴拓扑 ID；横轴时间）");

subplot(2, 1, 2);
tt = tailTrait(:);
ts = tailSignal(:);
tt(isnan(tt)) = 0;
ts(isnan(ts)) = 0;
bh = bar(1:nB, [tt, ts], "stacked");
try %#ok<TRYNC>
    bh(1).FaceColor = [0.45 0.62 0.82];
    bh(2).FaceColor = [0.85 0.55 0.35];
catch %#ok<CTCH>
end
grid on;
try %#ok<TRYNC>
    set(gca, "XTick", 1:nB, "XTickLabel", codeLabels, "XTickLabelRotation", 90);
catch %#ok<CTCH>
    set(gca, 'XTick', 1:nB, 'XTickLabel', codeLabels, 'XTickLabelRotation', 90);
end
xlabel("编码（株1-株2-株3，类型 1–4）");
ylabel("末段均值代价（后 30% 时间窗）");
title("堆叠条：性状生产成本 + 信号合成代价（与 \omega_j 中扣减项一致）");
legend({'C_{trait}：\Sigma f_j(produce\cdot c)_j', 'C_{signal}：\Sigma f_j c_{signal} k_{A,j}'}, ...
    'Location', 'northwest', 'Interpreter', 'tex');
sgtitle(figName);
end

function [Ctrait, Csignal, Csum] = local_communityWeightedCostFromPop(X, produce, c_vec, decepStrength, epsN, c_signal, kA_vec)
% 各时刻种群频率加权平均代价（与 qs_mspg_rhs_impl 中 cost_per_strain、signal_cost 一致）
produce = double(produce);
ce = c_vec(:) * decepStrength;
traitPerStrain = produce * ce;
sigPerStrain = c_signal * reshape(double(kA_vec), [], 1);
[nt, Mc] = size(X);
Mloc = size(produce, 1);
Ctrait = nan(nt, 1);
Csignal = nan(nt, 1);
Csum = nan(nt, 1);
if Mc ~= Mloc || isempty(nt) || numel(sigPerStrain) ~= Mloc
    return;
end
for i = 1:nt
    x = X(i, :).';
    N = sum(x);
    if N <= 1e-15
        continue;
    end
    f = x / (N + epsN);
    Ctrait(i) = dot(f(:), traitPerStrain(:));
    Csignal(i) = dot(f(:), sigPerStrain(:));
    Csum(i) = Ctrait(i) + Csignal(i);
end
end

function SA = local_getQsSimA(simOut)
% 优先 base 中的 qs_sim_A；否则从 Simulink.SimulationOutput 取（Single simulation output=on 时）
SA = [];
if evalin("base", "exist('qs_sim_A','var')")
    SA = local_normalizeQsSimA(evalin("base", "qs_sim_A"));
end
if ~isempty(SA) && local_isValidStructWithTime(SA)
    return;
end
SA = [];
if ~isa(simOut, "Simulink.SimulationOutput")
    return;
end
try
    SA = simOut.qs_sim_A;
catch
end
if isempty(SA) || ~local_isValidStructWithTime(SA)
    try
        SA = simOut.get("qs_sim_A"); %#ok<MCNPN>
    catch
        try
            SA = get(simOut, "qs_sim_A"); %#ok<GGET>
        catch
            SA = [];
        end
    end
end
SA = local_normalizeQsSimA(SA);
if isempty(SA) || ~local_isValidStructWithTime(SA)
    SA = [];
end
end

function SA = local_normalizeQsSimA(SA)
if isempty(SA)
    return;
end
if local_isValidStructWithTime(SA)
    return;
end
% 部分版本返回 timeseries，转成与 Structure With Time 一致的字段便于后续 plot
try
    if isa(SA, "timeseries")
        SA = struct("time", SA.Time(:), "signals", struct("values", SA.Data(:)));
    end
catch
    SA = [];
end
end

function ok = local_isValidStructWithTime(S)
ok = isstruct(S) && isfield(S, "time") && isfield(S, "signals") ...
    && isstruct(S.signals) && isfield(S.signals, "values");
end

function SP = local_getQsSimPop(simOut)
SP = [];
if evalin("base", "exist('qs_sim_pop','var')")
    SP = local_normalizeQsSimPop(evalin("base", "qs_sim_pop"));
end
if ~isempty(SP) && local_isValidStructPop(SP)
    return;
end
SP = [];
if ~isa(simOut, "Simulink.SimulationOutput")
    return;
end
try
    SP = simOut.qs_sim_pop;
catch
end
if isempty(SP) || ~local_isValidStructPop(SP)
    try
        SP = simOut.get("qs_sim_pop"); %#ok<MCNPN>
    catch
        try
            SP = get(simOut, "qs_sim_pop"); %#ok<GGET>
        catch
            SP = [];
        end
    end
end
if ~isempty(SP)
    SP = local_normalizeQsSimPop(SP);
end
if isempty(SP) || ~local_isValidStructPop(SP)
    SP = [];
end
end

function SP = local_normalizeQsSimPop(SP)
if isempty(SP) || ~isstruct(SP)
    return;
end
if local_isValidStructPop(SP)
    return;
end
try
    if isa(SP, "timeseries")
        d = SP.Data;
        SP = struct("time", SP.Time(:), "signals", struct("values", d));
    end
catch
    SP = [];
end
end

function ok = local_isValidStructPop(S)
ok = isstruct(S) && isfield(S, "time") && isfield(S, "signals") ...
    && isstruct(S.signals) && isfield(S.signals, "values");
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

function g = local_geomMeanAbundance(X)
% 各时刻 G = (prod_j x_j)^(1/M)，用 exp(mean(log(x+eps))) 避免下溢/ log(0)
eps0 = 1e-12;
g = exp(mean(log(X + eps0), 2));
end

function S = local_traitPublicSupplyFromPop(X, produce, b_vec, epsN)
% 各时刻性状层「公共产物」供给标量：Σ_i b_i (1 - p_ch(i))，p_ch 由种群频率与 produce 得到（同 rhs）
produce = double(produce);
b = b_vec(:);
[nt, Mc] = size(X);
Mloc = size(produce, 1);
S = nan(nt, 1);
if Mc ~= Mloc || isempty(nt)
    return;
end
cheat_frac = 1 - produce;
for i = 1:nt
    x = X(i, :).';
    N = sum(x);
    if N <= 1e-15
        continue;
    end
    f = x / (N + epsN);
    p_ch = f(:).' * cheat_frac;
    S(i) = sum(b .* (1 - p_ch(:)));
end
end

function S = local_boostedTraitBenefitFromPop(X, produce, b_vec, epsN, A_aux, KA, nHill, qsBoost)
% 与 qs_mspg_rhs_impl 中 B_trait·(1+qsBoost·φ(A)) 一致（不含 ω0）
produce = double(produce);
b = b_vec(:);
[nt, Mc] = size(X);
Mloc = size(produce, 1);
S = nan(nt, 1);
if Mc ~= Mloc || isempty(nt) || numel(A_aux) ~= nt
    return;
end
KA = double(KA(1));
nHill = double(nHill(1));
qsBoost = double(qsBoost(1));
cheat_frac = 1 - produce;
for i = 1:nt
    x = X(i, :).';
    N = sum(x);
    if N <= 1e-15
        continue;
    end
    f = x / (N + epsN);
    p_ch = f(:).' * cheat_frac;
    B_trait = sum(b .* (1 - p_ch(:)));
    Apos = max(0, A_aux(i));
    phiA = (Apos^nHill) / (max(eps, KA^nHill) + Apos^nHill);
    S(i) = B_trait * (1 + qsBoost * phiA);
end
end

function [omegaBar, omegaAll] = local_omegaFromPop(X, produce, b_vec, c_vec, decepStrength, omega0, epsN, A_aux, KA, nHill, qsBoost, c_signal, kA_vec)
produce = double(produce);
ce = c_vec(:) * decepStrength;
b = b_vec(:);
kA_col = reshape(double(kA_vec), [], 1);
[nt, Mc] = size(X);
Mloc = size(produce, 1);
omegaBar = nan(nt, 1);
omegaAll = nan(nt, Mloc);
if Mc ~= Mloc || isempty(nt) || numel(A_aux) ~= nt || numel(kA_col) ~= Mloc
    return;
end
KA = double(KA(1));
nHill = double(nHill(1));
qsBoost = double(qsBoost(1));
c_signal = double(c_signal(1));
cheat_frac = 1 - produce;
for i = 1:nt
    x = X(i, :).';
    N = sum(x);
    if N <= 1e-15
        continue;
    end
    f = x / (N + epsN);
    p_ch = f(:).' * cheat_frac;
    B_trait = sum(b .* (1 - p_ch(:)));
    Apos = max(0, A_aux(i));
    phiA = (Apos^nHill) / (max(eps, KA^nHill) + Apos^nHill);
    boost = 1 + qsBoost * phiA;
    Bcommon = omega0 + B_trait * boost;
    cost_per_strain = produce * ce;
    signal_cost = c_signal * kA_col;
    omega = Bcommon - cost_per_strain - signal_cost;
    omegaBar(i) = dot(f(:), omega(:));
    omegaAll(i, :) = omega(:).';
end
end

function x = local_mwToDoubleScalarOr(mw, name, defaultVal)
try
    x = local_mwToDoubleScalar(mw, name);
catch
    x = double(defaultVal);
    x = x(1);
end
end

function x = local_mwToDoubleScalar(mw, name)
raw = evalin(mw, name);
raw = local_mwUnwrapValue(raw);
x = double(raw);
x = x(1);
end

function v = local_mwToDoubleVector(mw, name)
raw = evalin(mw, name);
raw = local_mwUnwrapValue(raw);
v = double(raw);
v = v(:);
end

function raw = local_mwUnwrapValue(raw)
% Simulink.ModelWorkspace 里常见为数值；若为 Parameter 对象则取 .Value
try %#ok<TRYNC>
    if isa(raw, 'Simulink.Parameter')
        raw = raw.Value;
    end
catch
end
end

function topo_assignProduceKA(mw, produce, kA_vec)
produce = double(produce);
kA_vec = reshape(double(kA_vec), 1, []);
try
    mw.assignin("produce", produce);
    mw.assignin("kA_vec", kA_vec);
catch
    evalin(mw, sprintf("produce = %s;", mat2str(produce)));
    evalin(mw, sprintf("kA_vec = %s;", mat2str(kA_vec)));
end
end
