function varargout = triple_qs_production_orbit8(action, varargin)
%TRIPLE_QS_PRODUCTION_ORBIT8 三菌产三信号：在 S3×S3（菌株与信号类型可分别置换）下的 **8 类**产率结构（约束母集）
%
% 约束母集（与组合题一致）：每菌至少产 1 种、至多 2 种信号；三种信号 A1–A3 均至少被某一菌产出。
%   对应 stratN∈{2..7}（排除「无」与「全产三种」），且三菌 bitmask 之 OR 为 7。
%   共 138 种标号策略，在 S3×S3 下去重得 **8** 轨；本文件内嵌查找表。
%
% 用法：
%   T = triple_qs_production_orbit8('triples');           % 138×3，每行 (stratN1,stratN2,stratN3)
%   oid = triple_qs_production_orbit8('id', a, b, c);   % 1..8 若在母集内，否则 0
%   lbl = triple_qs_production_orbit8('labels');        % 8×1 cellstr 中文简述
%   m = triple_qs_production_orbit8('rowMask', stratId); % stratId 1..8 → 行 bitmask（bit2=A1, bit1=A2, bit0=A3）
%
% 参见：build_modular_qs_simulink_model_triple 默认 TripleProductionSweepMode='constrained138'。
% **T_k**（热图横轴）= 本文件的轨编号 **k** = `id(...)` 返回值 = 嵌入表第四列 prodOrbit8；中文说明见 `labels{k}`（P1..P8 与 k 同序）。
if nargin < 1
    action = "triples";
elseif isempty(action)
    action = "triples";
end
act = lower(strtrim(string(action)));

if act == "rowmask" || act == "mask"
    if nargin < 2
        error('triple_qs_production_orbit8:Args', 'rowmask 需要 stratId。');
    end
    varargout{1} = local_strat_row_mask8(varargin{1});
    return;
end

if act == "id"
    if nargin < 4
        error('triple_qs_production_orbit8:Args', 'id 需要 (a,b,c) 三个 strat 编号 1..8。');
    end
    a = varargin{1};
    b = varargin{2};
    c = varargin{3};
    varargout{1} = local_lookup_orbit_id(a, b, c);
    return;
end

if act == "labels"
    varargout{1} = local_orbit_labels();
    return;
end

if act == "triples" || act == "constrained138"
    M = local_embedded_table();
    varargout{1} = M(:, 1:3);
    return;
end

if act == "table"
    varargout{1} = local_embedded_table();
    return;
end

error('triple_qs_production_orbit8:BadAction', '未知 action：%s', char(act));
end

function m = local_strat_row_mask8(stratId)
% 与 local_tripleStratToRates8 一致：bit2=A1, bit1=A2, bit0=A3（与 MATLAB 位序书写无关，仅为 0..7 整数）
switch stratId
    case 1, m = uint8(0);
    case 2, m = uint8(4);  % 100
    case 3, m = uint8(2);  % 010
    case 4, m = uint8(1);  % 001
    case 5, m = uint8(6);  % 110
    case 6, m = uint8(5);  % 101
    case 7, m = uint8(3);  % 011
    case 8, m = uint8(7);
    otherwise
        error('triple_qs_production_orbit8:BadStrat', 'stratId 须为 1..8。');
end
end

function oid = local_lookup_orbit_id(a, b, c)
persistent T
if isempty(T)
    T = local_embedded_table();
end
aa = uint8(a); bb = uint8(b); cc = uint8(c);
oid = uint8(0);
for r = 1:size(T, 1)
    if T(r, 1) == aa && T(r, 2) == bb && T(r, 3) == cc
        oid = T(r, 4);
        return;
    end
end
end

function lbl = local_orbit_labels()
lbl = {
    'P1:4边 (1,1,2)/(1,1,2) 两菌同产单信号'
    'P2:3边 完美匹配 (1,1,1)/(1,1,1)'
    'P3:4边 (1,1,2)/(1,1,2) 两菌各产不同单信号'
    'P4:5边 (1,2,2)/(1,1,3) 含一信号被三菌同时产出'
    'P5:5边 (1,2,2)/(1,2,2) 无三度信号桶'
    'P6:5边 (1,2,2)/(1,2,2) 两菌共享同一对信号'
    'P7:6边 全度2 (1,2,3) 于信号侧'
    'P8:6边 全度2 (2,2,2) 六边圈型'
    };
end

function M = local_embedded_table()
% 138×4：[stratN1 stratN2 stratN3 prodOrbit8]（prodOrbit8 由 S3×S3 轨枚举预计算）
M = uint8([
  2 2 7 1;
  2 3 4 2;
  2 3 6 3;
  2 3 7 3;
  2 4 3 2;
  2 4 5 3;
  2 4 7 3;
  2 5 4 3;
  2 5 6 4;
  2 5 7 5;
  2 6 3 3;
  2 6 5 4;
  2 6 7 5;
  2 7 2 1;
  2 7 3 3;
  2 7 4 3;
  2 7 5 5;
  2 7 6 5;
  2 7 7 6;
  3 2 4 2;
  3 2 6 3;
  3 2 7 3;
  3 3 6 1;
  3 4 2 2;
  3 4 5 3;
  3 4 6 3;
  3 5 4 3;
  3 5 6 5;
  3 5 7 4;
  3 6 2 3;
  3 6 3 1;
  3 6 4 3;
  3 6 5 5;
  3 6 6 6;
  3 6 7 5;
  3 7 2 3;
  3 7 5 4;
  3 7 6 5;
  4 2 3 2;
  4 2 5 3;
  4 2 7 3;
  4 3 2 2;
  4 3 5 3;
  4 3 6 3;
  4 4 5 1;
  4 5 2 3;
  4 5 3 3;
  4 5 4 1;
  4 5 5 6;
  4 5 6 5;
  4 5 7 5;
  4 6 3 3;
  4 6 5 5;
  4 6 7 4;
  4 7 2 3;
  4 7 5 5;
  4 7 6 4;
  5 2 4 3;
  5 2 6 4;
  5 2 7 5;
  5 3 4 3;
  5 3 6 5;
  5 3 7 4;
  5 4 2 3;
  5 4 3 3;
  5 4 4 1;
  5 4 5 6;
  5 4 6 5;
  5 4 7 5;
  5 5 4 6;
  5 5 6 7;
  5 5 7 7;
  5 6 2 4;
  5 6 3 5;
  5 6 4 5;
  5 6 5 7;
  5 6 6 7;
  5 6 7 8;
  5 7 2 5;
  5 7 3 4;
  5 7 4 5;
  5 7 5 7;
  5 7 6 8;
  5 7 7 7;
  6 2 3 3;
  6 2 5 4;
  6 2 7 5;
  6 3 2 3;
  6 3 3 1;
  6 3 4 3;
  6 3 5 5;
  6 3 6 6;
  6 3 7 5;
  6 4 3 3;
  6 4 5 5;
  6 4 7 4;
  6 5 2 4;
  6 5 3 5;
  6 5 4 5;
  6 5 5 7;
  6 5 6 7;
  6 5 7 8;
  6 6 3 6;
  6 6 5 7;
  6 6 7 7;
  6 7 2 5;
  6 7 3 5;
  6 7 4 4;
  6 7 5 8;
  6 7 6 7;
  6 7 7 7;
  7 2 2 1;
  7 2 3 3;
  7 2 4 3;
  7 2 5 5;
  7 2 6 5;
  7 2 7 6;
  7 3 2 3;
  7 3 5 4;
  7 3 6 5;
  7 4 2 3;
  7 4 5 5;
  7 4 6 4;
  7 5 2 5;
  7 5 3 4;
  7 5 4 5;
  7 5 5 7;
  7 5 6 8;
  7 5 7 7;
  7 6 2 5;
  7 6 3 5;
  7 6 4 4;
  7 6 5 8;
  7 6 6 7;
  7 6 7 7;
  7 7 2 6;
  7 7 5 7;
  7 7 6 7
  ]);
assert(size(M, 1) == 138, 'triple_qs_production_orbit8:Count', '须 138 行。');
end
