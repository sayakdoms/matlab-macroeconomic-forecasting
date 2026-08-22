function status = ensureOutputDirectories(cfg)
%ENSUREOUTPUTDIRECTORIES Create only the isolated V2 output hierarchy.

arguments
    cfg (1,1) struct
end

required = ["ProjectRoot","OutputRoot","DataDir","VintageDataDir", ...
    "ResultsDir","FiguresDir","RefreshVintages","GenerateFigures", ...
    "StopOnError"];
missing = required(~isfield(cfg,required));
if ~isempty(missing)
    error("macro:v2:ensureOutputDirectories:InvalidConfiguration", ...
        "V2 configuration is missing required field(s): %s", ...
        strjoin(missing,", "));
end

% Rebuild the configuration to reapply all V1-overlap guards before any
% directory is created. Preserve the caller's output and execution options.
validated = macro.v2.projectConfig(string(cfg.ProjectRoot), ...
    OutputRoot=string(cfg.OutputRoot), ...
    RefreshVintages=logical(cfg.RefreshVintages), ...
    GenerateFigures=logical(cfg.GenerateFigures), ...
    StopOnError=logical(cfg.StopOnError));

pathFields = ["DataDir","VintageDataDir","ResultsDir","FiguresDir"];
for fieldName = pathFields
    if canonicalPath(string(cfg.(fieldName))) ~= ...
            canonicalPath(string(validated.(fieldName)))
        error("macro:v2:ensureOutputDirectories:ConfigurationMismatch", ...
            "%s does not match the validated V2 configuration.",fieldName);
    end
end
baseStatus = macro.ensureOutputDirectories(validated);

vintageDir = canonicalPath(string(validated.VintageDataDir));
dataDir = canonicalPath(string(validated.DataDir));
if ~isStrictDescendant(vintageDir,dataDir)
    error("macro:v2:ensureOutputDirectories:UnsafeVintagePath", ...
        "VintageDataDir must be a strict descendant of the V2 DataDir.");
end

created = false;
if ~isfolder(vintageDir)
    [success,message] = mkdir(vintageDir);
    if ~success
        error("macro:v2:ensureOutputDirectories:DirectoryCreationFailed", ...
            "Could not create vintage directory %s: %s",vintageDir,message);
    end
    created = true;
end
vintageStatus = table(vintageDir,created, ...
    'VariableNames',{'Directory','Created'});
status = [baseStatus;vintageStatus];
end

function tf = isStrictDescendant(candidate,parent)
parent = parent + string(filesep);
if ispc
    tf = startsWith(lower(candidate),lower(parent));
else
    tf = startsWith(candidate,parent);
end
end

function pathOut = canonicalPath(pathIn)
pathOut = string(java.io.File(char(pathIn)).getCanonicalPath());
end
