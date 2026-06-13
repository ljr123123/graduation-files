function yi = qs_mspg_rhs_component(u, k)
%QS_MSPG_RHS_COMPONENT 返回 qs_mspg_rhs_impl(u) 的第 k 个分量（标量）
%
% Simulink 的 Interpreted MATLAB Fcn 默认难以可靠输出向量宽度 M+1，故用 M+1 个块
% 各调本函数一次。代价：每步重复计算完整 RHS 共 M+1 次（M 不大时可接受）。

du = qs_mspg_rhs_impl(u);
nk = numel(du);
if k < 1 || k > nk || ~isscalar(k) || k ~= floor(k)
    error("qs_mspg_rhs_component:Range", "k 须为 1..%d 的整数。", nk);
end
yi = du(k);
end
