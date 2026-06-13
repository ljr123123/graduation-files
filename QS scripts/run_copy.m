function modelName = run_copy(varargin)
%RUN_COPY 直接运行同目录下的 copy.m（雪堆博弈版 Simulink 建膜）
%
% 用法（在 MATLAB 命令窗口）：
%   run_copy
%   run_copy("OpenModel", true, "RunSim", true)
%   run_copy("RunDecepSweep", true)
%   run_copy("RunNpopSweep", true)
%
% 说明：copy.m 内函数名为 build_modular_qs_simulink_model，与同目录
% build_modular_qs_simulink_model.m 冲突；本脚本临时解析 copy.m 后调用。

here = fileparts(mfilename('fullpath'));
copyPath = fullfile(here, "copy.m");
if ~isfile(copyPath)
    error("run_copy:NoCopy", "未找到 copy.m：%s", copyPath);
end

tmpDir = tempname;
[ok, msg] = mkdir(tmpDir);
if ~ok
    error("run_copy:Mkdir", "无法创建临时目录：%s", msg);
end
c = onCleanup(@() local_rmdirQuiet(tmpDir));

tmpFile = fullfile(tmpDir, "snowdrift_qs_build.m");
copyfile(copyPath, tmpFile);

txt = fileread(tmpFile);
txt = regexprep(txt, ...
    "^function\s+modelName\s*=\s*build_modular_qs_simulink_model", ...
    "function modelName = snowdrift_qs_build", 1, "dotexceptnewline");
fid = fopen(tmpFile, "w", "n", "UTF-8");
if fid < 0
    error("run_copy:Write", "无法写入临时文件：%s", tmpFile);
end
fprintf(fid, "%s", txt);
fclose(fid);

addpath(tmpDir);
modelName = snowdrift_qs_build(varargin{:});

if nargout == 0
    fprintf("完成，模型：%s\n", modelName);
end
end

function local_rmdirQuiet(d)
if isfolder(d)
    try
        rmdir(d, "s");
    catch %#ok<CTCH>
    end
end
end
