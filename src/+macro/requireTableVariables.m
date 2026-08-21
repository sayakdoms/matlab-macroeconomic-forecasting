function requireTableVariables(data,requiredVariables,options)
%REQUIRETABLEVARIABLES Require named variables in a table or timetable.
%   macro.requireTableVariables(DATA,NAMES) throws a descriptive error when
%   one or more exact variable names are absent from DATA.

arguments
    data
    requiredVariables (1,:) string
    options.DataName (1,1) string = "input data"
end

if ~(istable(data) || istimetable(data))
    error("macro:requireTableVariables:InvalidInputType", ...
        "%s must be a table or timetable.",options.DataName);
end

if isempty(requiredVariables) || any(strlength(requiredVariables) == 0) || ...
        numel(unique(requiredVariables)) ~= numel(requiredVariables)
    error("macro:requireTableVariables:InvalidRequiredVariables", ...
        "Required variable names must be nonempty and unique.");
end

availableVariables = string(data.Properties.VariableNames);
missingVariables = setdiff(requiredVariables,availableVariables,"stable");

if ~isempty(missingVariables)
    error("macro:requireTableVariables:MissingVariables", ...
        "%s is missing required variable(s): %s", ...
        options.DataName,strjoin(missingVariables,", "));
end
end
