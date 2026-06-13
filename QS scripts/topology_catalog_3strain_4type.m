function catalog = topology_catalog_3strain_4type(M, K, kA_sum, mdPath)
%TOPOLOGY_CATALOG_3STRAIN_4TYPE 三标号菌株 × 四策略 → 4^3=64 套 produce / kA_vec，可选写 Markdown
%
% 用法：
%   catalog = topology_catalog_3strain_4type(3, 2, 0.1);
%   catalog = topology_catalog_3strain_4type(3, 2, 0.1, 'out.md');
%
% 参见生成的 topology_catalog_3strain_4types.md（由 mdPath 写出）。

if nargin < 1 || isempty(M)
    M = 3;
end
if nargin < 2 || isempty(K)
    K = 2;
end
if nargin < 3 || isempty(kA_sum)
    kA_sum = 0.1;
end
if M ~= 3
    error("topology_catalog_3strain_4type:OnlyM3", "当前枚举仅实现 M=3（4^3 种）。");
end

n = 4^M;
catalog(1, n) = local_emptyEntry();
idx = 0;
for t1 = 1:4
    for t2 = 1:4
        for t3 = 1:4
            idx = idx + 1;
            typesAll = [t1, t2, t3];
            [produce, kA_vec, nShare] = local_typesToProduceKA(typesAll, M, K, kA_sum);
            catalog(idx).id = idx;
            catalog(idx).types = typesAll;
            catalog(idx).code = sprintf("%d-%d-%d", t1, t2, t3);
            catalog(idx).name = local_longName(typesAll);
            catalog(idx).produce = produce;
            catalog(idx).kA_vec = kA_vec;
            catalog(idx).n_sharers = nShare;
            if nShare == 0
                catalog(idx).note = "无人平摊信号：kA 全 0";
            else
                catalog(idx).note = sprintf("平摊株数=%d，各得 kA=%.6g", nShare, kA_sum / nShare);
            end
        end
    end
end

if nargin >= 4 && ~isempty(mdPath)
    local_writeMd(catalog, mdPath);
end
end

function local_writeMd(catalog, outPath)
lines = strings(0, 1);
lines(end+1) = "# 三菌株四类型策略目录（主表：**20 种**无标号 multiset / 规范序）";
lines(end+1) = "";
lines(end+1) = "主表给出 **\(t_1 \\\\leq t_2 \\\\leq t_3\)** 的 20 个代表（与 **`ONLY_UNLABELED_20=true`**、`qs_topology_sim_cache_unlabeled20.mat` 热图索引 1–20 一致）。附录为 **64** 种有标号全枚举。";
lines(end+1) = "";
lines(end+1) = "## 与 64 种的关系";
lines(end+1) = "- **20**： multiset / 同质菌株、槽位可置换。";
lines(end+1) = "- **64**：三槽有标号，**4³** 全表；`ONLY_UNLABELED_20=false` 时使用。";
lines(end+1) = "";
lines(end+1) = "## 校对说明";
lines(end+1) = "- **公共物**：`produce(j,:)=[1 1]` 为参与两性状生产；`[0 0]` 为不参与。";
lines(end+1) = "- **信号分子 A**：`sum(kA_vec)=kA_sum`。**类型 1、4** 平摊；**类型 2、3** 的 `kA_j=0`。";
lines(end+1) = "- **退化**：三株均为类型 2 或 3 → **`kA_vec` 全 0**。";
lines(end+1) = "";
lines(end+1) = "## 单株四类型定义";
lines(end+1) = "";
lines(end+1) = "| 类型 | 信号（平摊池） | 公共物 `produce` 行 |";
lines(end+1) = "| --- | --- | --- |";
lines(end+1) = "| **1** | 参与平摊（与类型 1、4 均分 `kA_sum`） | `[1 1]` |";
lines(end+1) = "| **2** | 不参与平摊（`kA_j=0`） | `[1 1]` |";
lines(end+1) = "| **3** | 不参与平摊 | `[0 0]` |";
lines(end+1) = "| **4** | 参与平摊 | `[0 0]` |";
lines(end+1) = "";

idx20 = [];
for k = 1:numel(catalog)
    if local_typesSortedForMd(catalog(k).types)
        idx20(end+1) = k; %#ok<AGROW>
    end
end

lines(end+1) = "## 主表：20 种组合（规范序 \(t_1 \\\\leq t_2 \\\\leq t_3\)）";
lines(end+1) = "";
lines(end+1) = "| ID | 编码 (株1-株2-株3) | 对应全表 64 中的 ID | `produce` | `kA_vec` | 平摊株数 | 备注 |";
lines(end+1) = "| ---: | --- | ---: | --- | --- | ---: | --- |";
for j = 1:numel(idx20)
    c = catalog(idx20(j));
    pstr = mat2str(c.produce, 3);
    kstr = mat2str(c.kA_vec, 4);
    lines(end+1) = sprintf("| %d | %s | %d | %s | %s | %d | %s |", ...
        j, c.code, c.id, pstr, kstr, c.n_sharers, c.note);
end

lines(end+1) = "";
lines(end+1) = "### 20 种长名称";
lines(end+1) = "";
for j = 1:numel(idx20)
    c = catalog(idx20(j));
    lines(end+1) = sprintf("- **%d** `%s`：%s", j, c.code, c.name);
end

lines(end+1) = "";
lines(end+1) = "## 附录：有标号全枚举（4³ = 64）";
lines(end+1) = "";
lines(end+1) = "| ID | 编码 (株1-株2-株3) | `produce` | `kA_vec` | 平摊株数 | 备注 |";
lines(end+1) = "| ---: | --- | --- | --- | ---: | --- |";

for k = 1:numel(catalog)
    c = catalog(k);
    pstr = mat2str(c.produce, 3);
    kstr = mat2str(c.kA_vec, 4);
    lines(end+1) = sprintf("| %d | %s | %s | %s | %d | %s |", ...
        c.id, c.code, pstr, kstr, c.n_sharers, c.note);
end

lines(end+1) = "";
lines(end+1) = "## 附录：64 种长名称检索";
lines(end+1) = "";
for k = 1:numel(catalog)
    lines(end+1) = sprintf("- **%d** `%s`：%s", catalog(k).id, catalog(k).code, catalog(k).name);
end

txt = strjoin(lines, newline);
fid = fopen(outPath, "w");
if fid < 0
    error("topology_catalog_3strain_4type:WriteFailed", "无法写入：%s", outPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", txt);
end

function s = local_emptyEntry()
s = struct( ...
    "id", [], ...
    "types", [], ...
    "code", "", ...
    "name", "", ...
    "produce", [], ...
    "kA_vec", [], ...
    "n_sharers", [], ...
    "note", "");
end

function [produce, kA_vec, nShare] = local_typesToProduceKA(types, M, K, kA_sum)
produce = zeros(M, K);
share = false(1, M);
for j = 1:M
    switch types(j)
        case 1
            produce(j, :) = 1;
            share(j) = true;
        case 2
            produce(j, :) = 1;
            share(j) = false;
        case 3
            produce(j, :) = 0;
            share(j) = false;
        case 4
            produce(j, :) = 0;
            share(j) = true;
        otherwise
            error("topology_catalog_3strain_4type:BadType", "类型须为 1..4。");
    end
end
nShare = sum(share);
kA_vec = zeros(1, M);
if nShare > 0
    kA_vec(share) = kA_sum / nShare;
end
end

function name = local_longName(types)
lbl = ["T1平摊产A+产公"; "T2不产A+产公"; "T3不产A+不产公"; "T4平摊产A+不产公"];
parts = strings(1, numel(types));
for j = 1:numel(types)
    parts(j) = lbl(types(j));
end
name = strjoin(parts, " | ");
end

function tf = local_typesSortedForMd(types)
tv = reshape(double(types), 1, []);
tf = all(diff(tv) >= 0);
end
