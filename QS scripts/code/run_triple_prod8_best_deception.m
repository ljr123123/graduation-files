function run_triple_prod8_best_deception(varargin)
%RUN_TRIPLE_PROD8_BEST_DECEPTION 三菌：18 调控拓扑 × **138** 种产率策略（8 轨母集）— 最优欺骗 + 按轨汇总
%
% 与 run_triple18_topology_best_deception 类似，但产率扫描使用 TripleProductionSweepMode='constrained138'：
%   每菌可产 1 或 2 种信号（strat 2..7），且三种信号均被至少一菌产出；共 138 种标号组合；
%   rows.prodOrbit8∈{1..8} 为在「菌株置换 × 信号置换」下的等价类（见 triple_qs_production_orbit8.m）。
%   全空间 512 维：build_modular_qs_simulink_model_triple(..., 'TripleProductionSweepMode','full512')。
%
% 用法（在 QS scripts 目录）：
%   run_triple_prod8_best_deception;
%   run_triple_prod8_best_deception('Recompute', true);
%   run_triple_prod8_best_deception('UseHysteresis', true);
%   run_triple_prod8_best_deception('OwnBPromotesNi', true, 'Recompute', true);
%
% 随机产率（每菌独立均匀 1..8 strat，含不产与全产）：示例
%   build_modular_qs_simulink_model_triple('RunTripleCommunityDeceptionSweep', true, ...
%       'TripleProductionSweepMode','random512', 'TripleRandomStratTrials', 400, ...
%       'TripleRandomStratSeed', 42, 'DualResultsMat', 'triple_rand512.mat', 'OpenModel', false, 'SaveModel', false);
%
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
sweepParts = {'prod8_138'};
if isfield(p, 'OwnBPromotesNi') && p.OwnBPromotesNi
    sweepParts{end+1} = 'BpromNi'; %#ok<AGROW>
end
if p.UseHysteresis
    sweepParts{end+1} = 'hyst'; %#ok<AGROW>
end
matName = ['triple18_sweep_' strjoin(sweepParts, '_') '_cached.mat'];
figPfx = ['triple18_' strjoin(sweepParts, '_') '_'];
nHypTopo = 18;
sumName = sprintf('triple18_prod8_best%d_summary.mat', nHypTopo);
if isfield(p, 'OwnBPromotesNi') && p.OwnBPromotesNi
    sumName = strrep(sumName, '.mat', '_BpromNi.mat');
end
if p.UseHysteresis
    sumName = strrep(sumName, '.mat', '_hyst.mat');
end
matPath = fullfile(cacheRoot, matName);
needRun = p.Recompute || (exist(matPath, 'file') ~= 2);
if needRun
    fprintf('[triple prod8] 开始扫描 18×138 次 ODE，结果写入：%s\n', matPath);
    commonArgs = { ...
        'RunTripleCommunityDeceptionSweep', true, ...
        'OpenModel', false, ...
        'SaveModel', false, ...
        'DualResultsMat', matPath, ...
        'DualSaveFigures', false, ...
        'TripleLargeSweepHeatmapOnly', true, ...
        'TripleShowWaitbar', true, ...
        'TripleSweepFastApprox', true, ...
        'TripleProductionSweepMode', 'constrained138' ...
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
    fprintf('[triple prod8] 使用缓存：%s\n', matPath);
end
S = load(matPath);
rows = S.rows;
hypLabels = S.hypLabels;
if isfield(S, 'tripleSweepMeta')
    meta = S.tripleSweepMeta;
else
    meta = struct();
end
if isfield(meta, 'bestByProdOrbit8Strat')
    fprintf('\n=== tripleSweepMeta：各拓扑×产率轨 P1..P8 的最优策略码（空表示该轨无有效解）===\n');
    bestCell = meta.bestByProdOrbit8Strat;
    bestScore = meta.bestByProdOrbit8Score;
    oLab = meta.prodOrbit8Labels;
    nH = size(bestCell, 1);
    for oid = 1:min(8, size(bestCell, 2))
        fprintf('\n--- P%d %s ---\n', oid, char(string(oLab{oid})));
        for hi = 1:nH
            sc = bestCell{hi, oid};
            if isempty(sc)
                continue;
            end
            fprintf('  H%2d | 码 %s | score=%.4g\n', hi, sc, bestScore(hi, oid));
        end
    end
end
save(fullfile(cacheRoot, sumName), 'matPath', 'meta', '-v7.3');
fprintf('[triple prod8] 已写入摘要：%s\n', fullfile(cacheRoot, sumName));
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
