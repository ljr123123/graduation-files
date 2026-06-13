function run_qs_triple18_hyst_inhibit_force
%RUN_QS_TRIPLE18_HYST_INHIBIT_FORCE 三菌：迟滞 + 默认抑制（OwnBPromotesNi=false）
% Recompute=true → 重写 cache_triple18/triple18_sweep_full18_hyst_cached.mat
% 图：paper_figures_export/triple18_hyst_inhibit/
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
cd(scriptDir);
addpath(scriptDir);
plotDir = fullfile(scriptDir, 'paper_figures_export', 'triple18_hyst_inhibit');
run_triple18_topology_best_deception( ...
    'Recompute', true, ...
    'UseHysteresis', true, ...
    'OwnBPromotesNi', false, ...
    'PlotExportDir', plotDir);
fprintf('[run_qs_triple18_hyst_inhibit_force] 完成。图：%s\n', plotDir);
fprintf('  缓存 mat：%s\n', fullfile(scriptDir, 'cache_triple18', 'triple18_sweep_full18_hyst_cached.mat'));
end
