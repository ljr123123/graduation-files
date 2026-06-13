function run_triple18_BpromNi_recompute()
%RUN_TRIPLE18_BPROMNI_RECOMPUTE 18 拓扑扫描 + B_i 促进 N_i + 强制重算
%
% 等价于：
%   run_triple18_topology_best_deception('OwnBPromotesNi', true, 'Recompute', true);

run_triple18_topology_best_deception( ...
    'OwnBPromotesNi', true, ...
    'Recompute', true);
end
