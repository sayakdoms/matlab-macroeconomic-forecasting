function output = runNestedModelSelection(cfg,options)
%RUNNESTEDMODELSELECTION Run leakage-controlled V2.4 model selection.

arguments
    cfg (1,1) struct = macro.v2.projectConfig()
    options.ModelingDataset table = table()
    options.InformationSet table = table()
    options.BenchmarkForecasts table = table()
    options.SaveOutputs (1,1) logical = true
end

if ~isfield(cfg,"ModelSelectionProtocol")
    error("macro:v2:runNestedModelSelection:InvalidConfiguration", ...
        "V2 configuration must contain ModelSelectionProtocol.");
end
protocol = cfg.ModelSelectionProtocol;
[modelingDataset,informationSet] = loadInputs( ...
    cfg,options.ModelingDataset,options.InformationSet);
prepared = macro.v2.prepareNestedModelingData( ...
    modelingDataset,informationSet,protocol);
[folds,outerIndices] = macro.v2.buildNestedValidationFolds( ...
    prepared,protocol);
candidates = protocol.Candidates;

numOuter = numel(outerIndices);
numCandidates = height(candidates);
scoreRows = numOuter*numCandidates;
OuterTargetQuarter = NaT(scoreRows,1);
OuterForecastOrigin = NaT(scoreRows,1);
Candidate = strings(scoreRows,1);
ModelFamily = strings(scoreRows,1);
ARLag = NaN(scoreRows,1);
RidgeLambda = NaN(scoreRows,1);
Priority = zeros(scoreRows,1);
ValidationObservations = zeros(scoreRows,1);
ValidationRMSE = Inf(scoreRows,1);
ValidationMAE = Inf(scoreRows,1);
Status = strings(scoreRows,1);
Diagnostic = strings(scoreRows,1);

SelectedModel = strings(numOuter,1);
SelectedFamily = strings(numOuter,1);
SelectedARLag = NaN(numOuter,1);
SelectedRidgeLambda = NaN(numOuter,1);
SelectedValidationRMSE = NaN(numOuter,1);
SelectedValidationMAE = NaN(numOuter,1);
OuterTrainingObservations = zeros(numOuter,1);
NestedForecast = NaN(numOuter,1);
ActualGDPGrowth = NaN(numOuter,1);
PersistenceForecast = NaN(numOuter,1);

scoreRow = 0;
for outerPosition = 1:numOuter
    outerIndex = outerIndices(outerPosition);
    outerFolds = folds(folds.OuterIndex == outerIndex,:);
    outerScores = table();
    for candidateIndex = 1:numCandidates
        candidate = candidates(candidateIndex,:);
        validationForecasts = NaN(height(outerFolds),1);
        validationActuals = NaN(height(outerFolds),1);
        foldStatus = strings(height(outerFolds),1);
        foldDiagnostics = strings(height(outerFolds),1);
        for foldIndex = 1:height(outerFolds)
            trainingRows = (outerFolds.TrainingStartIndex(foldIndex): ...
                outerFolds.TrainingEndIndex(foldIndex))';
            validationIndex = outerFolds.ValidationIndex(foldIndex);
            fitted = macro.v2.forecastCandidate( ...
                prepared,trainingRows,validationIndex,candidate);
            validationForecasts(foldIndex) = fitted.Forecast;
            validationActuals(foldIndex) = prepared.Y(validationIndex);
            foldStatus(foldIndex) = fitted.Status;
            foldDiagnostics(foldIndex) = fitted.Diagnostic;
        end
        scoreRow = scoreRow+1;
        OuterTargetQuarter(scoreRow) = ...
            prepared.Data.TargetQuarter(outerIndex);
        OuterForecastOrigin(scoreRow) = ...
            prepared.Data.ForecastOrigin(outerIndex);
        Candidate(scoreRow) = candidate.Candidate;
        ModelFamily(scoreRow) = candidate.ModelFamily;
        ARLag(scoreRow) = candidate.ARLag;
        RidgeLambda(scoreRow) = candidate.RidgeLambda;
        Priority(scoreRow) = candidate.Priority;
        ValidationObservations(scoreRow) = sum(foldStatus == "valid");
        if all(foldStatus == "valid")
            errors = validationActuals-validationForecasts;
            ValidationRMSE(scoreRow) = sqrt(mean(errors.^2));
            ValidationMAE(scoreRow) = mean(abs(errors));
            Status(scoreRow) = "valid";
            Diagnostic(scoreRow) = "";
        else
            Status(scoreRow) = "invalid-inner-fold";
            Diagnostic(scoreRow) = join(unique( ...
                foldDiagnostics(foldStatus ~= "valid"))," | ");
        end
        currentScore = table(OuterTargetQuarter(scoreRow), ...
            OuterForecastOrigin(scoreRow),Candidate(scoreRow), ...
            ModelFamily(scoreRow),ARLag(scoreRow),RidgeLambda(scoreRow), ...
            Priority(scoreRow),ValidationObservations(scoreRow), ...
            ValidationRMSE(scoreRow),ValidationMAE(scoreRow), ...
            Status(scoreRow),Diagnostic(scoreRow),VariableNames={ ...
            'OuterTargetQuarter','OuterForecastOrigin','Candidate', ...
            'ModelFamily','ARLag','RidgeLambda','Priority', ...
            'ValidationObservations','ValidationRMSE','ValidationMAE', ...
            'Status','Diagnostic'});
        outerScores = [outerScores;currentScore]; %#ok<AGROW>
    end

    selected = macro.v2.selectBestCandidate(outerScores,protocol);
    selectedProtocolRow = candidates( ...
        candidates.Candidate == selected.Candidate,:);
    finalFit = macro.v2.forecastCandidate(prepared, ...
        (1:outerIndex-1)',outerIndex,selectedProtocolRow);
    if finalFit.Status ~= "valid"
        error("macro:v2:runNestedModelSelection:SelectedModelFailed", ...
            "Selected model failed at outer target %s: %s", ...
            string(prepared.Data.TargetQuarter(outerIndex)), ...
            finalFit.Diagnostic);
    end
    SelectedModel(outerPosition) = selected.Candidate;
    SelectedFamily(outerPosition) = selected.ModelFamily;
    SelectedARLag(outerPosition) = selected.ARLag;
    SelectedRidgeLambda(outerPosition) = selected.RidgeLambda;
    SelectedValidationRMSE(outerPosition) = selected.ValidationRMSE;
    SelectedValidationMAE(outerPosition) = selected.ValidationMAE;
    OuterTrainingObservations(outerPosition) = outerIndex-1;
    NestedForecast(outerPosition) = finalFit.Forecast;
    ActualGDPGrowth(outerPosition) = prepared.Y(outerIndex);
    PersistenceForecast(outerPosition) = prepared.Persistence(outerIndex);
end

scores = table(OuterTargetQuarter,OuterForecastOrigin,Candidate, ...
    ModelFamily,ARLag,RidgeLambda,Priority,ValidationObservations, ...
    ValidationRMSE,ValidationMAE,Status,Diagnostic);
selectedModels = table( ...
    prepared.Data.TargetQuarter(outerIndices), ...
    prepared.Data.ForecastOrigin(outerIndices),SelectedModel, ...
    SelectedFamily,SelectedARLag,SelectedRidgeLambda, ...
    SelectedValidationRMSE,SelectedValidationMAE, ...
    OuterTrainingObservations, ...
    prepared.MaximumPredictorAvailabilityDate(outerIndices), ...
    VariableNames={'TargetQuarter','ForecastOrigin','SelectedModel', ...
    'SelectedFamily','SelectedARLag','SelectedRidgeLambda', ...
    'InnerValidationRMSE','InnerValidationMAE', ...
    'OuterTrainingObservations','LatestPredictorAvailabilityDate'});

benchmarks = loadBenchmarks(cfg,options.BenchmarkForecasts);
forecasts = buildForecastRows(selectedModels,ActualGDPGrowth, ...
    NestedForecast,PersistenceForecast,benchmarks);
performance = performanceTable(forecasts);
stability = stabilityTable(selectedModels);

paths = outputPaths(cfg);
figureFiles = strings(0,1);
if options.SaveOutputs
    macro.v2.ensureOutputDirectories(cfg);
    writeDeterministicTable(folds,paths.Folds);
    writeDeterministicTable(scores,paths.Scores);
    writeDeterministicTable(selectedModels,paths.SelectedModels);
    writeDeterministicTable(forecasts,paths.Forecasts);
    writeDeterministicTable(stability,paths.Stability);
    writeDeterministicTable(performance,paths.Performance);
    if cfg.GenerateFigures
        figureFiles = createFigures(cfg,selectedModels,forecasts,scores);
    end
end

output = struct( ...
    "PreparedData",prepared, ...
    "ValidationFolds",folds, ...
    "CandidateScores",scores, ...
    "SelectedModels",selectedModels, ...
    "Forecasts",forecasts, ...
    "Performance",performance, ...
    "SelectionStability",stability, ...
    "Protocol",protocol, ...
    "ResultFiles",string(struct2cell(paths)), ...
    "FigureFiles",figureFiles);
end

function [modeling,information] = loadInputs(cfg,modeling,information)
if isempty(modeling)
    pathValue = fullfile(cfg.DataDir,"RealTime_Macro_Modeling_Dataset.csv");
    if ~isfile(pathValue)
        error("macro:v2:runNestedModelSelection:MissingRealTimeDataset", ...
            "Build the V2.1C historical real-time dataset before running " + ...
            "nested selection, or supply ModelingDataset explicitly.");
    end
    modeling = readtable(pathValue,TextType="string");
end
if isempty(information)
    pathValue = fullfile(cfg.DataDir,"Forecast_Origin_Information_Set.csv");
    if ~isfile(pathValue)
        error("macro:v2:runNestedModelSelection:MissingInformationSet", ...
            "The V2.1C forecast-origin information set is required.");
    end
    information = readtable(pathValue,TextType="string");
end
modeling = normalizeDates(modeling,["TargetQuarter","ForecastOrigin", ...
    "TargetFirstReleaseDate"]);
information = normalizeDates(information,["TargetQuarter", ...
    "ForecastOrigin","LatestSelectedVintageStart"]);
end

function value = normalizeDates(value,names)
for name = names
    if ismember(name,string(value.Properties.VariableNames)) && ...
            ~isdatetime(value.(name))
        value.(name) = datetime(string(value.(name)), ...
            InputFormat="yyyy-MM-dd");
    end
end
end

function benchmarks = loadBenchmarks(cfg,benchmarks)
if ~isempty(benchmarks)
    return;
end
pathValue = fullfile(cfg.V1ResultsDir,"Expanding_Window_Forecasts.csv");
if ~isfile(pathValue)
    benchmarks = table();
    return;
end
benchmarks = readtable(pathValue,TextType="string");
if ~isdatetime(benchmarks.Date)
    benchmarks.Date = datetime(string(benchmarks.Date), ...
        InputFormat="yyyy-MM-dd");
end
end

function forecasts = buildForecastRows(selected,actual,nested,persistence,benchmarks)
n = height(selected);
TargetQuarter = repelem(selected.TargetQuarter,4);
ForecastOrigin = repelem(selected.ForecastOrigin,4);
ForecastModel = repmat(["Nested selected";"Persistence"; ...
    "V1 fixed historical OLS";"V1 expanding OLS"],n,1);
ModelRole = repmat(["V2 adaptive selection";"V2 benchmark"; ...
    "V1 revised-data baseline";"V1 revised-data baseline"],n,1);
ActualGDPGrowth = repelem(actual,4);
Forecast = NaN(4*n,1);
SelectedCandidate = strings(4*n,1);
for index = 1:n
    rows = (4*index-3):(4*index);
    Forecast(rows(1)) = nested(index);
    Forecast(rows(2)) = persistence(index);
    SelectedCandidate(rows(1)) = selected.SelectedModel(index);
    if ~isempty(benchmarks)
        benchmarkRow = find(benchmarks.Date == selected.TargetQuarter(index),1);
        if ~isempty(benchmarkRow)
            Forecast(rows(3)) = benchmarks.FixedForecast(benchmarkRow);
            Forecast(rows(4)) = benchmarks.ExpandingForecast(benchmarkRow);
        end
    end
end
ForecastError = ActualGDPGrowth-Forecast;
TargetConvention = repmat( ...
    "V2 first-release GDP growth",4*n,1);
forecasts = table(TargetQuarter,ForecastOrigin,ForecastModel,ModelRole, ...
    SelectedCandidate,TargetConvention,ActualGDPGrowth,Forecast,ForecastError);
end

function performance = performanceTable(forecasts)
models = unique(forecasts.ForecastModel,"stable");
ForecastModel = models;
Observations = zeros(numel(models),1);
RMSE = NaN(numel(models),1);
MAE = NaN(numel(models),1);
for index = 1:numel(models)
    rows = forecasts.ForecastModel == models(index) & ...
        isfinite(forecasts.Forecast);
    Observations(index) = sum(rows);
    if any(rows)
        errors = forecasts.ForecastError(rows);
        RMSE(index) = sqrt(mean(errors.^2));
        MAE(index) = mean(abs(errors));
    end
end
persistenceIndex = find(models == "Persistence",1);
RMSEImprovementVsPersistence = 100*(RMSE(persistenceIndex)-RMSE)./ ...
    RMSE(persistenceIndex);
MAEImprovementVsPersistence = 100*(MAE(persistenceIndex)-MAE)./ ...
    MAE(persistenceIndex);
performance = table(ForecastModel,Observations,RMSE,MAE, ...
    RMSEImprovementVsPersistence,MAEImprovementVsPersistence);
end

function stability = stabilityTable(selected)
models = unique(selected.SelectedModel,"stable");
SelectedModel = models;
Selections = zeros(numel(models),1);
SelectionPercent = zeros(numel(models),1);
SelectedRidgePenalties = strings(numel(models),1);
for index = 1:numel(models)
    rows = selected.SelectedModel == models(index);
    Selections(index) = sum(rows);
    SelectionPercent(index) = 100*Selections(index)/height(selected);
    penalties = unique(selected.SelectedRidgeLambda(rows & ...
        isfinite(selected.SelectedRidgeLambda)));
    if ~isempty(penalties)
        SelectedRidgePenalties(index) = join(string(penalties),"|");
    end
end
stability = table(SelectedModel,Selections,SelectionPercent, ...
    SelectedRidgePenalties);
end

function paths = outputPaths(cfg)
paths = struct( ...
    "Folds",fullfile(cfg.ResultsDir,"Time_Series_Validation_Folds.csv"), ...
    "Scores",fullfile(cfg.ResultsDir, ...
        "Candidate_Model_Validation_Scores.csv"), ...
    "SelectedModels",fullfile(cfg.ResultsDir, ...
        "Selected_Model_By_Forecast_Origin.csv"), ...
    "Forecasts",fullfile(cfg.ResultsDir,"Nested_OOS_Forecasts.csv"), ...
    "Stability",fullfile(cfg.ResultsDir,"Model_Selection_Stability.csv"), ...
    "Performance",fullfile(cfg.ResultsDir,"Nested_Forecast_Performance.csv"));
end

function writeDeterministicTable(value,pathValue)
datetimeVariables = string(value.Properties.VariableNames( ...
    varfun(@isdatetime,value,OutputFormat="uniform")));
for variable = datetimeVariables
    value.(variable).Format = "yyyy-MM-dd";
end
writetable(value,pathValue);
end

function files = createFigures(cfg,selected,forecasts,scores)
fig1 = figure(Visible="off",Position=[100 100 1000 550]);
[modelNames,~,modelGroups] = unique(selected.SelectedModel,"stable");
counts = accumarray(modelGroups,1);
bar(counts);
set(gca,"XTick",1:numel(modelNames),"XTickLabel",modelNames);
xtickangle(30);
ylabel("Outer forecast origins");
title("V2 Nested Model-Selection Frequency");
grid on;
frequencyPath = fullfile(cfg.FiguresDir, ...
    "V2_Nested_Model_Selection_Frequency.png");
exportgraphics(fig1,frequencyPath,Resolution=200);
close(fig1);

fig2 = figure(Visible="off",Position=[100 100 1200 600]);
actualRows = forecasts.ForecastModel == "Nested selected";
plot(forecasts.TargetQuarter(actualRows), ...
    forecasts.ActualGDPGrowth(actualRows),LineWidth=1.6);
hold on;
plot(forecasts.TargetQuarter(actualRows), ...
    forecasts.Forecast(actualRows),"--",LineWidth=1.5);
persistenceRows = forecasts.ForecastModel == "Persistence";
plot(forecasts.TargetQuarter(persistenceRows), ...
    forecasts.Forecast(persistenceRows),":",LineWidth=1.4);
title("V2 Nested Out-of-Sample Forecasts");
legend("First-release actual","Nested selected","Persistence", ...
    Location="best");
grid on;
forecastPath = fullfile(cfg.FiguresDir,"V2_Nested_OOS_Forecasts.png");
exportgraphics(fig2,forecastPath,Resolution=200);
close(fig2);

fig3 = figure(Visible="off",Position=[100 100 1200 600]);
valid = scores.Status == "valid";
boxchart(categorical(scores.Candidate(valid)),scores.ValidationRMSE(valid));
xtickangle(30);
ylabel("Inner-validation RMSE");
title("V2 Candidate Inner-Validation Scores");
grid on;
scorePath = fullfile(cfg.FiguresDir,"V2_Inner_Validation_RMSE.png");
exportgraphics(fig3,scorePath,Resolution=200);
close(fig3);
files = [frequencyPath;forecastPath;scorePath];
end
