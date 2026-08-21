function status = ensureOutputDirectories(cfg)
%ENSUREOUTPUTDIRECTORIES Safely create configured project output folders.
%   STATUS = macro.ensureOutputDirectories(CFG) validates every destination
%   before creating data/, results/, and figures/. Each destination must be
%   a strict descendant of CFG.OutputRoot. Repeated calls are safe.

arguments
    cfg (1,1) struct
end

requiredFields = ["OutputRoot","DataDir","ResultsDir","FiguresDir"];
missingFields = requiredFields(~isfield(cfg,requiredFields));
if ~isempty(missingFields)
    error("macro:ensureOutputDirectories:InvalidConfiguration", ...
        "Configuration is missing required field(s): %s", ...
        strjoin(missingFields,", "));
end

outputRoot = canonicalPath(string(cfg.OutputRoot));
targets = [string(cfg.DataDir); string(cfg.ResultsDir); string(cfg.FiguresDir)];
canonicalTargets = strings(size(targets));

for index = 1:numel(targets)
    canonicalTargets(index) = canonicalPath(targets(index));
    if ~isStrictDescendant(canonicalTargets(index),outputRoot)
        error("macro:ensureOutputDirectories:UnsafeOutputPath", ...
            "Refusing to create output directory outside OutputRoot: %s", ...
            canonicalTargets(index));
    end
end

wasCreated = false(size(canonicalTargets));
for index = 1:numel(canonicalTargets)
    if ~isfolder(canonicalTargets(index))
        [created,message] = mkdir(canonicalTargets(index));
        if ~created
            error("macro:ensureOutputDirectories:DirectoryCreationFailed", ...
                "Could not create output directory %s: %s", ...
                canonicalTargets(index),message);
        end
        wasCreated(index) = true;
    end
end

status = table(canonicalTargets,wasCreated, ...
    'VariableNames',{'Directory','Created'});
end

function tf = isStrictDescendant(candidate,root)
rootWithSeparator = root + string(filesep);
if ispc
    tf = startsWith(lower(candidate),lower(rootWithSeparator));
else
    tf = startsWith(candidate,rootWithSeparator);
end
end

function pathOut = canonicalPath(pathIn)
pathFile = java.io.File(char(pathIn));
if ~pathFile.isAbsolute()
    pathFile = java.io.File(char(pwd),char(pathIn));
end
pathOut = string(pathFile.getCanonicalPath());
end
