function projectRoot = findProjectRoot(startLocation)
%FINDPROJECTROOT Locate the macroeconometrics repository root.
%   PROJECTROOT = macro.findProjectRoot(STARTLOCATION) walks upward from a
%   file or directory until it finds the repository markers README.md,
%   scripts/, and data/. The returned path is absolute and canonical.

arguments
    startLocation (1,1) string = string(pwd)
end

startLocation = canonicalPath(startLocation);

if isfile(startLocation)
    candidate = string(fileparts(startLocation));
elseif isfolder(startLocation)
    candidate = startLocation;
else
    error("macro:findProjectRoot:StartLocationNotFound", ...
        "Start location does not exist: %s", startLocation);
end

while true
    if hasProjectMarkers(candidate)
        projectRoot = candidate;
        return
    end

    parent = string(fileparts(candidate));
    if parent == candidate || strlength(parent) == 0
        break
    end
    candidate = parent;
end

error("macro:findProjectRoot:ProjectRootNotFound", ...
    ["Could not locate the project root from %s. Expected a parent " + ...
     "containing README.md, scripts/, and data/."], startLocation);
end

function tf = hasProjectMarkers(candidate)
tf = isfile(fullfile(candidate,"README.md")) && ...
    isfolder(fullfile(candidate,"scripts")) && ...
    isfolder(fullfile(candidate,"data"));
end

function pathOut = canonicalPath(pathIn)
pathOut = string(java.io.File(char(pathIn)).getCanonicalPath());
end
