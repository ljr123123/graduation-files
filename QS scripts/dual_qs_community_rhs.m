function du = dual_qs_community_rhs(~, y, p)
%DUAL_QS_COMMUNITY_RHS 双菌 N1/N2、底物 S、信号 A1/A2、产物 B1/B2（恒化器 + QS / 微菌素风格）
%
% 参考：Karkaria, Fedorec & Barnes, Nat Commun 12, 672 (2021).
%   https://doi.org/10.1038/s41467-020-20756-2
%   生长 Monod：mu_x(S)=mu_max*S/(KS+S)；杀伤 omega(B) 为 Hill；产物合成率 k_B 对信号取
%   诱导式 (15) 或抑制式 (16)；稀释 D 作用于 N、S、A、B。
%
% 已知生物学设定（与扫描脚本一致）：
%   - A1 仅通过诱导 Hill 调制 N1 产 B1；A2 不参与 N2 产 B2（B2 合成不乘 A2 项）。
%   - B1、B2 分别通过 omega(B1)、omega(B2) 抑制 N1、N2（自限 / SL）。
%   - 交叉假设：sign_A2_on_B1、sign_A1_on_B2 ∈ {+1,-1} 控制 A2→B1、A1→B2 为诱导或抑制。
%
% 状态 y = [N1; N2; S; A1; A2; B1; B2; R]，R 为累积资源消耗 ∫ resDot dt。
%   S 为无量纲营养（可视为 S/S0），S0 在参数中给出，初值通常取 S0。

N1 = max(0, y(1));
N2 = max(0, y(2));
S = max(0, y(3));
A1 = max(0, y(4));
A2 = max(0, y(5));
B1 = max(0, y(6));
B2 = max(0, y(7));

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

% N1 产 B1：A1 必为诱导；A2 按假设诱导/抑制
fA1_B1 = phi_in(A1, K1, nH);
if p.sign_A2_on_B1 >= 0
    modA2_B1 = phi_in(A2, Kx21, nH);
else
    modA2_B1 = phi_re(A2, Kx21, nH);
end
kB1_eff = p.KB_max1 .* fA1_B1 .* modA2_B1;
prodB1 = kB1_eff .* N1;

% N2 产 B2：无 A2 项；A1 交叉按假设
if p.sign_A1_on_B2 >= 0
    modA1_B2 = phi_in(A1, Kx12, nH);
else
    modA1_B2 = phi_re(A1, Kx12, nH);
end
kB2_eff = p.KB_max2 .* modA1_B2;
prodB2 = kB2_eff .* N2;

w1 = local_omega_kill(B1, p.omega_max, p.K_omega, p.n_omega);
w2 = local_omega_kill(B2, p.omega_max, p.K_omega, p.n_omega);

sig1 = p.kA1_N1 * N1 + p.kA1_N2 * N2;
sig2 = p.kA2_N1 * N1 + p.kA2_N2 * N2;

% 代谢负担：降低有效生长（与「产 A/B 消耗资源」一致，可与积分计价同时使用）
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

% 资源消耗率（对产信号与产物的通量线性计价；外源 A 通量不计入菌群代谢）
resDot = p.costA1 * sig1 + p.costA2 * sig2 + p.costB1 * prodB1 + p.costB2 * prodB2;

du = [dN1; dN2; dS; dA1; dA2; dB1; dB2; resDot];
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
