function selection = asOfValue(panel,seriesID,observationDate,forecastOrigin)
%ASOFVALUE Return only the vintage valid at the specified forecast origin.

arguments
    panel table
    seriesID (1,1) string
    observationDate (1,1) datetime
    forecastOrigin (1,1) datetime
end

panel = macro.v2.validateVintagePanel(panel);
if isnat(observationDate) || isnat(forecastOrigin)
    error("macro:v2:asOfValue:InvalidDate", ...
        "Observation date and forecast origin must be valid datetimes.");
end

isAvailable = panel.SeriesID == seriesID & ...
    panel.ObservationDate == observationDate & ...
    panel.RealtimeStart <= forecastOrigin & ...
    panel.RealtimeEnd >= forecastOrigin;

if ~any(isAvailable)
    error("macro:v2:asOfValue:ObservationUnavailable", ...
        "%s for %s was not available at forecast origin %s.", ...
        seriesID,string(observationDate),string(forecastOrigin));
end
if sum(isAvailable) > 1
    error("macro:v2:asOfValue:AmbiguousVintage", ...
        "Multiple vintages are valid at the requested forecast origin.");
end

selection = panel(isAvailable,:);
selection.AvailableDate = selection.RealtimeStart;
selection.ForecastOrigin = forecastOrigin;
selection = macro.v2.validateAvailability(selection);
end
