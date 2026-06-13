function run_triple18_topology_best_deception(varargin)
%RUN_TRIPLE18_TOPOLOGY_BEST_DECEPTION 一键：**18 种**调控拓扑 × 512 策略 — 最优欺骗结构、本地缓存、柱状图
%
% 枚举 triple_qs_topology18 母库全部假设；缓存文件名含 full18（及可选 BpromNi、hyst）。
%
% 一键运行（复制到 MATLAB 命令行，把路径改成你的 QS scripts 目录）：
%   cd('c:\Users\14227\Downloads\...\QS scripts');
%   run_triple18_topology_best_deception;
%
% 强制重新跑完全部 ODE（18×512）：
%   run_triple18_topology_best_deception('Recompute', true);
%
% 迟滞版（缓存例如 triple18_sweep_full18_hyst_cached.mat）：
%   run_triple18_topology_best_deception('UseHysteresis', true);
%
% 本菌 B_i 对 N_i 为促进（+ω）（缓存名含 BpromNi）：
%   run_triple18_topology_best_deception('OwnBPromotesNi', true, 'Recompute', true);
%
% 迟滞 + 促进 + 重算：
%   run_triple18_topology_best_deception('UseHysteresis', true, 'OwnBPromotesNi', true, 'Recompute', true);
%
% 柱状图改存统一目录（例如论文插图根目录）：
%   run_triple18_topology_best_deception('PlotExportDir', 'c:\...\paper_figures_export\triple18_topology_bars');
%
% 缓存目录：本脚本同级的 cache_triple18/
%   - 文件名由「full18」「BpromNi」「hyst」组合，例如 triple18_sweep_full18_BpromNi_hyst_cached.mat
%   - 摘要 triple18_best18_summary*.mat 仍在 cache_triple18/；柱状图见 PlotExportDir 或默认 cache_triple18/plots/
%
% 图 1：三指标在「各拓扑 lexRank=1 最优解」上的柱状对比（18 种拓扑）。
% 图 2：「组内排序依据」——相对同拓扑 lexRank=2 的差值（ΔN、ΔB、Δres>0 表示优于第二名）。
p = local_parseArgs(varargin{:});
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);
cacheRoot = fullfile(scriptDir, 'cache_triple18');
if isfield(p, 'PlotExportDir') && ~isempty(strtrim(p.PlotExportDir))
    plotDir = char(string(p.PlotExportDir));
else
    plotDir = fullfile(cacheRoot, 'plots');
end
if ~exist(cacheRoot, 'dir')
    mkdir(cacheRoot);
end
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end
sweepParts = {'full18'};
if isfield(p, 'OwnBPromotesNi') && p.OwnBPromotesNi
    sweepParts{end+1} = 'BpromNi'; %#ok<AGROW>
end
if p.UseHysteresis
    sweepParts{end+1} = 'hyst'; %#ok<AGROW>
end
matName = ['triple18_sweep_' strjoin(sweepParts, '_') '_cached.mat'];
figPfx = ['triple18_' strjoin(sweepParts, '_') '_'];
nHypTopo = 18;
sumTail = '';
if isfield(p, 'OwnBPromotesNi') && p.OwnBPromotesNi
    sumTail = [sumTail '_BpromNi'];
end
if p.UseHysteresis
    sumTail = [sumTail '_hyst'];
end
sumName = sprintf('triple18_best%d_summary%s.mat', nHypTopo, sumTail);
matPath = fullfile(cacheRoot, matName);
needRun = p.Recompute || (exist(matPath, 'file') ~= 2);
if needRun
    fprintf('[triple18] 开始全量扫描（约 %d×512 次 ODE），结果写入：%s\n', nHypTopo, matPath);
    commonArgs = { ...
        'RunTripleCommunityDeceptionSweep', true, ...
        'OpenModel', false, ...
        'SaveModel', false, ...
        'DualResultsMat', matPath, ...
        'DualSaveFigures', false, ...
        'TripleLargeSweepHeatmapOnly', true, ...
        'TripleShowWaitbar', true, ...
        'TripleSweepFastApprox', true ...
        };
    if isfield(p, 'OwnBPromotesNi') && p.OwnBPromotesNi
        commonArgs = [commonArgs, {'TripleOwnBPromotesNi', true}];
    end
    if p.UseHysteresis
        build_modular_qs_simulink_model_triple_hyst(commonArgs{:});
    else
        build_modular_qs_simulink_model_triple(commonArgs{:});
    end
else
    fprintf('[triple18] 使用缓存（跳过 ODE）：%s\n', matPath);
end
S = load(matPath);
if ~isfield(S, 'rows') || ~isfield(S, 'hypLabels')
    error('run_triple18:BadMat', '缓存文件缺少 rows / hypLabels：%s', matPath);
end
rows = S.rows;
hypLabels = S.hypLabels;
if isfield(S, 'tripleSweepMeta')
    tripleSweepMeta = S.tripleSweepMeta;
else
    tripleSweepMeta = struct();
end
if isfield(S, 'stratTick')
    stratTick = S.stratTick;
else
    stratTick = {};
end
[bestT, gapsT] = local_extractBestAndGaps(rows, hypLabels, stratTick);
save(fullfile(cacheRoot, sumName), 'bestT', 'gapsT', 'matPath', 'tripleSweepMeta', '-v7.3');
fprintf('[triple18] 已写入摘要：%s\n', fullfile(cacheRoot, sumName));
local_plotBars(bestT, gapsT, plotDir, figPfx, height(bestT));
fprintf('[triple18] 柱状图已保存至：%s\n', plotDir);
% --- 控制台简要表 ---
fprintf('\n=== %d 个拓扑各自最优欺骗（策略码 = N1-N2-N3，每位 0..7）===\n', height(bestT));
for i = 1:height(bestT)
    fprintf('T%2d | %s | 码 %s | geomN=%.4g geomB=%.4g res=%.4g | 对第2名 ΔN=%.3g ΔB=%.3g Δres=%.3g\n', ...
        bestT.hypothesis(i), char(bestT.labelShort(i)), char(bestT.stratCode(i)), ...
        bestT.geomMeanN(i), bestT.geomMeanB(i), bestT.resTotal(i), ...
        gapsT.delta_geomMeanN(i), gapsT.delta_geomMeanB(i), gapsT.delta_resTotal(i));
end
if isfield(tripleSweepMeta, 'globalBestAmongTopologies')
    gb = tripleSweepMeta.globalBestAmongTopologies;
    if isfield(gb, 'nCandidates') && gb.nCandidates >= 1
        fprintf('\n=== 跨拓扑「最最最优」（各拓扑 lexRank=1 中按 econGeomScore 取第一；tripleSweepMeta.globalBestAmongTopologies）===\n');
        if isfield(gb, 'econGeomScore')
            fprintf('H%d | %s | 码 %s | econGeomScore=%.4g | passCountEcon=%d | N_h=%.3f B_h=%.3f res_h=%.3f | geomN=%.4g geomB=%.4g res=%.4g\n', ...
                gb.hypothesis, gb.topologyLabel, gb.stratCode, gb.econGeomScore, gb.passCountEcon, ...
                gb.geomMeanN_h, gb.geomMeanB_h, gb.resTotal_h, ...
                gb.geomMeanN, gb.geomMeanB, gb.resTotal);
        else
            fprintf('H%d | %s | 码 %s | passCountEcon=%d | N_h=%.3f B_h=%.3f res_h=%.3f | geomN=%.4g geomB=%.4g res=%.4g\n', ...
                gb.hypothesis, gb.topologyLabel, gb.stratCode, gb.passCountEcon, ...
                gb.geomMeanN_h, gb.geomMeanB_h, gb.resTotal_h, ...
                gb.geomMeanN, gb.geomMeanB, gb.resTotal);
        end
    end
end
end

function p = local_parseArgs(varargin)
p = struct('Recompute', false, 'UseHysteresis', false, 'OwnBPromotesNi', false, 'PlotExportDir', '');
if isempty(varargin)
    return;
end
for k = 1:2:numel(varargin)
    key = string(varargin{k});
    if k + 1 > numel(varargin)
        break;
    end
    val = varargin{k + 1};
    if strcmp(key, 'Recompute')
        p.Recompute = logical(val);
    elseif strcmp(key, 'UseHysteresis')
        p.UseHysteresis = logical(val);
    elseif strcmp(key, 'OwnBPromotesNi')
        p.OwnBPromotesNi = logical(val);
    elseif strcmp(key, 'PlotExportDir')
        p.PlotExportDir = char(string(val));
    end
end
end

function [bestT, gapsT] = local_extractBestAndGaps(rows, hypLabels, stratTick)
nHyp = max(rows.hypothesis);
hyp = (1:nHyp).';
geomN = nan(nHyp, 1);
geomB = nan(nHyp, 1);
resT = nan(nHyp, 1);
stratCode = strings(nHyp, 1);
stratTxt = strings(nHyp, 1);
labelShort = strings(nHyp, 1);
passEcon = nan(nHyp, 1);
gN_h = nan(nHyp, 1);
gB_h = nan(nHyp, 1);
r_h = nan(nHyp, 1);
lex1 = nan(nHyp, 1);
dN = nan(nHyp, 1);
dB = nan(nHyp, 1);
dRes = nan(nHyp, 1);
d_pass = nan(nHyp, 1);
d_gNh = nan(nHyp, 1);
d_gBh = nan(nHyp, 1);
d_rh = nan(nHyp, 1);
for hi = 1:nHyp
    sub = rows(rows.hypothesis == hi, :);
    if height(sub) < 1
        continue;
    end
    sub = sortrows(sub, 'lexRank');
    r1 = sub(1, :);
    geomN(hi) = local_rowScalar(r1, 'geomMeanN');
    geomB(hi) = local_rowScalar(r1, 'geomMeanB');
    resT(hi) = local_rowScalar(r1, 'resTotal');
    passEcon(hi) = local_rowScalar(r1, 'passCountEcon');
    gN_h(hi) = local_rowScalar(r1, 'geomMeanN_h');
    gB_h(hi) = local_rowScalar(r1, 'geomMeanB_h');
    r_h(hi) = local_rowScalar(r1, 'resTotal_h');
    lex1(hi) = local_rowScalar(r1, 'lexRank');
    rawSc = r1{1, 'stratCode'};
    if iscell(rawSc)
        stratCode(hi) = string(rawSc{1});
    else
        stratCode(hi) = string(rawSc);
    end
    stratTxt(hi) = local_stratToText(r1, stratTick);
    if hi <= numel(hypLabels)
        labelShort(hi) = string(sprintf('T%d', hi));
    else
        labelShort(hi) = string(sprintf('T%d', hi));
    end
    if height(sub) >= 2
        r2 = sub(2, :);
        dN(hi) = local_rowScalar(r1, 'geomMeanN') - local_rowScalar(r2, 'geomMeanN');
        dB(hi) = local_rowScalar(r1, 'geomMeanB') - local_rowScalar(r2, 'geomMeanB');
        dRes(hi) = local_rowScalar(r2, 'resTotal') - local_rowScalar(r1, 'resTotal');
        d_pass(hi) = local_rowScalar(r1, 'passCountEcon') - local_rowScalar(r2, 'passCountEcon');
        d_gNh(hi) = local_rowScalar(r1, 'geomMeanN_h') - local_rowScalar(r2, 'geomMeanN_h');
        d_gBh(hi) = local_rowScalar(r1, 'geomMeanB_h') - local_rowScalar(r2, 'geomMeanB_h');
        d_rh(hi) = local_rowScalar(r1, 'resTotal_h') - local_rowScalar(r2, 'resTotal_h');
    end
end
labFull = strings(nHyp, 1);
for hi = 1:nHyp
    if hi <= numel(hypLabels)
        labFull(hi) = string(hypLabels{hi});
    else
        labFull(hi) = string('');
    end
end
bestT = table(hyp, labelShort, labFull, stratCode, stratTxt, geomN, geomB, resT, ...
    passEcon, gN_h, gB_h, r_h, lex1, ...
    'VariableNames', {'hypothesis', 'labelShort', 'topologyLabel', 'stratCode', 'stratDescription', ...
    'geomMeanN', 'geomMeanB', 'resTotal', 'passCountEcon', 'geomMeanN_h', 'geomMeanB_h', 'resTotal_h', 'lexRank'});
gapsT = table(hyp, dN, dB, dRes, d_pass, d_gNh, d_gBh, d_rh, ...
    'VariableNames', {'hypothesis', 'delta_geomMeanN', 'delta_geomMeanB', 'delta_resTotal', ...
    'delta_passCountEcon', 'delta_geomMeanN_h', 'delta_geomMeanB_h', 'delta_resTotal_h'});
end

function s = local_stratToText(r, stratTick)
try
    a = local_rowScalar(r, 'stratN1');
    b = local_rowScalar(r, 'stratN2');
    c = local_rowScalar(r, 'stratN3');
catch %#ok<CTCH>
    s = string('');
    return;
end
if isempty(stratTick) || numel(stratTick) < max([a, b, c])
    s = sprintf('N1=%d N2=%d N3=%d', a, b, c);
    return;
end
s = sprintf('N1:%s | N2:%s | N3:%s', stratTick{a}, stratTick{b}, stratTick{c});
end

function v = local_rowScalar(r, vn)
if istable(r)
    v = r{1, vn};
else
    v = r.(vn);
end
if iscell(v)
    v = v{1};
end
v = double(v);
end

function local_plotBars(bestT, gapsT, plotDir, figPfx, nTopoBars)
if nargin < 5 || isempty(nTopoBars)
    nTopoBars = height(bestT);
end
x = bestT.hypothesis;
xl = cellstr(bestT.labelShort);
% --- 图 1：三指标（双 y：res 与 N/B 量级常不同）---
f1 = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 520]);
tiledlayout(f1, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
bar(x, bestT.geomMeanN, 'FaceColor', [0.35 0.55 0.85]);
set(gca, 'XTick', x, 'XTickLabel', xl);
xlabel('调控拓扑');
ylabel('geomMeanN');
title('末段几何平均菌量 (N_1 N_2 N_3)^{1/3}');
grid on;
xtickangle(45);
nexttile;
bar(x, bestT.geomMeanB, 'FaceColor', [0.45 0.75 0.55]);
set(gca, 'XTick', x, 'XTickLabel', xl);
xlabel('调控拓扑');
ylabel('geomMeanB');
title('末段几何平均产物 (B_1 B_2 B_3)^{1/3}');
grid on;
xtickangle(45);
nexttile;
bar(x, bestT.resTotal, 'FaceColor', [0.85 0.55 0.35]);
set(gca, 'XTick', x, 'XTickLabel', xl);
xlabel('调控拓扑');
ylabel('resTotal');
title('累积资源消耗 \int dR（越小越好）');
grid on;
xtickangle(45);
sgtitle(f1, sprintf('%d 种拓扑各自 lexRank=1 最优欺骗：三项经济指标', nTopoBars));
p1 = fullfile(plotDir, [figPfx 'bars_three_metrics.png']);
local_tryExportgraphics(f1, p1);
close(f1);
% --- 图 2：相对组内第 2 名的「胜出幅度」（解释为何在该拓扑内排第一）---
f2 = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 680]);
tiledlayout(f2, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
bar(x, gapsT.delta_geomMeanN, 'FaceColor', [0.35 0.55 0.85]);
set(gca, 'XTick', x, 'XTickLabel', xl);
ylabel('\Delta geomMeanN');
title('最优 − 同拓扑第2名（菌量，越大越好）');
grid on;
xtickangle(45);
nexttile;
bar(x, gapsT.delta_geomMeanB, 'FaceColor', [0.45 0.75 0.55]);
set(gca, 'XTick', x, 'XTickLabel', xl);
ylabel('\Delta geomMeanB');
title('最优 − 同拓扑第2名（产物，越大越好）');
grid on;
xtickangle(45);
nexttile;
bar(x, gapsT.delta_resTotal, 'FaceColor', [0.85 0.55 0.35]);
set(gca, 'XTick', x, 'XTickLabel', xl);
ylabel('\Delta res');
title('同拓扑第2名 − 最优（资源，越大=最优越省资源）');
grid on;
xtickangle(45);
nexttile;
hold on;
bar(x - 0.25, gapsT.delta_geomMeanN_h, 0.22, 'FaceColor', [0.5 0.5 0.85]);
bar(x, gapsT.delta_geomMeanB_h, 0.22, 'FaceColor', [0.5 0.8 0.55]);
bar(x + 0.25, gapsT.delta_resTotal_h, 0.22, 'FaceColor', [0.9 0.65 0.45]);
hold off;
set(gca, 'XTick', x, 'XTickLabel', xl);
ylabel('\Delta 归一指标_h');
title('组内 min-max 归一后：最优 − 第2名（字典序用）');
legend({'ΔN_h', 'ΔB_h', 'Δres_h'}, 'Location', 'best');
grid on;
xtickangle(45);
sgtitle(f2, sprintf('为何为各拓扑内最优：相对 lexRank=2 的差值（%d 拓扑；主排序 econGeomScore→strat）', nTopoBars));
p2 = fullfile(plotDir, [figPfx 'bars_rank2_gaps.png']);
local_tryExportgraphics(f2, p2);
close(f2);
end

function local_tryExportgraphics(f, outPath)
outPath = char(string(outPath));
try
    exportgraphics(f, outPath, 'Resolution', 200);
catch %#ok<CTCH>
    try
        saveas(f, outPath);
    catch %#ok<CTCH>
        warning('run_triple18:ExportFig', '无法导出图形：%s', outPath);
    end
end
end
