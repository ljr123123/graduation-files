function [effMats, labels] = triple_qs_topology18()
%TRIPLE_QS_TOPOLOGY18 三信号 A1–A3、三群体产物 B1–B3（对应 D1–D3）下，「单类信号对多群体的调控形态」共 18 种枚举。
%
% 数学上：仅由 **A1 行** 给出对 (B1,B2,B3) 的带符号作用（+1 促进合成、−1 抑制、0 无直接 Hill 项）；
% A2、A3 行全零——仍参与产率、稀释与代谢代价扫描；18 种刻画「一分子对多群体」子集–符号组合：
%   6 = 单群体×(促进|抑制)
%   6 = 双群体同号×(促进|抑制)×C(3,2)
%   3 = 双群体异号
%   3 = 三群体两促进一抑制
%
% effMats{k} 为 3×3 double，行 = A1..A3，列 = B1..B3。

effMats = cell(18, 1);
labels = cell(18, 1);
k = 0;

for j = 1:3
    k = k + 1;
    M = zeros(3, 3);
    M(1, j) = 1;
    effMats{k} = M;
    labels{k} = sprintf('单群体促进：A1→B%d 促进', j);
end
for j = 1:3
    k = k + 1;
    M = zeros(3, 3);
    M(1, j) = -1;
    effMats{k} = M;
    labels{k} = sprintf('单群体抑制：A1→B%d 抑制', j);
end
pairs = {[1 2], [1 3], [2 3]};
for pi = 1:3
    k = k + 1;
    M = zeros(3, 3);
    M(1, pairs{pi}(1)) = 1;
    M(1, pairs{pi}(2)) = 1;
    effMats{k} = M;
    labels{k} = sprintf('双群体促进：A1→B%d,B%d', pairs{pi}(1), pairs{pi}(2));
end
for pi = 1:3
    k = k + 1;
    M = zeros(3, 3);
    M(1, pairs{pi}(1)) = -1;
    M(1, pairs{pi}(2)) = -1;
    effMats{k} = M;
    labels{k} = sprintf('双群体抑制：A1→B%d,B%d', pairs{pi}(1), pairs{pi}(2));
end
k = k + 1;
effMats{k} = [1 -1 0; 0 0 0; 0 0 0];
labels{k} = '双群体异号：A1→B1促进 B2抑制';
k = k + 1;
effMats{k} = [1 0 -1; 0 0 0; 0 0 0];
labels{k} = '双群体异号：A1→B1促进 B3抑制';
k = k + 1;
effMats{k} = [0 1 -1; 0 0 0; 0 0 0];
labels{k} = '双群体异号：A1→B2促进 B3抑制';
k = k + 1;
effMats{k} = [1 1 -1; 0 0 0; 0 0 0];
labels{k} = '三群体：B1B2促进 B3抑制';
k = k + 1;
effMats{k} = [1 -1 1; 0 0 0; 0 0 0];
labels{k} = '三群体：B1B3促进 B2抑制';
k = k + 1;
effMats{k} = [-1 1 1; 0 0 0; 0 0 0];
labels{k} = '三群体：B2B3促进 B1抑制';

assert(k == 18, 'triple_qs_topology18:Count', '须恰好 18 条。');
end
