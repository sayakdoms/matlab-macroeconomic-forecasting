function origins = generateForecastOrigins(panel,options)
%GENERATEFORECASTORIGINS Generate deterministic V2 historical origins.

arguments
    panel table
    options.EvaluationStart (1,1) datetime = datetime(2016,1,1)
    options.EvaluationEnd (1,1) datetime = NaT
    options.Protocol (1,1) struct = macro.v2.forecastProtocol()
end

panel = macro.v2.validateVintagePanel(panel);
if isnat(options.EvaluationStart) || ...
        options.EvaluationStart ~= dateshift( ...
        options.EvaluationStart,"start","quarter")
    error("macro:v2:generateForecastOrigins:InvalidEvaluationStart", ...
        "EvaluationStart must be the first day of a calendar quarter.");
end
if ~isnat(options.EvaluationEnd) && ( ...
        options.EvaluationEnd ~= dateshift( ...
        options.EvaluationEnd,"start","quarter") || ...
        options.EvaluationEnd < options.EvaluationStart)
    error("macro:v2:generateForecastOrigins:InvalidEvaluationEnd", ...
        "EvaluationEnd must be a quarter start on or after EvaluationStart.");
end

gdpDates = unique(panel.ObservationDate( ...
    panel.SeriesID == string(options.Protocol.TargetSeriesID)));
gdpDates = sort(gdpDates);
hasPriorQuarter = ismember(gdpDates-calmonths(3),gdpDates);
targetQuarters = gdpDates(hasPriorQuarter & ...
    gdpDates >= options.EvaluationStart);
if ~isnat(options.EvaluationEnd)
    targetQuarters = targetQuarters(targetQuarters <= options.EvaluationEnd);
end
if isempty(targetQuarters)
    error("macro:v2:generateForecastOrigins:NoEligibleTargets", ...
        "The vintage panel contains no eligible GDP target quarters.");
end

rules = string(options.Protocol.OriginRules.Name);
numRows = numel(targetQuarters)*numel(rules);
TargetQuarter = NaT(numRows,1);
OriginRule = strings(numRows,1);
ForecastOrigin = NaT(numRows,1);
rowIndex = 0;
for quarterIndex = 1:numel(targetQuarters)
    for ruleIndex = 1:numel(rules)
        rowIndex = rowIndex + 1;
        TargetQuarter(rowIndex) = targetQuarters(quarterIndex);
        OriginRule(rowIndex) = rules(ruleIndex);
        ForecastOrigin(rowIndex) = macro.v2.forecastOrigin( ...
            targetQuarters(quarterIndex),rules(ruleIndex),options.Protocol);
    end
end
TargetQuarter.Format = "yyyy-MM-dd";
ForecastOrigin.Format = "yyyy-MM-dd";
origins = table(TargetQuarter,OriginRule,ForecastOrigin);
end
