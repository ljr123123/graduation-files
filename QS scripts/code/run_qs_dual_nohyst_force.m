function run_qs_dual_nohyst_force
%RUN_QS_DUAL_NOHYST_FORCE 双菌欺骗扫描（无迟滞，dual_qs_community_rhs）
% 双菌流程无「跳过缓存」开关，每次调用均全量 ODE；此处单独 mat 路径避免与迟滞版互相覆盖。
% 热图+柱状图（约 24 张 PNG）：paper_figures_export/dual_nohyst_force/
% 数值结果：cache_dual/dual_community_deception_nohyst.mat
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
cd(scriptDir);
addpath(scriptDir);
figDir = fullfile(scriptDir, 'paper_figures_export', 'dual_nohyst_force');
matDir = fullfile(scriptDir, 'cache_dual');
if ~isfolder(matDir)
    mkdir(matDir);
end
matPath = fullfile(matDir, 'dual_community_deception_nohyst.mat');
build_modular_qs_simulink_model( ...
    "RunDualCommunityDeceptionSweep", true, ...
    "OpenModel", false, ...
    "SaveModel", false, ...
    "DualSaveFigures", true, ...
    "DualFigureExportDir", figDir, ...
    "DualResultsMat", matPath);
fprintf('[run_qs_dual_nohyst_force] 完成。\n  图目录：%s（H*_geomN/B/resRate 的 heatmap 与 bar）\n  mat：%s\n', figDir, matPath);
end
