function yi = qs_mspg_rhs_component_hyst(u, k)
%QS_MSPG_RHS_COMPONENT_HYST 返回 qs_mspg_rhs_impl_hyst(u) 的第 k 个分量（标量）
%
% u = [x_1;...;x_M;A;q]，k = 1..M+2。

du = qs_mspg_rhs_impl_hyst(u);
nk = numel(du);
if k < 1 || k > nk || ~isscalar(k) || k ~= floor(k)
    error("qs_mspg_rhs_component_hyst:Range", "k 须为 1..%d 的整数。", nk);
end
yi = du(k);
end
