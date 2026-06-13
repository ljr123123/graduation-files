function run_all_paper_figure_sweeps(varargin)
%RUN_ALL_PAPER_FIGURE_SWEEPS 论文插图一键导出：双菌扫描（含迟滞）+ 三菌四档热图 + 三菌拓扑柱状图（四档）
%
% 所有插图集中在目录：本脚本所在目录/paper_figures_export/
%   dual_baseline/              双菌无迟滞，约 24 张（H*_*_heatmap / bar）
%   dual_hysteresis/            双菌迟滞版
%   triple_full18/              三菌 18 拓扑，无迟滞，默认 B 抑制 N
%   triple_full18_BpromNi/      三菌 + 本菌 B_i 促进 N_i
%   triple_full18_hyst/         三菌迟滞
%   triple_full18_BpromNi_hyst/ 迟滞 + 促进
%   triple18_topology_bars/     run_triple18 四柱组图（文件名前缀区分四档）
%
% 三菌缓存 mat 仍在：cache_triple18/triple18_sweep_*.mat（与单独运行 run_triple18 一致）
%
% 用法（请在「QS scripts」目录为当前路径，或先 cd 到该目录）：
%   cd('...\QS scripts'); addpath(pwd);
%   run_all_paper_figure_sweeps;
%
% 全部强制重算（极耗时）：
%   run_all_paper_figure_sweeps('Recompute', true);
%
% 指定插图根目录（否则为脚本目录下 paper_figures_export）：
%   run_all_paper_figure_sweeps('FigureRoot', 'D:\qs_paper_figures');
%
% 说明：三菌某一子目录若已有 mat 且已有 PNG，且 Recompute=false，则跳过该档热图扫描。
%       三菌热图扫描默认 TripleSweepFastApprox=true（放宽 ODE、缩短 Tend、稀化插值）；
%       与「本菌 B 促进 N」专用快速档一致，显著快于旧默认。论文定稿若需精细解，请对
%       build_modular_qs_simulink_model_triple* 显式传 TripleSweepFastApprox,false。

p = local_parseArgs_runAll(varargin{:});

scriptDir = fileparts(mfilename("fullpath"));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);

if isempty(strtrim(p.FigureRoot))
    figRoot = fullfile(scriptDir, 'paper_figures_export');
else
    figRoot = char(string(p.FigureRoot));
end
if ~isfolder(figRoot)
    mkdir(figRoot);
end

cacheT = fullfile(scriptDir, 'cache_triple18');
if ~isfolder(cacheT)
    mkdir(cacheT);
end

recompute = p.Recompute;
barDir = fullfile(figRoot, 'triple18_topology_bars');
if ~isfolder(barDir)
    mkdir(barDir);
end

fprintf("\n==== [1/3] 双菌欺骗扫描图（无迟滞）====\n");
build_modular_qs_simulink_model( ...
    "RunDualCommunityDeceptionSweep", true, ...
    "OpenModel", false, ...
    "SaveModel", false, ...
    "DualFigureExportDir", fullfile(figRoot, "dual_baseline"));

fprintf("\n==== [2/3] 双菌欺骗扫描图（迟滞）====\n");
build_modular_qs_simulink_model_hyst( ...
    "RunDualCommunityDeceptionSweep", true, ...
    "OpenModel", false, ...
    "SaveModel", false, ...
    "DualFigureExportDir", fullfile(figRoot, "dual_hysteresis"));

fprintf("\n==== [3a/3] 三菌 18×512 扫描热图（四档）====\n");
local_runTripleSweepWithFigs(cacheT, recompute, false, false, fullfile(figRoot, "triple_full18"));
local_runTripleSweepWithFigs(cacheT, recompute, false, true, fullfile(figRoot, "triple_full18_BpromNi"));
local_runTripleSweepWithFigs(cacheT, recompute, true, false, fullfile(figRoot, "triple_full18_hyst"));
local_runTripleSweepWithFigs(cacheT, recompute, true, true, fullfile(figRoot, "triple_full18_BpromNi_hyst"));

fprintf("\n==== [3b/3] 三菌拓扑柱状图（四档，文件名前缀区分）====\n");
run_triple18_topology_best_deception("PlotExportDir", barDir, "Recompute", recompute, "UseHysteresis", false, "OwnBPromotesNi", false);
run_triple18_topology_best_deception("PlotExportDir", barDir, "Recompute", recompute, "UseHysteresis", false, "OwnBPromotesNi", true);
run_triple18_topology_best_deception("PlotExportDir", barDir, "Recompute", recompute, "UseHysteresis", true, "OwnBPromotesNi", false);
run_triple18_topology_best_deception("PlotExportDir", barDir, "Recompute", recompute, "UseHysteresis", true, "OwnBPromotesNi", true);

fprintf("\n完成。插图根目录：%s\n", figRoot);
end

function p = local_parseArgs_runAll(varargin)
p = struct("Recompute", false, "FigureRoot", "");
if isempty(varargin)
    return;
end
for k = 1:2:numel(varargin)
    key = string(varargin{k});
    if k + 1 > numel(varargin)
        break;
    end
    val = varargin{k + 1};
    if key == "Recompute"
        p.Recompute = logical(val);
    elseif key == "FigureRoot"
        p.FigureRoot = char(string(val));
    end
end
end

function local_runTripleSweepWithFigs(cacheT, recompute, useHyst, ownB, figSub)
parts = {'full18'};
if ownB
    parts{end+1} = 'BpromNi'; %#ok<AGROW>
end
if useHyst
    parts{end+1} = 'hyst'; %#ok<AGROW>
end
matName = ['triple18_sweep_' strjoin(parts, '_') '_cached.mat'];
matPath = fullfile(cacheT, matName);
if ~isfolder(figSub)
    mkdir(figSub);
end
d = dir(fullfile(figSub, '*.png'));
hasPng = ~isempty(d);
if ~recompute && isfile(matPath) && hasPng
    fprintf("[skip] %s（mat 与子目录 PNG 已存在）\n", figSub);
    return;
end

args = { ...
    "RunTripleCommunityDeceptionSweep", true, ...
    "OpenModel", false, ...
    "SaveModel", false, ...
    "DualSaveFigures", true, ...
    "DualFigureExportDir", figSub, ...
    "DualResultsMat", matPath, ...
    "TripleLargeSweepHeatmapOnly", true, ...
    "TripleShowWaitbar", true, ...
    "TripleSweepFastApprox", true ...
    };
if ownB
    args = [args, {"TripleOwnBPromotesNi", true}]; %#ok<AGROW>
end
if useHyst
    build_modular_qs_simulink_model_triple_hyst(args{:});
else
    build_modular_qs_simulink_model_triple(args{:});
end
end
