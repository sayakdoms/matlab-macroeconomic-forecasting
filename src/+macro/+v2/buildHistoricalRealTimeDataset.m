function output = buildHistoricalRealTimeDataset(cfg,options)
%BUILDHISTORICALREALTIMEDATASET Build the V2 pseudo-real-time macro data.
%   This function reconstructs data and provenance only. It does not fit,
%   select, compare, or forecast with any model.

arguments
    cfg (1,1) struct
    options.Panel table = table()
    options.RealtimeStart (1,1) datetime = datetime(1776,7,4)
    options.RealtimeEnd (1,1) datetime = dateshift(datetime("today"), ...
        "start","day")
    options.EvaluationStart (1,1) datetime = datetime(2016,1,1)
    options.EvaluationEnd (1,1) datetime = NaT
    options.SaveOutputs (1,1) logical = true
end

protocol = cfg.ForecastProtocol;
if isempty(options.Panel)
    panel = macro.v2.loadCachedVintagePanel(cfg, ...
        RealtimeStart=options.RealtimeStart, ...
        RealtimeEnd=options.RealtimeEnd);
    sourceMode = "validated-cache";
else
    panel = macro.v2.validateVintagePanel(options.Panel);
    sourceMode = "supplied-validated-panel";
end

origins = macro.v2.generateForecastOrigins(panel, ...
    EvaluationStart=options.EvaluationStart, ...
    EvaluationEnd=options.EvaluationEnd,Protocol=protocol);
targetQuarters = unique(origins.TargetQuarter,"stable");
targetComparison = buildTargetComparison(panel,targetQuarters,protocol,cfg);

featureNames = ["GDPGrowth_L1";"Inflation_L1"; ...
    "Unemployment_L1";"InterestRate_L1"];
informationSet = table();
numOrigins = height(origins);
GDPGrowth_L1 = NaN(numOrigins,1);
Inflation_L1 = NaN(numOrigins,1);
Unemployment_L1 = NaN(numOrigins,1);
InterestRate_L1 = NaN(numOrigins,1);
InformationSetComplete = false(numOrigins,1);
TargetGDPGrowthFirstRelease = NaN(numOrigins,1);
TargetFirstReleaseDate = NaT(numOrigins,1);
TargetVintageStart = NaT(numOrigins,1);
PriorGDPVintageStart = NaT(numOrigins,1);

for originIndex = 1:numOrigins
    targetQuarter = origins.TargetQuarter(originIndex);
    originRule = origins.OriginRule(originIndex);
    forecastOrigin = origins.ForecastOrigin(originIndex);
    featureRows = reconstructFeatures( ...
        panel,targetQuarter,originRule,forecastOrigin,featureNames);
    informationSet = [informationSet;featureRows]; %#ok<AGROW>

    values = featureRows.Value;
    GDPGrowth_L1(originIndex) = values(1);
    Inflation_L1(originIndex) = values(2);
    Unemployment_L1(originIndex) = values(3);
    InterestRate_L1(originIndex) = values(4);
    InformationSetComplete(originIndex) = all(featureRows.IsComplete);

    targetIndex = find( ...
        targetComparison.TargetQuarter == targetQuarter,1);
    TargetGDPGrowthFirstRelease(originIndex) = ...
        targetComparison.FirstReleaseGDPGrowth(targetIndex);
    TargetFirstReleaseDate(originIndex) = ...
        targetComparison.FirstReleaseDate(targetIndex);
    TargetVintageStart(originIndex) = ...
        targetComparison.TargetVintageStart(targetIndex);
    PriorGDPVintageStart(originIndex) = ...
        targetComparison.PriorVintageStart(targetIndex);
end

modelingDataset = table(origins.TargetQuarter,origins.OriginRule, ...
    origins.ForecastOrigin,InformationSetComplete,GDPGrowth_L1, ...
    Inflation_L1,Unemployment_L1,InterestRate_L1, ...
    TargetGDPGrowthFirstRelease,TargetFirstReleaseDate, ...
    TargetVintageStart,PriorGDPVintageStart, ...
    'VariableNames',{'TargetQuarter','OriginRule','ForecastOrigin', ...
    'InformationSetComplete','GDPGrowth_L1','Inflation_L1', ...
    'Unemployment_L1','InterestRate_L1', ...
    'TargetGDPGrowthFirstRelease','TargetFirstReleaseDate', ...
    'TargetVintageStart','PriorGDPVintageStart'});

assumptions = macro.v2.publicationDelayAssumptions(protocol);
coverage = buildCoverageSummary(modelingDataset,protocol);
metadata = baseMetadata(panel,origins,informationSet,modelingDataset, ...
    targetComparison,coverage,sourceMode,options.EvaluationStart);

paths = outputPaths(cfg);
if options.SaveOutputs
    macro.v2.ensureOutputDirectories(cfg);
    writeDeterministicTable(informationSet,paths.InformationSet);
    writeDeterministicTable(targetComparison,paths.GDPRevisionComparison);
    writeDeterministicTable(assumptions,paths.PublicationAssumptions);
    writeDeterministicTable(modelingDataset,paths.ModelingDataset);
    writeDeterministicTable(coverage,paths.CoverageSummary);
    metadata.outputChecksums = struct( ...
        "forecastOriginInformationSet", ...
            macro.v2.fileChecksum(paths.InformationSet), ...
        "gdpFirstReleaseVsLatest", ...
            macro.v2.fileChecksum(paths.GDPRevisionComparison), ...
        "publicationDelayAssumptions", ...
            macro.v2.fileChecksum(paths.PublicationAssumptions), ...
        "realTimeMacroModelingDataset", ...
            macro.v2.fileChecksum(paths.ModelingDataset), ...
        "coverageCompletenessSummary", ...
            macro.v2.fileChecksum(paths.CoverageSummary));
    writeMetadata(metadata,paths.Metadata);
end

output = struct( ...
    "ForecastOrigins",origins, ...
    "InformationSet",informationSet, ...
    "GDPRevisionComparison",targetComparison, ...
    "PublicationDelayAssumptions",assumptions, ...
    "ModelingDataset",modelingDataset, ...
    "CoverageSummary",coverage, ...
    "Metadata",metadata, ...
    "Paths",paths);
end

function information = reconstructFeatures( ...
        panel,targetQuarter,originRule,forecastOrigin,featureNames)
priorQuarter = targetQuarter-calmonths(3);
twoQuartersBack = targetQuarter-calmonths(6);
requiredDates = { ...
    [twoQuartersBack;priorQuarter], ...
    [monthlyDates(twoQuartersBack);monthlyDates(priorQuarter)], ...
    monthlyDates(priorQuarter), ...
    monthlyDates(priorQuarter)};
seriesIDs = ["GDPC1";"CPIAUCSL";"UNRATE";"FEDFUNDS"];

numFeatures = numel(featureNames);
TargetQuarter = repmat(targetQuarter,numFeatures,1);
OriginRule = repmat(originRule,numFeatures,1);
ForecastOrigin = repmat(forecastOrigin,numFeatures,1);
Feature = featureNames;
SourceSeries = seriesIDs;
Value = NaN(numFeatures,1);
RequiredObservationCount = zeros(numFeatures,1);
AvailableObservationCount = zeros(numFeatures,1);
IsComplete = false(numFeatures,1);
RequiredObservationDates = strings(numFeatures,1);
SelectedObservationDates = strings(numFeatures,1);
SelectedRealtimeStarts = strings(numFeatures,1);
SelectedValues = strings(numFeatures,1);
LatestSelectedVintageStart = NaT(numFeatures,1);
LatestRequiredAvailabilityDate = NaT(numFeatures,1);
IncompleteReason = strings(numFeatures,1);

for featureIndex = 1:numFeatures
    dates = requiredDates{featureIndex};
    RequiredObservationCount(featureIndex) = numel(dates);
    RequiredObservationDates(featureIndex) = joinDates(dates);
    [selected,firstReleaseDates,missingFromPanel] = selectAsOfMany( ...
        panel,seriesIDs(featureIndex),dates,forecastOrigin);
    AvailableObservationCount(featureIndex) = height(selected);
    IsComplete(featureIndex) = height(selected) == numel(dates);
    SelectedObservationDates(featureIndex) = ...
        joinDates(selected.ObservationDate);
    SelectedRealtimeStarts(featureIndex) = ...
        joinDates(selected.RealtimeStart);
    SelectedValues(featureIndex) = joinNumbers(selected.Value);
    if ~isempty(selected)
        LatestSelectedVintageStart(featureIndex) = ...
            max(selected.RealtimeStart);
    end
    if ~any(isnat(firstReleaseDates))
        LatestRequiredAvailabilityDate(featureIndex) = ...
            max(firstReleaseDates);
    end
    if IsComplete(featureIndex)
        Value(featureIndex) = transformFeature( ...
            featureNames(featureIndex),selected.Value);
        IncompleteReason(featureIndex) = "";
    elseif missingFromPanel
        IncompleteReason(featureIndex) = "Required observation absent from cache";
    else
        IncompleteReason(featureIndex) = ...
            "Required observation not released by forecast origin";
    end
end

information = table(TargetQuarter,OriginRule,ForecastOrigin,Feature, ...
    SourceSeries,Value,RequiredObservationCount, ...
    AvailableObservationCount,IsComplete,RequiredObservationDates, ...
    SelectedObservationDates,SelectedRealtimeStarts,SelectedValues, ...
    LatestSelectedVintageStart,LatestRequiredAvailabilityDate, ...
    IncompleteReason);

hasSelectedDate = ~isnat(information.LatestSelectedVintageStart);
if any(hasSelectedDate)
    availability = information(hasSelectedDate, ...
        ["LatestSelectedVintageStart","ForecastOrigin"]);
    availability.Properties.VariableNames{1} = 'AvailableDate';
    macro.v2.validateAvailability(availability);
end
end

function [selected,firstReleaseDates,missingFromPanel] = selectAsOfMany( ...
        panel,seriesID,observationDates,forecastOrigin)
selected = panel([],:);
firstReleaseDates = NaT(numel(observationDates),1);
missingFromPanel = false;
for dateIndex = 1:numel(observationDates)
    observationRows = panel.SeriesID == seriesID & ...
        panel.ObservationDate == observationDates(dateIndex);
    if ~any(observationRows)
        missingFromPanel = true;
        continue;
    end
    firstReleaseDates(dateIndex) = min( ...
        panel.RealtimeStart(observationRows));
    validRows = observationRows & ...
        panel.RealtimeStart <= forecastOrigin & ...
        panel.RealtimeEnd >= forecastOrigin;
    if sum(validRows) > 1
        error("macro:v2:buildHistoricalRealTimeDataset:AmbiguousVintage", ...
            "Multiple vintages are valid for %s on %s.", ...
            seriesID,string(observationDates(dateIndex)));
    end
    if any(validRows)
        selected = [selected;panel(validRows,:)]; %#ok<AGROW>
    end
end
selected = sortrows(selected,"ObservationDate");
end

function value = transformFeature(featureName,values)
switch featureName
    case "GDPGrowth_L1"
        value = 400*log(values(2)/values(1));
    case "Inflation_L1"
        value = 400*log(mean(values(4:6))/mean(values(1:3)));
    case {"Unemployment_L1","InterestRate_L1"}
        value = mean(values);
    otherwise
        error("macro:v2:buildHistoricalRealTimeDataset:UnknownFeature", ...
            "Unknown feature: %s",featureName);
end
end

function comparison = buildTargetComparison(panel,targetQuarters,protocol,cfg)
numTargets = numel(targetQuarters);
TargetQuarter = targetQuarters;
FirstReleaseDate = NaT(numTargets,1);
TargetVintageStart = NaT(numTargets,1);
PriorVintageStart = NaT(numTargets,1);
FirstReleaseTargetGDP = NaN(numTargets,1);
FirstReleasePriorGDP = NaN(numTargets,1);
FirstReleaseGDPGrowth = NaN(numTargets,1);
LatestTargetGDP = NaN(numTargets,1);
LatestPriorGDP = NaN(numTargets,1);
LatestGDPGrowth = NaN(numTargets,1);
TargetLevelRevision = NaN(numTargets,1);
GDPGrowthRevision = NaN(numTargets,1);
V1RevisedGDP = NaN(numTargets,1);
V1RevisedGDPGrowth = NaN(numTargets,1);
FirstReleaseVsV1GDPDifference = NaN(numTargets,1);
FirstReleaseVsV1GDPGrowthDifference = NaN(numTargets,1);

v1Path = fullfile(cfg.V1DataDir,"Macroeconomic_Data_Quarterly.csv");
if ~isfile(v1Path)
    error("macro:v2:buildHistoricalRealTimeDataset:MissingV1Baseline", ...
        "The read-only V1 quarterly baseline is unavailable: %s",v1Path);
end
v1Data = readtable(v1Path,TextType="string");
v1Data = macro.validateQuarterlyData(v1Data);

for targetIndex = 1:numTargets
    target = macro.v2.firstReleaseGDPGrowth( ...
        panel,targetQuarters(targetIndex),protocol);
    latestTarget = latestValue(panel,"GDPC1",targetQuarters(targetIndex));
    latestPrior = latestValue( ...
        panel,"GDPC1",targetQuarters(targetIndex)-calmonths(3));
    latestGrowth = 400*log(latestTarget.Value/latestPrior.Value);

    FirstReleaseDate(targetIndex) = target.FirstReleaseDate;
    TargetVintageStart(targetIndex) = target.TargetVintageStart;
    PriorVintageStart(targetIndex) = target.PriorVintageStart;
    FirstReleaseTargetGDP(targetIndex) = target.TargetGDP;
    FirstReleasePriorGDP(targetIndex) = target.PriorQuarterGDP;
    FirstReleaseGDPGrowth(targetIndex) = target.GDPGrowth;
    LatestTargetGDP(targetIndex) = latestTarget.Value;
    LatestPriorGDP(targetIndex) = latestPrior.Value;
    LatestGDPGrowth(targetIndex) = latestGrowth;
    TargetLevelRevision(targetIndex) = latestTarget.Value-target.TargetGDP;
    GDPGrowthRevision(targetIndex) = latestGrowth-target.GDPGrowth;
    v1Index = find(v1Data.observation_date == ...
        targetQuarters(targetIndex),1);
    if ~isempty(v1Index)
        V1RevisedGDP(targetIndex) = v1Data.RealGDP(v1Index);
        V1RevisedGDPGrowth(targetIndex) = v1Data.GDPGrowth(v1Index);
        FirstReleaseVsV1GDPDifference(targetIndex) = ...
            target.TargetGDP-v1Data.RealGDP(v1Index);
        FirstReleaseVsV1GDPGrowthDifference(targetIndex) = ...
            target.GDPGrowth-v1Data.GDPGrowth(v1Index);
    end
end

comparison = table(TargetQuarter,FirstReleaseDate,TargetVintageStart, ...
    PriorVintageStart,FirstReleaseTargetGDP,FirstReleasePriorGDP, ...
    FirstReleaseGDPGrowth,LatestTargetGDP,LatestPriorGDP, ...
    LatestGDPGrowth,TargetLevelRevision,GDPGrowthRevision,V1RevisedGDP, ...
    V1RevisedGDPGrowth,FirstReleaseVsV1GDPDifference, ...
    FirstReleaseVsV1GDPGrowthDifference);
end

function selected = latestValue(panel,seriesID,observationDate)
rows = panel.SeriesID == seriesID & ...
    panel.ObservationDate == observationDate;
if ~any(rows)
    error("macro:v2:buildHistoricalRealTimeDataset:MissingLatestValue", ...
        "No cached value exists for %s on %s.", ...
        seriesID,string(observationDate));
end
candidates = panel(rows,:);
[~,latestIndex] = max(candidates.RealtimeStart);
selected = candidates(latestIndex,:);
end

function coverage = buildCoverageSummary(modelingDataset,protocol)
rules = string(protocol.OriginRules.Name);
numRules = numel(rules);
OriginRule = rules;
TotalOrigins = zeros(numRules,1);
CompleteInformationSets = zeros(numRules,1);
IncompleteInformationSets = zeros(numRules,1);
CompletePercent = zeros(numRules,1);
EarliestCompleteTargetQuarter = NaT(numRules,1);
LatestCompleteTargetQuarter = NaT(numRules,1);
for ruleIndex = 1:numRules
    rows = modelingDataset.OriginRule == rules(ruleIndex);
    completeRows = rows & modelingDataset.InformationSetComplete;
    TotalOrigins(ruleIndex) = sum(rows);
    CompleteInformationSets(ruleIndex) = sum(completeRows);
    IncompleteInformationSets(ruleIndex) = ...
        TotalOrigins(ruleIndex)-CompleteInformationSets(ruleIndex);
    CompletePercent(ruleIndex) = ...
        100*CompleteInformationSets(ruleIndex)/TotalOrigins(ruleIndex);
    if any(completeRows)
        EarliestCompleteTargetQuarter(ruleIndex) = min( ...
            modelingDataset.TargetQuarter(completeRows));
        LatestCompleteTargetQuarter(ruleIndex) = max( ...
            modelingDataset.TargetQuarter(completeRows));
    end
end
coverage = table(OriginRule,TotalOrigins,CompleteInformationSets, ...
    IncompleteInformationSets,CompletePercent, ...
    EarliestCompleteTargetQuarter,LatestCompleteTargetQuarter);
end

function metadata = baseMetadata(panel,origins,information,modeling, ...
        comparison,coverage,sourceMode,evaluationStart)
metadata = struct( ...
    "schemaVersion","1.0", ...
    "methodologySlice","V2.1C", ...
    "sourceMode",sourceMode, ...
    "sourcePanelChecksumAlgorithm","SHA-256", ...
    "sourcePanelChecksum",macro.v2.vintagePanelChecksum(panel), ...
    "evaluationStart",string(evaluationStart,"yyyy-MM-dd"), ...
    "evaluationEnd",string(max(origins.TargetQuarter),"yyyy-MM-dd"), ...
    "originRules",{{"primary-early-quarter", ...
        "strict-quarter-start"}}, ...
    "forecastOriginCount",height(origins), ...
    "informationSetRowCount",height(information), ...
    "modelingDatasetRowCount",height(modeling), ...
    "gdpRevisionRowCount",height(comparison), ...
    "coverageRowCount",height(coverage), ...
    "targetDefinition","First-release annualized quarterly real GDP growth", ...
    "latestValueDefinition", ...
        "Maximum RealtimeStart available in the validated cache", ...
    "raggedEdgeRule", ...
        "No imputation; incomplete required observations produce NaN features");
end

function paths = outputPaths(cfg)
paths = struct( ...
    "InformationSet",fullfile(cfg.DataDir, ...
        "Forecast_Origin_Information_Set.csv"), ...
    "GDPRevisionComparison",fullfile(cfg.DataDir, ...
        "GDP_First_Release_vs_Latest.csv"), ...
    "PublicationAssumptions",fullfile(cfg.DataDir, ...
        "Publication_Delay_Assumptions.csv"), ...
    "ModelingDataset",fullfile(cfg.DataDir, ...
        "RealTime_Macro_Modeling_Dataset.csv"), ...
    "CoverageSummary",fullfile(cfg.ResultsDir, ...
        "RealTime_Data_Coverage_Summary.csv"), ...
    "Metadata",fullfile(cfg.DataDir, ...
        "RealTime_Macro_Dataset.metadata.json"));
end

function writeDeterministicTable(value,pathValue)
datetimeVariables = string(value.Properties.VariableNames( ...
    varfun(@isdatetime,value,'OutputFormat','uniform')));
for variableName = datetimeVariables
    value.(variableName).Format = "yyyy-MM-dd";
end
writetable(value,pathValue);
end

function writeMetadata(metadata,pathValue)
jsonText = jsonencode(metadata,"PrettyPrint",true);
fileID = fopen(pathValue,"w","n","UTF-8");
if fileID < 0
    error("macro:v2:buildHistoricalRealTimeDataset:MetadataWriteFailed", ...
        "Could not create real-time dataset metadata.");
end
cleanup = onCleanup(@() fclose(fileID));
count = fwrite(fileID,jsonText,"char");
if count ~= strlength(string(jsonText))
    error("macro:v2:buildHistoricalRealTimeDataset:MetadataWriteFailed", ...
        "Could not write complete real-time dataset metadata.");
end
end

function dates = monthlyDates(quarterStart)
dates = quarterStart+calmonths((0:2)');
end

function value = joinDates(dates)
if isempty(dates)
    value = "";
else
    value = join(string(dates,"yyyy-MM-dd"),"|");
end
end

function value = joinNumbers(numbers)
if isempty(numbers)
    value = "";
else
    value = join(compose("%.17g",numbers),"|");
end
end
