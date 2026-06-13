function run_qs_dual_hyst_force
%RUN_QS_DUAL_HYST_FORCE 双菌欺骗扫描（迟滞，dual_qs_community_rhs_hyst，默认 DualUseHysteresis=true）
% 图：paper_figures_export/dual_hyst_force/
% mat：cache_dual/dual_community_deception_hyst.mat
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
cd(scriptDir);
addpath(scriptDir);
figDir = fullfile(scriptDir, 'paper_figures_export', 'dual_hyst_force');
matDir = fullfile(scriptDir, 'cache_dual');
if ~isfolder(matDir)
    mkdir(matDir);
end
matPath = fullfile(matDir, 'dual_community_deception_hyst.mat');
build_modular_qs_simulink_model_hyst( ...
    "RunDualCommunityDeceptionSweep", true, ...
    "OpenModel", false, ...
    "SaveModel", false, ...
    "DualSaveFigures", true, ...
    "DualFigureExportDir", figDir, ...
    "DualResultsMat", matPath);
fprintf('[run_qs_dual_hyst_force] 完成。\n  图目录：%s\n  mat：%s\n', figDir, matPath);
end
