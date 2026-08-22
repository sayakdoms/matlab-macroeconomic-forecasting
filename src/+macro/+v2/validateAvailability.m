function information = validateAvailability(information)
%VALIDATEAVAILABILITY Reject features published after their forecast origin.

arguments
    information table
end

required = ["AvailableDate","ForecastOrigin"];
available = string(information.Properties.VariableNames);
missing = required(~ismember(required,available));
if ~isempty(missing)
    error("macro:v2:validateAvailability:MissingVariables", ...
        "Information set is missing required variable(s): %s", ...
        strjoin(missing,", "));
end
if ~isdatetime(information.AvailableDate) || ...
        ~isdatetime(information.ForecastOrigin) || ...
        any(isnat(information.AvailableDate)) || ...
        any(isnat(information.ForecastOrigin))
    error("macro:v2:validateAvailability:InvalidDates", ...
        "AvailableDate and ForecastOrigin must contain valid datetimes.");
end
if any(information.AvailableDate > information.ForecastOrigin)
    error("macro:v2:validateAvailability:FutureInformation", ...
        "At least one feature was published after its forecast origin.");
end
end
