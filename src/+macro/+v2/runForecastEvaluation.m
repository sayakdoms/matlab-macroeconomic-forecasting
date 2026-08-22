function output = runForecastEvaluation(cfg,options)
%RUNFORECASTEVALUATION Run finalized V2.5 forecast evaluation and tests.

arguments
    cfg (1,1) struct = macro.v2.projectConfig()
    options.Forecasts table = table()
    options.TrainingScales table = table()
    options.ModelingDataset table = table()
    options.InformationSet table = table()
    options.SaveOutputs (1,1) logical = true
end

if ~isfield(cfg,"ForecastEvaluationProtocol")
    error("macro:v2:runForecastEvaluation:InvalidConfiguration", ...
        "V2 configuration must contain ForecastEvaluationProtocol.");
end
protocol = cfg.ForecastEvaluationProtocol;
forecasts = loadForecasts(cfg,options.Forecasts);
modelNames = ["Nested selected";"Persistence"; ...
    "V1 fixed historical OLS";"V1 expanding OLS"];
modelTables = cell(numel(modelNames),1);
for modelIndex = 1:numel(modelNames)
    rows = forecasts.ForecastModel == modelNames(modelIndex);
    if ~any(rows)
        error("macro:v2:runForecastEvaluation:MissingModel", ...
            "Forecast input is missing required model %s.",modelNames(modelIndex));
    end
    modelTables{modelIndex} = sortrows(forecasts(rows, ...
        ["TargetQuarter","ActualGDPGrowth","Forecast"]),"TargetQuarter");
end
for modelIndex = 2:numel(modelNames)
    macro.v2.validateForecastPair(modelTables{modelIndex},modelTables{1});
end
dates = modelTables{1}.TargetQuarter;
n = numel(dates);
if n < protocol.SmallSampleWarningThreshold
    warning("macro:v2:runForecastEvaluation:VerySmallSample", ...
        "V2.5 has only %d genuine outer forecasts. Formal tests have low " + ...
        "power; non-rejection must not be interpreted as equivalence.",n);
end
trainingScale = resolveTrainingScales(cfg,dates,options.TrainingScales, ...
    options.ModelingDataset,options.InformationSet);

leaderboard = buildLeaderboard( ...
    modelNames,modelTables,trainingScale,protocol);
windowLoss = buildWindowLoss( ...
    modelNames,modelTables,trainingScale,protocol);
formalTests = runFormalTests( ...
    modelNames,modelTables,protocol);
confidenceIntervals = buildConfidenceIntervals( ...
    modelNames,modelTables,trainingScale,protocol);

paths = outputPaths(cfg);
figureFiles = strings(0,1);
if options.SaveOutputs
    macro.v2.ensureOutputDirectories(cfg);
    writeDeterministicTable(leaderboard,paths.Leaderboard);
    writeDeterministicTable(windowLoss,paths.WindowLoss);
    writeDeterministicTable(formalTests,paths.FormalTests);
    writeDeterministicTable(confidenceIntervals,paths.ConfidenceIntervals);
    if cfg.GenerateFigures
        figureFiles = createFigures(cfg,modelNames,modelTables,protocol);
    end
end

output = struct( ...
    "Leaderboard",leaderboard, ...
    "LossByWindow",windowLoss, ...
    "FormalTests",formalTests, ...
    "ConfidenceIntervals",confidenceIntervals, ...
    "TrainingScales",table(dates,trainingScale,VariableNames={ ...
        'TargetQuarter','TrainingNaiveScale'}), ...
    "Protocol",protocol, ...
    "ResultFiles",string(struct2cell(paths)), ...
    "FigureFiles",figureFiles);
end

function forecasts = loadForecasts(cfg,forecasts)
if isempty(forecasts)
    pathValue = fullfile(cfg.ResultsDir,"Nested_OOS_Forecasts.csv");
    if ~isfile(pathValue)
        error("macro:v2:runForecastEvaluation:MissingForecasts", ...
            "Finalized V2.4 forecasts are required before V2.5 evaluation.");
    end
    forecasts = readtable(pathValue,TextType="string");
end
required = ["TargetQuarter","ForecastModel", ...
    "ActualGDPGrowth","Forecast"];
macro.requireTableVariables(forecasts,required,DataName="V2.4 forecasts");
forecasts.ForecastModel = string(forecasts.ForecastModel);
if ~isdatetime(forecasts.TargetQuarter)
    forecasts.TargetQuarter = datetime(string(forecasts.TargetQuarter), ...
        InputFormat="yyyy-MM-dd");
end
if any(isnat(forecasts.TargetQuarter)) || ...
        ~isnumeric(forecasts.ActualGDPGrowth) || ...
        ~isnumeric(forecasts.Forecast) || ...
        any(~isfinite(forecasts.ActualGDPGrowth)) || ...
        any(~isfinite(forecasts.Forecast))
    error("macro:v2:runForecastEvaluation:InvalidForecasts", ...
        "Forecast dates, actuals, and predictions must be valid and finite.");
end
end

function scale = resolveTrainingScales(cfg,dates,supplied,modeling,information)
if ~isempty(supplied)
    macro.requireTableVariables(supplied, ...
        ["TargetQuarter","TrainingNaiveScale"], ...
        DataName="training-only MASE scales");
    if ~isdatetime(supplied.TargetQuarter)
        supplied.TargetQuarter = datetime(string(supplied.TargetQuarter), ...
            InputFormat="yyyy-MM-dd");
    end
    [present,location] = ismember(dates,supplied.TargetQuarter);
    if ~all(present)
        error("macro:v2:runForecastEvaluation:MissingTrainingScale", ...
            "Every forecast origin must have a training-only MASE scale.");
    end
    scale = supplied.TrainingNaiveScale(location);
else
    [modeling,information] = loadRealTimeInputs(cfg,modeling,information);
    modeling = modeling(modeling.TargetQuarter <= max(dates),:);
    information = information(information.TargetQuarter <= max(dates),:);
    prepared = macro.v2.prepareNestedModelingData( ...
        modeling,information,cfg.ModelSelectionProtocol);
    scale = NaN(numel(dates),1);
    for dateIndex = 1:numel(dates)
        preparedIndex = find(prepared.Data.TargetQuarter == dates(dateIndex),1);
        if isempty(preparedIndex) || preparedIndex < 2
            error("macro:v2:runForecastEvaluation:MissingTrainingHistory", ...
                "Training history is unavailable for forecast target %s.", ...
                string(dates(dateIndex)));
        end
        trainingTargets = prepared.Y(1:preparedIndex-1);
        scale(dateIndex) = mean(abs(diff(trainingTargets)));
    end
end
if ~isnumeric(scale) || any(~isfinite(scale)) || any(scale <= 0)
    error("macro:v2:runForecastEvaluation:InvalidTrainingScale", ...
        "Training-only MASE scales must be finite and strictly positive.");
end
scale = scale(:);
end

function [modeling,information] = loadRealTimeInputs(cfg,modeling,information)
if isempty(modeling)
    modeling = readtable(fullfile(cfg.DataDir, ...
        "RealTime_Macro_Modeling_Dataset.csv"),TextType="string");
end
if isempty(information)
    information = readtable(fullfile(cfg.DataDir, ...
        "Forecast_Origin_Information_Set.csv"),TextType="string");
end
for name = ["TargetQuarter","ForecastOrigin","TargetFirstReleaseDate"]
    if ismember(name,string(modeling.Properties.VariableNames)) && ...
            ~isdatetime(modeling.(name))
        modeling.(name) = datetime(string(modeling.(name)), ...
            InputFormat="yyyy-MM-dd");
    end
end
for name = ["TargetQuarter","ForecastOrigin", ...
        "LatestSelectedVintageStart"]
    if ismember(name,string(information.Properties.VariableNames)) && ...
            ~isdatetime(information.(name))
        information.(name) = datetime(string(information.(name)), ...
            InputFormat="yyyy-MM-dd");
    end
end
end

function leaderboard = buildLeaderboard(names,tables,scale,protocol)
numModels = numel(names);
ForecastModel = names;
Observations = zeros(numModels,1);
ForecastStart = NaT(numModels,1);
ForecastEnd = NaT(numModels,1);
MeanError = NaN(numModels,1);
RMSE = NaN(numModels,1);
MAE = NaN(numModels,1);
MedianAbsoluteError = NaN(numModels,1);
MASE = NaN(numModels,1);
HuberLoss = NaN(numModels,1);
Correlation = NaN(numModels,1);
SignAccuracyPercent = NaN(numModels,1);
SignAccuracyMeaningful = false(numModels,1);
TrainingScaleMinimum = NaN(numModels,1);
TrainingScaleMaximum = NaN(numModels,1);
SmallSampleWarning = false(numModels,1);
for index = 1:numModels
    value = tables{index};
    metric = macro.v2.forecastEvaluationMetrics( ...
        value.ActualGDPGrowth,value.Forecast,scale, ...
        HuberDelta=protocol.HuberDelta);
    Observations(index) = metric.Observations;
    ForecastStart(index) = value.TargetQuarter(1);
    ForecastEnd(index) = value.TargetQuarter(end);
    MeanError(index) = metric.MeanError;
    RMSE(index) = metric.RMSE;
    MAE(index) = metric.MAE;
    MedianAbsoluteError(index) = metric.MedianAbsoluteError;
    MASE(index) = metric.MASE;
    HuberLoss(index) = metric.HuberLoss;
    Correlation(index) = metric.Correlation;
    SignAccuracyPercent(index) = metric.SignAccuracyPercent;
    SignAccuracyMeaningful(index) = metric.SignAccuracyMeaningful;
    TrainingScaleMinimum(index) = metric.TrainingScaleMinimum;
    TrainingScaleMaximum(index) = metric.TrainingScaleMaximum;
    SmallSampleWarning(index) = ...
        metric.Observations < protocol.SmallSampleWarningThreshold;
end
leaderboard = table(ForecastModel,Observations,ForecastStart,ForecastEnd, ...
    MeanError,RMSE,MAE,MedianAbsoluteError,MASE,HuberLoss,Correlation, ...
    SignAccuracyPercent,SignAccuracyMeaningful, ...
    TrainingScaleMinimum,TrainingScaleMaximum, ...
    SmallSampleWarning);
end

function windowLoss = buildWindowLoss(names,tables,scale,protocol)
windows = protocol.Windows;
rows = numel(names)*height(windows);
Window = strings(rows,1);
ForecastModel = strings(rows,1);
DeclaredStart = NaT(rows,1);
DeclaredEnd = NaT(rows,1);
Observations = zeros(rows,1);
Status = strings(rows,1);
MeanError = NaN(rows,1); RMSE = NaN(rows,1); MAE = NaN(rows,1);
MedianAbsoluteError = NaN(rows,1); MASE = NaN(rows,1);
HuberLoss = NaN(rows,1); Correlation = NaN(rows,1);
SignAccuracyPercent = NaN(rows,1);
SignAccuracyMeaningful = false(rows,1);
row = 0;
for windowIndex = 1:height(windows)
    for modelIndex = 1:numel(names)
        row = row+1;
        value = tables{modelIndex};
        selected = true(height(value),1);
        if ~isnat(windows.StartQuarter(windowIndex))
            selected = selected & value.TargetQuarter >= ...
                windows.StartQuarter(windowIndex);
        end
        if ~isnat(windows.EndQuarter(windowIndex))
            selected = selected & value.TargetQuarter <= ...
                windows.EndQuarter(windowIndex);
        end
        Window(row) = windows.Window(windowIndex);
        ForecastModel(row) = names(modelIndex);
        DeclaredStart(row) = windows.StartQuarter(windowIndex);
        DeclaredEnd(row) = windows.EndQuarter(windowIndex);
        Observations(row) = sum(selected);
        completeDeclaredWindow = true;
        if windows.RequireCompleteDeclaredWindow(windowIndex)
            completeDeclaredWindow = any(selected) && ...
                min(value.TargetQuarter(selected)) <= ...
                    windows.StartQuarter(windowIndex) && ...
                max(value.TargetQuarter(selected)) >= ...
                    windows.EndQuarter(windowIndex);
        end
        if ~completeDeclaredWindow
            Status(row) = "unavailable-incomplete-declared-window";
        elseif Observations(row) < windows.MinimumObservations(windowIndex)
            Status(row) = "unavailable-insufficient-observations";
        else
            Status(row) = "reported";
            metric = macro.v2.forecastEvaluationMetrics( ...
                value.ActualGDPGrowth(selected),value.Forecast(selected), ...
                scale(selected),HuberDelta=protocol.HuberDelta);
            MeanError(row) = metric.MeanError;
            RMSE(row) = metric.RMSE;
            MAE(row) = metric.MAE;
            MedianAbsoluteError(row) = metric.MedianAbsoluteError;
            MASE(row) = metric.MASE;
            HuberLoss(row) = metric.HuberLoss;
            Correlation(row) = metric.Correlation;
            SignAccuracyPercent(row) = metric.SignAccuracyPercent;
            SignAccuracyMeaningful(row) = metric.SignAccuracyMeaningful;
        end
    end
end
windowLoss = table(Window,ForecastModel,DeclaredStart,DeclaredEnd, ...
    Observations,Status,MeanError,RMSE,MAE,MedianAbsoluteError,MASE, ...
    HuberLoss,Correlation,SignAccuracyPercent,SignAccuracyMeaningful);
end

function tests = runFormalTests(names,tables,protocol)
comparisons = protocol.Comparisons;
n = height(comparisons);
TestFamily = comparisons.TestFamily;
Model = comparisons.Model;
Benchmark = comparisons.Benchmark;
Loss = comparisons.Loss;
Alternative = comparisons.Alternative;
Observations = zeros(n,1); ForecastStart = NaT(n,1); ForecastEnd = NaT(n,1);
HACBandwidth = zeros(n,1); MeanLossDifferential = NaN(n,1);
EconomicLossImprovementPercent = NaN(n,1); DMStatistic = NaN(n,1);
HLNCorrectionFactor = NaN(n,1); Statistic = NaN(n,1);
RawPValue = NaN(n,1); Status = strings(n,1);
SmallSampleWarning = false(n,1);
for index = 1:n
    modelIndex = find(names == Model(index),1);
    benchmarkIndex = find(names == Benchmark(index),1);
    if TestFamily(index) == "DM-HLN"
        result = macro.v2.dieboldMarianoTest( ...
            tables{modelIndex},tables{benchmarkIndex}, ...
            Loss="squared",Horizon=protocol.ForecastHorizon, ...
            SmallSampleThreshold=protocol.SmallSampleWarningThreshold);
    else
        result = macro.v2.clarkWestTest( ...
            tables{modelIndex},tables{benchmarkIndex}, ...
            SmallSampleThreshold=protocol.SmallSampleWarningThreshold);
    end
    Observations(index) = result.Observations;
    ForecastStart(index) = result.ForecastStart;
    ForecastEnd(index) = result.ForecastEnd;
    HACBandwidth(index) = result.HACBandwidth;
    MeanLossDifferential(index) = result.MeanLossDifferential;
    modelErrors = tables{modelIndex}.ActualGDPGrowth- ...
        tables{modelIndex}.Forecast;
    benchmarkErrors = tables{benchmarkIndex}.ActualGDPGrowth- ...
        tables{benchmarkIndex}.Forecast;
    EconomicLossImprovementPercent(index) = 100*( ...
        mean(benchmarkErrors.^2)-mean(modelErrors.^2))/ ...
        mean(benchmarkErrors.^2);
    DMStatistic(index) = result.DMStatistic;
    HLNCorrectionFactor(index) = result.HLNCorrectionFactor;
    Statistic(index) = result.Statistic;
    RawPValue(index) = result.PValue;
    Status(index) = result.Status;
    SmallSampleWarning(index) = result.SmallSampleWarning;
end
HolmAdjustedPValue = macro.v2.holmAdjust(RawPValue);
RejectRaw = RawPValue < protocol.Alpha;
RejectHolm = HolmAdjustedPValue < protocol.Alpha;
Interpretation = strings(n,1);
ApplicabilityCaveat = strings(n,1);
for index = 1:n
    if TestFamily(index) == "Clark-West"
        ApplicabilityCaveat(index) = ...
            "V1 macro OLS is structurally larger than persistence, but its " + ...
            "revised-data estimation differs from the V2 first-release target convention";
        if RejectHolm(index) && EconomicLossImprovementPercent(index) > 0
            Interpretation(index) = ...
                "Clark-West rejects after Holm; the larger model also has lower observed MSE";
        elseif RejectHolm(index)
            Interpretation(index) = ...
                "Clark-West rejects after Holm, but the larger model has higher observed MSE; this is not an economic-loss gain";
        else
            Interpretation(index) = ...
                "Clark-West does not reject; this is not evidence of forecast equivalence";
        end
    elseif RejectHolm(index) && MeanLossDifferential(index) > 0
        Interpretation(index) = ...
            "Statistically lower loss after Holm adjustment; assess magnitude separately";
    elseif RejectHolm(index)
        Interpretation(index) = ...
            "Statistically higher loss after Holm adjustment";
    else
        Interpretation(index) = ...
            "Not rejected; this is not evidence of forecast equivalence";
    end
end
tests = table(TestFamily,Model,Benchmark,Loss,Alternative,Observations, ...
    ForecastStart,ForecastEnd,HACBandwidth,MeanLossDifferential, ...
    EconomicLossImprovementPercent,DMStatistic,HLNCorrectionFactor, ...
    Statistic,RawPValue,HolmAdjustedPValue,RejectRaw,RejectHolm, ...
    Status,SmallSampleWarning,Interpretation,ApplicabilityCaveat);
end

function intervals = buildConfidenceIntervals(names,tables,scale,protocol)
intervals = table();
for index = 1:numel(names)
    value = tables{index};
    current = macro.v2.blockBootstrapMetricCI( ...
        value.ActualGDPGrowth,value.Forecast,scale, ...
        Replications=protocol.BootstrapReplications, ...
        BlockLength=protocol.BootstrapBlockLength, ...
        Seed=protocol.BootstrapSeed, ...
        ConfidenceLevel=protocol.BootstrapConfidenceLevel, ...
        HuberDelta=protocol.HuberDelta);
    current = addvars(current,repmat(names(index),height(current),1), ...
        repmat(value.TargetQuarter(1),height(current),1), ...
        repmat(value.TargetQuarter(end),height(current),1), ...
        'Before','Metric','NewVariableNames', ...
        {'ForecastModel','ForecastStart','ForecastEnd'});
    intervals = [intervals;current]; %#ok<AGROW>
end
end

function paths = outputPaths(cfg)
paths = struct( ...
    "Leaderboard",fullfile(cfg.ResultsDir,"Forecast_Leaderboard_V2.csv"), ...
    "WindowLoss",fullfile(cfg.ResultsDir,"Forecast_Loss_By_Window.csv"), ...
    "FormalTests",fullfile(cfg.ResultsDir, ...
        "Formal_Model_Comparison_Tests.csv"), ...
    "ConfidenceIntervals",fullfile(cfg.ResultsDir, ...
        "Forecast_Metric_Confidence_Intervals.csv"));
end

function writeDeterministicTable(value,pathValue)
datetimeVariables = string(value.Properties.VariableNames( ...
    varfun(@isdatetime,value,OutputFormat="uniform")));
for variable = datetimeVariables
    value.(variable).Format = "yyyy-MM-dd";
end
writetable(value,pathValue);
end

function files = createFigures(cfg,names,tables,~)
dates = tables{1}.TargetQuarter;
fig1 = figure(Visible="off",Position=[100 100 1100 600]);
hold on;
for index = 1:numel(names)
    errors = tables{index}.ActualGDPGrowth-tables{index}.Forecast;
    plot(dates,cumsum(errors.^2),LineWidth=1.5);
end
grid on;
title("V2 Cumulative Squared Forecast Loss");
ylabel("Cumulative squared error");
legend(names,Location="best");
cumulativePath = fullfile(cfg.FiguresDir, ...
    "V2_Cumulative_Forecast_Loss.png");
exportgraphics(fig1,cumulativePath,Resolution=200);
close(fig1);

window = min(8,numel(dates));
fig2 = figure(Visible="off",Position=[100 100 1100 600]);
hold on;
for index = 1:numel(names)
    errors = tables{index}.ActualGDPGrowth-tables{index}.Forecast;
    rolling = NaN(numel(errors),1);
    for row = window:numel(errors)
        rolling(row) = sqrt(mean(errors(row-window+1:row).^2));
    end
    plot(dates,rolling,LineWidth=1.5);
end
grid on;
title(sprintf("V2 Rolling %d-Quarter RMSE",window));
ylabel("RMSE");
legend(names,Location="best");
rollingPath = fullfile(cfg.FiguresDir,"V2_Rolling_Forecast_RMSE.png");
exportgraphics(fig2,rollingPath,Resolution=200);
close(fig2);
files = [cumulativePath;rollingPath];
end
