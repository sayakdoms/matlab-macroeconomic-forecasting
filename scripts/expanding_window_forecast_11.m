function output = expanding_window_forecast_11(cfg)
%EXPANDING_WINDOW_FORECAST_11 Phase 11 - Recursive forecasting comparison.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 11 - Expanding Window Forecasting
%
% Objective:
% Re-estimate the forecasting model every quarter using
% all information available up to that point.
%
% Compare:
% 1. Fixed historical model
% 2. Expanding-window adaptive model
% 3. Naive persistence benchmark

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 11: Expanding Window Forecasting");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Quarterly dataset loaded successfully.");

%% ---------------------------------------------------------
% Build forecast-ready lagged dataset
% ----------------------------------------------------------

design = macro.buildForecastDesign(DATA);
Y = design.Y;
forecastDates = design.Dates;
X = design.X;

%% ---------------------------------------------------------
% Define out-of-sample test period
% ----------------------------------------------------------

splitDate = datetime(2016,1,1);

trainInitial = forecastDates < splitDate;
testIndex = forecastDates >= splitDate;

testRows = find(testIndex);

Y_test = Y(testIndex);
datesTest = forecastDates(testIndex);

numForecasts = length(Y_test);

fprintf("\nInitial training observations: %d\n",sum(trainInitial));
fprintf("Out-of-sample forecasts: %d\n",numForecasts);

%% ---------------------------------------------------------
% FIXED MODEL
% Estimate once using data before 2016
% ----------------------------------------------------------

X_initial = X(trainInitial,:);
Y_initial = Y(trainInitial);

FIXED_MODEL = macro.estimateOLS(X_initial,Y_initial, ...
    CovarianceSolver="inverse");
betaFixed = FIXED_MODEL.Coefficients;

FixedForecast = X(testIndex,:) * betaFixed;

%% ---------------------------------------------------------
% EXPANDING WINDOW MODEL
% Re-estimate model before every forecast
% ----------------------------------------------------------

ExpandingForecast = zeros(numForecasts,1);

CoefficientHistory = zeros( ...
    numForecasts, ...
    size(X,2));

TrainingSize = zeros(numForecasts,1);

for i = 1:numForecasts

    currentRow = testRows(i);

    % Use all observations strictly before forecast quarter
    trainingRows = 1:(currentRow-1);

    X_train = X(trainingRows,:);
    Y_train = Y(trainingRows);

    % Re-estimate coefficients
    adaptiveModel = macro.estimateOLS(X_train,Y_train, ...
        CovarianceSolver="inverse");
    betaAdaptive = adaptiveModel.Coefficients;

    % Generate one-step-ahead prediction
    ExpandingForecast(i) = ...
        X(currentRow,:) * betaAdaptive;

    % Save coefficient history
    CoefficientHistory(i,:) = betaAdaptive';

    TrainingSize(i) = length(Y_train);

end

%% ---------------------------------------------------------
% NAIVE BENCHMARK
% Previous quarter's GDP growth
% ----------------------------------------------------------

NaiveForecast = X(testIndex,2);

%% ---------------------------------------------------------
% Forecast errors
% ----------------------------------------------------------

FIXED_METRICS = macro.forecastMetrics( ...
    Y_test,FixedForecast,NaiveForecast);
EXPANDING_METRICS = macro.forecastMetrics( ...
    Y_test,ExpandingForecast,NaiveForecast);
NAIVE_METRICS = macro.forecastMetrics( ...
    Y_test,NaiveForecast,NaiveForecast);

FixedError = FIXED_METRICS.Errors;
ExpandingError = EXPANDING_METRICS.Errors;
NaiveError = NAIVE_METRICS.Errors;

%% ---------------------------------------------------------
% Performance metrics
% ----------------------------------------------------------

FixedRMSE = FIXED_METRICS.RMSE;
ExpandingRMSE = EXPANDING_METRICS.RMSE;
NaiveRMSE = NAIVE_METRICS.RMSE;
FixedMAE = FIXED_METRICS.MAE;
ExpandingMAE = EXPANDING_METRICS.MAE;
NaiveMAE = NAIVE_METRICS.MAE;

%% Forecast correlation

FixedCorrelation = FIXED_METRICS.ForecastCorrelation;
ExpandingCorrelation = EXPANDING_METRICS.ForecastCorrelation;
NaiveCorrelation = NAIVE_METRICS.ForecastCorrelation;

%% Directional accuracy

ActualDirection = sign(Y_test); %#ok<NASGU>
FixedDirectionalAccuracy = FIXED_METRICS.DirectionalAccuracy;
ExpandingDirectionalAccuracy = EXPANDING_METRICS.DirectionalAccuracy;
NaiveDirectionalAccuracy = NAIVE_METRICS.DirectionalAccuracy;

%% Improvement against naive benchmark

FixedRMSEImprovement = FIXED_METRICS.RMSEImprovementPercent;
ExpandingRMSEImprovement = EXPANDING_METRICS.RMSEImprovementPercent;
FixedMAEImprovement = FIXED_METRICS.MAEImprovementPercent;
ExpandingMAEImprovement = EXPANDING_METRICS.MAEImprovementPercent;

%% ---------------------------------------------------------
% Performance leaderboard
% ----------------------------------------------------------

Model = [ ...
    "Fixed Historical Model"
    "Expanding Window Model"
    "Naive Persistence"
    ];

RMSE = [ ...
    FixedRMSE
    ExpandingRMSE
    NaiveRMSE
    ];

MAE = [ ...
    FixedMAE
    ExpandingMAE
    NaiveMAE
    ];

Correlation = [ ...
    FixedCorrelation
    ExpandingCorrelation
    NaiveCorrelation
    ];

DirectionalAccuracy = [ ...
    FixedDirectionalAccuracy
    ExpandingDirectionalAccuracy
    NaiveDirectionalAccuracy
    ];

MODEL_LEADERBOARD = table( ...
    Model, ...
    RMSE, ...
    MAE, ...
    Correlation, ...
    DirectionalAccuracy);

disp(" ");
disp("==============================================");
disp(" EXPANDING WINDOW MODEL LEADERBOARD");
disp("==============================================");

disp(MODEL_LEADERBOARD);

fprintf("\nFixed RMSE Improvement vs Naive: %.2f %%\n", ...
    FixedRMSEImprovement);

fprintf("Expanding RMSE Improvement vs Naive: %.2f %%\n", ...
    ExpandingRMSEImprovement);

fprintf("\nFixed MAE Improvement vs Naive: %.2f %%\n", ...
    FixedMAEImprovement);

fprintf("Expanding MAE Improvement vs Naive: %.2f %%\n", ...
    ExpandingMAEImprovement);

%% Save leaderboard

writetable( ...
    MODEL_LEADERBOARD, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Expanding_Window_Model_Leaderboard.csv"));

%% ---------------------------------------------------------
% Save forecast results
% ----------------------------------------------------------

FORECAST_RESULTS = table( ...
    datesTest, ...
    Y_test, ...
    FixedForecast, ...
    ExpandingForecast, ...
    NaiveForecast, ...
    FixedError, ...
    ExpandingError, ...
    NaiveError, ...
    TrainingSize, ...
    'VariableNames', ...
    {'Date', ...
     'ActualGDPGrowth', ...
     'FixedForecast', ...
     'ExpandingForecast', ...
     'NaiveForecast', ...
     'FixedError', ...
     'ExpandingError', ...
     'NaiveError', ...
     'TrainingSize'});

writetable( ...
    FORECAST_RESULTS, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Expanding_Window_Forecasts.csv"));

%% ---------------------------------------------------------
% Coefficient history
% ----------------------------------------------------------

VariableNames = cellstr(design.VariableNames);

COEFFICIENT_HISTORY = array2table( ...
    CoefficientHistory, ...
    'VariableNames', ...
    VariableNames);

COEFFICIENT_HISTORY.Date = datesTest;

COEFFICIENT_HISTORY = ...
    movevars( ...
        COEFFICIENT_HISTORY, ...
        "Date", ...
        "Before", ...
        1);

writetable( ...
    COEFFICIENT_HISTORY, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Expanding_Window_Coefficient_History.csv"));

%% ---------------------------------------------------------
% Rolling RMSE
% ----------------------------------------------------------

rollingWindow = 8;

RollingFixedRMSE = ...
    NaN(numForecasts,1);

RollingExpandingRMSE = ...
    NaN(numForecasts,1);

RollingNaiveRMSE = ...
    NaN(numForecasts,1);

for i = rollingWindow:numForecasts

    idx = ...
        (i-rollingWindow+1):i;

    RollingFixedRMSE(i) = ...
        sqrt(mean(FixedError(idx).^2));

    RollingExpandingRMSE(i) = ...
        sqrt(mean(ExpandingError(idx).^2));

    RollingNaiveRMSE(i) = ...
        sqrt(mean(NaiveError(idx).^2));

end

%% ---------------------------------------------------------
% Figure 34 - Actual vs all forecasts
% ----------------------------------------------------------

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    datesTest, ...
    Y_test, ...
    'LineWidth',1.7);

hold on;

plot( ...
    datesTest, ...
    FixedForecast, ...
    '--', ...
    'LineWidth',1.4);

plot( ...
    datesTest, ...
    ExpandingForecast, ...
    '-.', ...
    'LineWidth',1.5);

plot( ...
    datesTest, ...
    NaiveForecast, ...
    ':', ...
    'LineWidth',1.4);

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    '2020 Shock');

yline(0,'--');

grid on;

title("Adaptive Out-of-Sample GDP Growth Forecasting");

subtitle( ...
    "Fixed Model vs Expanding Window vs Naive Persistence");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual GDP Growth", ...
    "Fixed Historical Model", ...
    "Expanding Window Model", ...
    "Naive Persistence", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig1, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "34_Adaptive_Forecast_Comparison.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 35 - Rolling RMSE
% ----------------------------------------------------------

fig2 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    datesTest, ...
    RollingFixedRMSE, ...
    'LineWidth',1.5);

hold on;

plot( ...
    datesTest, ...
    RollingExpandingRMSE, ...
    'LineWidth',1.6);

plot( ...
    datesTest, ...
    RollingNaiveRMSE, ...
    'LineWidth',1.5);

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    '2020 Shock');

grid on;

title("Rolling Forecast RMSE");

subtitle("Eight-Quarter Forecast Error Window");

xlabel("Year");
ylabel("Rolling RMSE");

legend( ...
    "Fixed Historical Model", ...
    "Expanding Window Model", ...
    "Naive Persistence", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig2, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "35_Rolling_RMSE.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 36 - Model leaderboard
% ----------------------------------------------------------

fig3 = figure( ...
    'Position',[100 100 950 600]);

bar( ...
    categorical(Model), ...
    RMSE);

grid on;

title("Out-of-Sample Forecast Model Leaderboard");

subtitle("Lower RMSE Indicates Better Forecast Performance");

ylabel("RMSE");

exportgraphics( ...
    fig3, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "36_Forecast_Model_Leaderboard.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 37 - Coefficient evolution
% Selected economically important coefficients
% ----------------------------------------------------------

fig4 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    datesTest, ...
    CoefficientHistory(:,2), ...
    'LineWidth',1.5);

hold on;

plot( ...
    datesTest, ...
    CoefficientHistory(:,7), ...
    'LineWidth',1.5);

plot( ...
    datesTest, ...
    CoefficientHistory(:,11), ...
    'LineWidth',1.5);

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    '2020 Shock');

yline(0,'--');

grid on;

title("Evolution of Expanding-Window Coefficients");

subtitle("Adaptive Model Parameter Stability");

xlabel("Year");
ylabel("Estimated Coefficient");

legend( ...
    "GDP Growth Lag 1", ...
    "Unemployment Lag 1", ...
    "Interest Rate Lag 1", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig4, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "37_Adaptive_Coefficient_Evolution.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 38 - Cumulative absolute forecast error
% ----------------------------------------------------------

CumulativeFixedError = ...
    cumsum(abs(FixedError));

CumulativeExpandingError = ...
    cumsum(abs(ExpandingError));

CumulativeNaiveError = ...
    cumsum(abs(NaiveError));

fig5 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    datesTest, ...
    CumulativeFixedError, ...
    'LineWidth',1.5);

hold on;

plot( ...
    datesTest, ...
    CumulativeExpandingError, ...
    'LineWidth',1.6);

plot( ...
    datesTest, ...
    CumulativeNaiveError, ...
    'LineWidth',1.5);

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    '2020 Shock');

grid on;

title("Cumulative Absolute Forecast Error");

subtitle("Long-Run Forecast Performance Comparison");

xlabel("Year");
ylabel("Cumulative Absolute Error");

legend( ...
    "Fixed Historical Model", ...
    "Expanding Window Model", ...
    "Naive Persistence", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig5, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "38_Cumulative_Forecast_Error.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 11 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/Expanding_Window_Model_Leaderboard.csv");
disp("results/Expanding_Window_Forecasts.csv");
disp("results/Expanding_Window_Coefficient_History.csv");

disp(" ");

disp("Figures saved:");
disp("figures/34_Adaptive_Forecast_Comparison.png");
disp("figures/35_Rolling_RMSE.png");
disp("figures/36_Forecast_Model_Leaderboard.png");
disp("figures/37_Adaptive_Coefficient_Evolution.png");
disp("figures/38_Cumulative_Forecast_Error.png");

output = struct("Design",design, ...
    "InitialTrainIndex",trainInitial, ...
    "TestIndex",testIndex, ...
    "FixedModel",FIXED_MODEL, ...
    "FixedMetrics",FIXED_METRICS, ...
    "ExpandingMetrics",EXPANDING_METRICS, ...
    "NaiveMetrics",NAIVE_METRICS, ...
    "ModelLeaderboard",MODEL_LEADERBOARD, ...
    "ForecastResults",FORECAST_RESULTS, ...
    "CoefficientHistory",COEFFICIENT_HISTORY, ...
    "RollingFixedRMSE",RollingFixedRMSE, ...
    "RollingExpandingRMSE",RollingExpandingRMSE, ...
    "RollingNaiveRMSE",RollingNaiveRMSE, ...
    "FigureFiles",[ ...
        "34_Adaptive_Forecast_Comparison.png"; ...
        "35_Rolling_RMSE.png"; ...
        "36_Forecast_Model_Leaderboard.png"; ...
        "37_Adaptive_Coefficient_Evolution.png"; ...
        "38_Cumulative_Forecast_Error.png"]);
end

function [cfg,pathCleanup] = initializePhaseConfiguration(cfg,scriptPath)
projectRoot = string(fileparts(fileparts(scriptPath)));
sourceDir = fullfile(projectRoot,"src");
pathEntries = string(strsplit(path,pathsep));
if ~any(pathEntries == sourceDir)
    addpath(sourceDir);
    pathCleanup = onCleanup(@() rmpath(sourceDir));
else
    pathCleanup = onCleanup(@() []);
end
if isempty(cfg)
    cfg = macro.projectConfig(projectRoot);
end
end

function inputFile = resolveDataInput(cfg,fileName)
inputFile = fullfile(cfg.DataDir,fileName);
if ~isfile(inputFile)
    sourceFile = fullfile(cfg.SourceDataDir,fileName);
    if ~isfile(sourceFile)
        error("macro:phase11:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
