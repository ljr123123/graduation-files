function run_qs_triple18_nohyst_inhibit_force
%RUN_QS_TRIPLE18_NOHYST_INHIBIT_FORCE 三菌 18 拓扑：非迟滞 + 本菌产物默认抑制 N（OwnBPromotesNi=false）
% 强制不使用缓存：Recompute=true，重写 cache_triple18/triple18_sweep_full18_cached.mat 并全量 ODE。
% 柱状图输出：本脚本目录/paper_figures_export/triple18_nohyst_inhibit/
% 摘要仍写：cache_triple18/triple18_best18_summary.mat
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
cd(scriptDir);
addpath(scriptDir);
plotDir = fullfile(scriptDir, 'paper_figures_export', 'triple18_nohyst_inhibit');
run_triple18_topology_best_deception( ...
    'Recompute', true, ...
    'UseHysteresis', false, ...
    'OwnBPromotesNi', false, ...
    'PlotExportDir', plotDir);
fprintf('[run_qs_triple18_nohyst_inhibit_force] 完成。图：%s\n', plotDir);
fprintf('  含：triple18_full18_bars_three_metrics.png, triple18_full18_bars_rank2_gaps.png\n');
fprintf('  缓存 mat：%s\n', fullfile(scriptDir, 'cache_triple18', 'triple18_sweep_full18_cached.mat'));
end
