function cfg = projectConfig(projectRoot,options)
%PROJECTCONFIG Build the shared project path and execution configuration.
%   CFG = macro.projectConfig(PROJECTROOT) returns absolute paths for the
%   repository and its standard input/output directories. OUTPUTROOT may be
%   overridden so tests and future isolated runs do not touch committed
%   artifacts.

arguments
    projectRoot (1,1) string = ""
    options.OutputRoot (1,1) string = ""
    options.RefreshData (1,1) logical = false
    options.GenerateFigures (1,1) logical = true
    options.StopOnError (1,1) logical = true
end

if strlength(projectRoot) == 0
    projectRoot = macro.findProjectRoot(mfilename("fullpath"));
else
    projectRoot = macro.findProjectRoot(projectRoot);
end

if strlength(options.OutputRoot) == 0
    outputRoot = projectRoot;
else
    outputRoot = absoluteCanonicalPath(options.OutputRoot);
end

cfg = struct( ...
    "ProjectRoot", projectRoot, ...
    "ScriptsDir", fullfile(projectRoot,"scripts"), ...
    "SourceDir", fullfile(projectRoot,"src"), ...
    "TestsDir", fullfile(projectRoot,"tests"), ...
    "SourceDataDir", fullfile(projectRoot,"data"), ...
    "OutputRoot", outputRoot, ...
    "DataDir", fullfile(outputRoot,"data"), ...
    "ResultsDir", fullfile(outputRoot,"results"), ...
    "FiguresDir", fullfile(outputRoot,"figures"), ...
    "RefreshData", options.RefreshData, ...
    "GenerateFigures", options.GenerateFigures, ...
    "StopOnError", options.StopOnError);
end

function pathOut = absoluteCanonicalPath(pathIn)
pathFile = java.io.File(char(pathIn));
if ~pathFile.isAbsolute()
    pathFile = java.io.File(char(pwd),char(pathIn));
end
pathOut = string(pathFile.getCanonicalPath());
end
