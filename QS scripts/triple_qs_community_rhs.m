function du = triple_qs_community_rhs(~, y, p)
%TRIPLE_QS_COMMUNITY_RHS 三菌 N1/N2/N3、底物 S、信号 A1/A2/A3、产物 B1/B2/B3（恒化器 + Hill）
%
% 状态 y = [N1; N2; N3; S; A1; A2; A3; B1; B2; B3; R]，R = ∫ resDot dt。
% p.effA_B 为 3×3，行 Ai、列 Bj：+1 促进 Bj 合成（乘 φ_act），−1 抑制（乘 φ_re），0 无 Hill 项。
% p.K_A_B(i,j) 为对应 Hill 半饱和；p.qsBoost 用于促进项。
% 合成率 k_Bj_eff = KB_max,j * Π_i f_ij（各信号因子连乘）。
% 若 p.ownB_promotes_Ni=true：本菌产物 B_i 对 N_i 生长率为「促进」（+ω(B_i)）；默认 false 时为「抑制」（−ω(B_i)）。

N1 = max(0, y(1));
N2 = max(0, y(2));
N3 = max(0, y(3));
S = max(0, y(4));
A1 = max(0, y(5));
A2 = max(0, y(6));
A3 = max(0, y(7));
B1 = max(0, y(8));
B2 = max(0, y(9));
B3 = max(0, y(10));

D = p.D;
KS = max(p.KS, 1e-12);
mu1 = p.mu_max1 * S ./ (KS + S);
mu2 = p.mu_max2 * S ./ (KS + S);
mu3 = p.mu_max3 * S ./ (KS + S);

phi_re = @(A, K, n) local_hill_repress(A, K, n);
phi_ac = @(A, K, n) local_hill_activate(A, K, n);

nH = max(1, round(p.n));
qb = max(0, double(p.qsBoost));

E = p.effA_B;
Kmat = p.K_A_B;
if ~isequal(size(E), [3, 3]) || ~isequal(size(Kmat), [3, 3])
    error("triple_qs_community_rhs:BadEff", "p.effA_B 与 p.K_A_B 须为 3×3。");
end

Avec = [A1; A2; A3];
F = ones(3, 3);
for si = 1:3
    for bj = 1:3
        sgn = E(si, bj);
        if sgn == 0
            F(si, bj) = 1;
        elseif sgn < 0
            F(si, bj) = phi_re(Avec(si), max(Kmat(si, bj), 1e-12), nH);
        else
            F(si, bj) = 1 + qb .* phi_ac(Avec(si), max(Kmat(si, bj), 1e-12), nH);
        end
    end
end

fB1 = F(1, 1) * F(2, 1) * F(3, 1);
fB2 = F(1, 2) * F(2, 2) * F(3, 2);
fB3 = F(1, 3) * F(2, 3) * F(3, 3);

kB1_eff = p.KB_max1 .* fB1;
kB2_eff = p.KB_max2 .* fB2;
kB3_eff = p.KB_max3 .* fB3;
prodB1 = kB1_eff .* N1;
prodB2 = kB2_eff .* N2;
prodB3 = kB3_eff .* N3;

w1 = local_omega_kill(B1, p.omega_max, p.K_omega, p.n_omega);
w2 = local_omega_kill(B2, p.omega_max, p.K_omega, p.n_omega);
w3 = local_omega_kill(B3, p.omega_max, p.K_omega, p.n_omega);
sgB = -1;
if isfield(p, 'ownB_promotes_Ni') && ~isempty(p.ownB_promotes_Ni) && logical(p.ownB_promotes_Ni)
    sgB = 1;
end

sig1 = p.kA1_N1 * N1 + p.kA1_N2 * N2 + p.kA1_N3 * N3;
sig2 = p.kA2_N1 * N1 + p.kA2_N2 * N2 + p.kA2_N3 * N3;
sig3 = p.kA3_N1 * N1 + p.kA3_N2 * N2 + p.kA3_N3 * N3;

burden1 = p.metCostA * (p.kA1_N1 + p.kA2_N1 + p.kA3_N1) + p.metCostB1 * kB1_eff;
burden2 = p.metCostA * (p.kA1_N2 + p.kA2_N2 + p.kA3_N2) + p.metCostB2 * kB2_eff;
burden3 = p.metCostA * (p.kA1_N3 + p.kA2_N3 + p.kA3_N3) + p.metCostB3 * kB3_eff;

dN1 = N1 .* (mu1 - burden1 + sgB * w1) - D * N1;
dN2 = N2 .* (mu2 - burden2 + sgB * w2) - D * N2;
dN3 = N3 .* (mu3 - burden3 + sgB * w3) - D * N3;

S0 = max(p.S0, 1e-12);
g1 = max(p.gamma1, 1e-12);
g2 = max(p.gamma2, 1e-12);
g3 = max(p.gamma3, 1e-12);
dS = D * (S0 - S) - (mu1 .* N1) ./ g1 - (mu2 .* N2) ./ g2 - (mu3 .* N3) ./ g3;

Ntot = N1 + N2 + N3 + p.epsN;
dA1 = sig1 + p.Ainflux1 - D * A1 - p.delta_qs * Ntot .* A1;
dA2 = sig2 + p.Ainflux2 - D * A2 - p.delta_qs * Ntot .* A2;
dA3 = sig3 + p.Ainflux3 - D * A3 - p.delta_qs * Ntot .* A3;

dB1 = prodB1 - D * B1;
dB2 = prodB2 - D * B2;
dB3 = prodB3 - D * B3;

resDot = p.costA1 * sig1 + p.costA2 * sig2 + p.costA3 * sig3 ...
    + p.costB1 * prodB1 + p.costB2 * prodB2 + p.costB3 * prodB3;

du = [dN1; dN2; dN3; dS; dA1; dA2; dA3; dB1; dB2; dB3; resDot];
end

function phi = local_hill_repress(A, K, nH)
Ap = max(0, A);
Kn = K .^ nH;
phi = Kn ./ (Kn + Ap .^ nH + 1e-30);
end

function phi = local_hill_activate(A, K, nH)
Ap = max(0, A);
Kn = K .^ nH;
phi = (Ap .^ nH) ./ (Kn + Ap .^ nH + 1e-30);
end

function w = local_omega_kill(B, omegaMax, Komega, nw)
Bp = max(0, B);
Kn = max(Komega, 1e-12) .^ nw;
w = omegaMax .* (Bp .^ nw) ./ (Kn + Bp .^ nw + 1e-30);
end
