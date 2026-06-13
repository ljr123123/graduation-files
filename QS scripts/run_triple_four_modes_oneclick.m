function run_triple_four_modes_oneclick(rootDir)
%RUN_TRIPLE_FOUR_MODES_ONECLICK 三菌群欺骗扫描：一键依次跑 **4 种**组合
%
%   迟滞 × 本菌产物 B_i 对 N_i：有迟滞 / 无迟滞 × 促进 (+ω) / 抑制 (−ω) ＝ 4 组。
%   每组：**P1–P8** 产率类（=T1–T8）× 每类内全部标号产率策略（138 母集按轨分列，短类右侧占位），固定调控矩阵下扫描。
%   图表：每组仅导出 **4 张柱状图**（横轴 P1–P8；纵轴依次为各类内最优策略的「几何平均丰度 / 产物量 / 累积资源消耗 / econGeomScore」），不导出热图。
%   不再使用原 18 种 A1→B 调控拓扑枚举。
%
% 用法（推荐把 root 改成你的 QS scripts 绝对路径后整段运行）：
%   run_triple_four_modes_oneclick;                    % 默认 root = 本文件所在目录
%   run_triple_four_modes_oneclick('d:\work\QS scripts');
%
% 输出：
%   - 数值：<root>\cache_triple18\triple_quad_<标签>_<时间戳>.mat
%   - 图片：<root>\figure_triple_quad\<时间戳>\<标签>\  （P1toP8_summary_*.png 共 4 张）
%
% **不复用数值缓存**：每一组开始前若目标 .mat 已存在则先 delete，再重新做完整 ODE 扫描（不读旧 mat）。
%   每组结束后在命令行打印：该组图表目录、全局最优产率类 **P几**、最优欺骗结构及 **T 轨** 说明。
%
productionMode = 'constrained138';  % 仅支持 constrained138（与 P1–P8 分组一致）；勿用 full512

if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(mfilename('fullpath'));
end
rootDir = char(string(rootDir));
if isempty(rootDir)
    rootDir = pwd;
end
cd(rootDir);
addpath(rootDir);

try
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
catch
    stamp = sprintf('%s_%06d', datestr(now, 'yyyymmdd_HHMMSS'), round(1e6 * (now - floor(now))));
end
cacheDir = fullfile(rootDir, 'cache_triple18');
figRoot = fullfile(rootDir, 'figure_triple_quad', stamp);
if ~isfolder(cacheDir)
    mkdir(cacheDir);
end
if ~isfolder(figRoot)
    mkdir(figRoot);
end

% 四组：{ 迟滞?, 本菌B促进N?, 文件夹标签, mat 文件名标签 }
cases = {
    false, false, 'nohyst_Binhibit',  '非迟滞 + B抑制N';
    false, true,  'nohyst_Bpromote', '非迟滞 + B促进N';
    true,  false, 'hyst_Binhibit',   '迟滞 + B抑制N';
    true,  true,  'hyst_Bpromote',   '迟滞 + B促进N';
    };

commonExtra = { ...
    'RunTripleCommunityDeceptionSweep', true, ...
    'OpenModel', false, ...
    'SaveModel', false, ...
    'DualSaveFigures', true, ...
    'DualFigureResolution', 200, ...
    'DualFigureFormat', 'png', ...
    'TripleProductionSweepMode', productionMode, ...
    'TripleSweepBarsP8Only', true, ...
    'TripleShowWaitbar', true, ...
    'TripleSweepFastApprox', true ...
    };

fprintf('\n======== 三菌群 4 模式一键扫描 | 时间戳 %s ========\n', stamp);
fprintf('根目录: %s\n', rootDir);

summary = cell(size(cases, 1), 1);
for k = 1:size(cases, 1)
    useHyst = logical(cases{k, 1});
    ownBpro = logical(cases{k, 2});
    tag = char(string(cases{k, 3}));
    desc = char(string(cases{k, 4}));

    matPath = fullfile(cacheDir, sprintf('triple_quad_%s_%s.mat', tag, stamp));
    figDir = fullfile(figRoot, tag);
    if ~isfolder(figDir)
        mkdir(figDir);
    end

    fprintf('\n--- [%d/4] %s (%s) ---\n', k, tag, desc);
    fprintf('    mat: %s\n', matPath);
    fprintf('    图:  %s\n', figDir);
    if exist(matPath, 'file')
        delete(matPath);
        fprintf('    （已删除同名旧 mat，本组将重新积分，不复用磁盘结果）\n');
    end

    args = [ commonExtra, { ...
        'DualResultsMat', matPath, ...
        'DualFigureExportDir', figDir, ...
        'TripleOwnBPromotesNi', ownBpro ...
        } ];

    if useHyst
        args = [ args, { 'DualUseHysteresis', true } ];
        build_modular_qs_simulink_model_triple_hyst(args{:});
    else
        build_modular_qs_simulink_model_triple(args{:});
    end

    local_print_quad_case_summary(matPath, tag, desc, figDir);

    summary{k} = struct('tag', tag, 'desc', desc, 'mat', matPath, 'figures', figDir);
end

fprintf('\n======== 全部完成 ========\n');
for k = 1:numel(summary)
    s = summary{k};
    fprintf('%s | %s\n  mat: %s\n  图:  %s\n', s.tag, s.desc, s.mat, s.figures);
end
fprintf('\n图片总根目录: %s\n', figRoot);
fprintf('子文件夹: nohyst_Binhibit, nohyst_Bpromote, hyst_Binhibit, hyst_Bpromote\n');
end

function local_print_quad_case_summary(matPath, tag, desc, figDir)
try
    S = load(matPath, 'tripleSweepMeta', 'stratTick');
catch ME
    fprintf('\n    >>> [%s] 无法读取结果 mat（扫描可能中断或未写入）：%s\n', tag, ME.message);
    return;
end
fprintf('\n    >>> 【%s】%s — 本组小结 <<<\n', tag, desc);
fprintf('        图表保存目录: %s\n', figDir);
if isfolder(figDir)
    pngN = numel(dir(fullfile(figDir, '*.png')));
    fprintf('        （该目录下 png 约 %d 个，含 P* 热图等）\n', pngN);
end
gb = S.tripleSweepMeta.globalBestAmongTopologies;
if ~isfield(gb, 'nCandidates') || isempty(gb.nCandidates) || double(gb.nCandidates) < 1
    fprintf('        全局最优: 无有效候选（各产率类 lexRank=1 为空或字段缺失）\n');
    return;
end
st = S.stratTick;
s1 = st{gb.stratN1};
s2 = st{gb.stratN2};
s3 = st{gb.stratN3};
Tn = double(triple_qs_production_orbit8('id', gb.stratN1, gb.stratN2, gb.stratN3));
pIdx = gb.hypothesis;
if isfield(gb, 'prodP')
    pIdx = gb.prodP;
end
fprintf('        全局最优产率类: **P%d**（同 T%d）| %s\n', pIdx, pIdx, char(string(gb.topologyLabel)));
fprintf('        最优欺骗结构: N1=%s N2=%s N3=%s | 紧凑码 %s\n', s1, s2, s3, char(string(gb.stratCode)));
if isfield(gb, 'econGeomScore')
    fprintf('        econGeomScore=%.4g', gb.econGeomScore);
    if isfield(gb, 'passCountEcon')
        fprintf(' | 经济过线=%g', gb.passCountEcon);
    end
    fprintf('\n');
end
if Tn == 0
    fprintf('        产率轨: 不在 138 母集 (triple_qs_production_orbit8 id=0)，无 T1–T8\n');
else
    lbl = triple_qs_production_orbit8('labels');
    fprintf('        对应产率轨 **T%d**（P%d）: %s\n', Tn, Tn, lbl{Tn});
end
end
