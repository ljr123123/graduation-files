function run_qs_triple18_hyst_promote_force
%RUN_QS_TRIPLE18_HYST_PROMOTE_FORCE 三菌：迟滞 + 本菌 B_i 促进 N_i
% Recompute=true → cache_triple18/triple18_sweep_full18_BpromNi_hyst_cached.mat
% 图：paper_figures_export/triple18_hyst_promote/
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
cd(scriptDir);
addpath(scriptDir);
plotDir = fullfile(scriptDir, 'paper_figures_export', 'triple18_hyst_promote');
run_triple18_topology_best_deception( ...
    'Recompute', true, ...
    'UseHysteresis', true, ...
    'OwnBPromotesNi', true, ...
    'PlotExportDir', plotDir);
fprintf('[run_qs_triple18_hyst_promote_force] 完成。图：%s\n', plotDir);
fprintf('  缓存 mat：%s\n', fullfile(scriptDir, 'cache_triple18', 'triple18_sweep_full18_BpromNi_hyst_cached.mat'));
end
