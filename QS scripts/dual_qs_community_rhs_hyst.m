function du = dual_qs_community_rhs_hyst(~, y, p)
%DUAL_QS_COMMUNITY_RHS_HYST 双菌模型 + A1/A2 迟滞门控（在 dual_qs_community_rhs 上扩展）
%
% 参考基线：dual_qs_community_rhs（Karkaria, Fedorec & Barnes, Nat Commun 12, 672 (2021)）。
% 增加标量 q1、q2∈[0,1]，分别由 A1、A2 经双阈值弛豫驱动，用于门控 QS 型 Hill 调节项：
%   w_up(A)=A^n/(KA_on^n+A^n)，w_dn(A)=KA_off^n/(KA_off^n+A^n)，dq/dt=k*(w_up*(1-q)-w_dn*q)，
%   须 KA_off < KA_on（由参数构造阶段保证）。
% 状态 y = [N1; N2; S; A1; A2; B1; B2; R; q1; q2]，R 仍为累积资源（第 8 分量）。
% 产物有效调节：fA1_B1_eff = q1*fA1_B1；modA2_B1_eff = q2*modA2_B1；modA1_B2_eff = q1*modA1_B2。
% 字段 p.k_hyst_A1、p.k_hyst_A2、p.KA_on_A1、p.KA_off_A1、p.KA_on_A2、p.KA_off_A2 由构建脚本写入。

N1 = max(0, y(1));
N2 = max(0, y(2));
S = max(0, y(3));
A1 = max(0, y(4));
A2 = max(0, y(5));
B1 = max(0, y(6));
B2 = max(0, y(7));
q1 = min(1, max(0, y(9)));
q2 = min(1, max(0, y(10)));

D = p.D;
KS = max(p.KS, 1e-12);
mu1 = p.mu_max1 * S ./ (KS + S);
mu2 = p.mu_max2 * S ./ (KS + S);

phi_in = @(A, K, n) local_hill_induce(A, K, n);
phi_re = @(A, K, n) local_hill_repress(A, K, n);

K1 = max(p.K_A1_B1, 1e-12);
Kx21 = max(p.K_A2_B1, 1e-12);
Kx12 = max(p.K_A1_B2, 1e-12);
nH = max(1, round(p.n));

fA1_B1 = phi_in(A1, K1, nH);
if p.sign_A2_on_B1 >= 0
    modA2_B1 = phi_in(A2, Kx21, nH);
else
    modA2_B1 = phi_re(A2, Kx21, nH);
end
if p.sign_A1_on_B2 >= 0
    modA1_B2 = phi_in(A1, Kx12, nH);
else
    modA1_B2 = phi_re(A1, Kx12, nH);
end

fA1_B1_eff = q1 * fA1_B1;
modA2_B1_eff = q2 * modA2_B1;
modA1_B2_eff = q1 * modA1_B2;

kB1_eff = p.KB_max1 .* fA1_B1_eff .* modA2_B1_eff;
kB2_eff = p.KB_max2 .* modA1_B2_eff;
prodB1 = kB1_eff .* N1;
prodB2 = kB2_eff .* N2;

w1 = local_omega_kill(B1, p.omega_max, p.K_omega, p.n_omega);
w2 = local_omega_kill(B2, p.omega_max, p.K_omega, p.n_omega);

sig1 = p.kA1_N1 * N1 + p.kA1_N2 * N2;
sig2 = p.kA2_N1 * N1 + p.kA2_N2 * N2;

burden1 = p.metCostA * (p.kA1_N1 + p.kA2_N1) + p.metCostB1 * kB1_eff;
burden2 = p.metCostA * (p.kA1_N2 + p.kA2_N2) + p.metCostB2 * kB2_eff;

dN1 = N1 .* (mu1 - burden1 - w1) - D * N1;
dN2 = N2 .* (mu2 - burden2 - w2) - D * N2;

S0 = max(p.S0, 1e-12);
g1 = max(p.gamma1, 1e-12);
g2 = max(p.gamma2, 1e-12);
dS = D * (S0 - S) - (mu1 .* N1) ./ g1 - (mu2 .* N2) ./ g2;

Ntot = N1 + N2 + p.epsN;
dA1 = sig1 + p.Ainflux1 - D * A1 - p.delta_qs * Ntot .* A1;
dA2 = sig2 + p.Ainflux2 - D * A2 - p.delta_qs * Ntot .* A2;

dB1 = prodB1 - D * B1;
dB2 = prodB2 - D * B2;

resDot = p.costA1 * sig1 + p.costA2 * sig2 + p.costB1 * prodB1 + p.costB2 * prodB2;

k1 = max(0, double(p.k_hyst_A1));
k2 = max(0, double(p.k_hyst_A2));
Kon1 = max(1e-12, double(p.KA_on_A1));
Koff1 = max(1e-12, double(p.KA_off_A1));
Kon2 = max(1e-12, double(p.KA_on_A2));
Koff2 = max(1e-12, double(p.KA_off_A2));

A1p = max(0, A1);
A2p = max(0, A2);
w_up1 = (A1p .^ nH) ./ (Kon1 .^ nH + A1p .^ nH + 1e-30);
w_dn1 = (Koff1 .^ nH) ./ (Koff1 .^ nH + A1p .^ nH + 1e-30);
w_up2 = (A2p .^ nH) ./ (Kon2 .^ nH + A2p .^ nH + 1e-30);
w_dn2 = (Koff2 .^ nH) ./ (Koff2 .^ nH + A2p .^ nH + 1e-30);

dq1 = k1 * (w_up1 * (1 - q1) - w_dn1 * q1);
dq2 = k2 * (w_up2 * (1 - q2) - w_dn2 * q2);

du = [dN1; dN2; dS; dA1; dA2; dB1; dB2; resDot; dq1; dq2];
end

function phi = local_hill_induce(A, K, nH)
Ap = max(0, A);
Kn = K .^ nH;
phi = (Ap .^ nH) ./ (Kn + Ap .^ nH + 1e-30);
end

function phi = local_hill_repress(A, K, nH)
Ap = max(0, A);
Kn = K .^ nH;
phi = Kn ./ (Kn + Ap .^ nH + 1e-30);
end

function w = local_omega_kill(B, omegaMax, Komega, nw)
Bp = max(0, B);
Kn = max(Komega, 1e-12) .^ nw;
w = omegaMax .* (Bp .^ nw) ./ (Kn + Bp .^ nw + 1e-30);
end
