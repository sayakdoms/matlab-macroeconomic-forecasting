function panel = validateVintagePanel(panel)
%VALIDATEVINTAGEPANEL Validate and normalize an ALFRED-style long panel.

arguments
    panel table
end

required = ["SeriesID","ObservationDate","RealtimeStart", ...
    "RealtimeEnd","Value"];
available = string(panel.Properties.VariableNames);
missing = required(~ismember(required,available));
if ~isempty(missing)
    error("macro:v2:validateVintagePanel:MissingVariables", ...
        "Vintage panel is missing required variable(s): %s", ...
        strjoin(missing,", "));
end
if isempty(panel)
    error("macro:v2:validateVintagePanel:EmptyPanel", ...
        "Vintage panel must contain at least one row.");
end

panel.SeriesID = string(panel.SeriesID);
if any(ismissing(panel.SeriesID) | strlength(strtrim(panel.SeriesID)) == 0)
    error("macro:v2:validateVintagePanel:InvalidSeriesID", ...
        "SeriesID values must be nonmissing and nonempty.");
end

for variableName = ["ObservationDate","RealtimeStart","RealtimeEnd"]
    if ~isdatetime(panel.(variableName)) || any(isnat(panel.(variableName)))
        error("macro:v2:validateVintagePanel:InvalidDates", ...
            "%s must contain valid datetime values.",variableName);
    end
end
if ~isnumeric(panel.Value) || ~isvector(panel.Value) || ...
        any(~isfinite(panel.Value))
    error("macro:v2:validateVintagePanel:InvalidValues", ...
        "Value must be a finite numeric vector.");
end
panel.Value = double(panel.Value(:));

if any(panel.RealtimeStart > panel.RealtimeEnd)
    error("macro:v2:validateVintagePanel:InvalidRealtimeInterval", ...
        "RealtimeStart must not be later than RealtimeEnd.");
end

panel = sortrows(panel,["SeriesID","ObservationDate","RealtimeStart"]);
keys = table(panel.SeriesID,panel.ObservationDate,panel.RealtimeStart);
if height(unique(keys,"rows")) ~= height(keys)
    error("macro:v2:validateVintagePanel:DuplicateVintage", ...
        "SeriesID, ObservationDate, and RealtimeStart must be unique.");
end

for rowIndex = 2:height(panel)
    sameObservation = ...
        panel.SeriesID(rowIndex) == panel.SeriesID(rowIndex-1) && ...
        panel.ObservationDate(rowIndex) == panel.ObservationDate(rowIndex-1);
    if sameObservation && ...
            panel.RealtimeStart(rowIndex) <= panel.RealtimeEnd(rowIndex-1)
        error("macro:v2:validateVintagePanel:OverlappingVintages", ...
            "Real-time validity intervals must not overlap.");
    end
end
end
