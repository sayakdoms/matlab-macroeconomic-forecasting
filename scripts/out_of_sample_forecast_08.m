function output = out_of_sample_forecast_08(cfg)
%OUT_OF_SAMPLE_FORECAST_08 Phase 8 - Fixed out-of-sample forecast.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 8 - Out-of-Sample Forecasting
%
% Objective:
% Forecast current GDP growth using ONLY lagged information.
%
% Training period: before 2016
% Test period: 2016 onward

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 8: Out-of-Sample GDP Forecasting");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Quarterly dataset loaded successfully.");

%% ---------------------------------------------------------
% MODEL DESIGN
%
% Forecast GDPGrowth(t) using:
%
% GDPGrowth(t-1)
%
% Inflation(t-1) to Inflation(t-4)
% Unemployment(t-1) to Unemployment(t-4)
% InterestRate(t-1) to InterestRate(t-4)
%
% No contemporaneous predictors are used.
% ----------------------------------------------------------

design = macro.buildForecastDesign(DATA);
Y = design.Y;
forecastDates = design.Dates;
X = design.X;

%% Split into training and test samples

splitDate = datetime(2016,1,1);

trainIndex = forecastDates < splitDate;
testIndex  = forecastDates >= splitDate;

X_train = X(trainIndex,:);
Y_train = Y(trainIndex);

X_test = X(testIndex,:);
Y_test = Y(testIndex);

datesTest = forecastDates(testIndex);

fprintf("\nTraining observations: %d\n", length(Y_train));
fprintf("Test observations: %d\n", length(Y_test));

fprintf("Training end date: %s\n", ...
    string(forecastDates(find(trainIndex,1,'last'))));

fprintf("Test start date: %s\n", ...
    string(datesTest(1)));

%% ---------------------------------------------------------
% Estimate forecasting model
% ----------------------------------------------------------

MODEL = macro.estimateOLS(X_train,Y_train, ...
    CovarianceSolver="inverse");
beta = MODEL.Coefficients;

%% Generate out-of-sample predictions

Y_forecast = X_test * beta;

naiveForecast = X_test(:,2);
METRICS = macro.forecastMetrics(Y_test,Y_forecast,naiveForecast);

forecastErrors = METRICS.Errors;
naiveErrors = METRICS.PersistenceErrors;
RMSE = METRICS.RMSE;
MAE = METRICS.MAE;
ForecastCorrelation = METRICS.ForecastCorrelation;
DirectionalAccuracy = METRICS.DirectionalAccuracy;
NaiveRMSE = METRICS.NaiveRMSE;
NaiveMAE = METRICS.NaiveMAE;
RMSEImprovement = METRICS.RMSEImprovementPercent;
MAEImprovement = METRICS.MAEImprovementPercent;

%% ---------------------------------------------------------
% Display forecast results
% ----------------------------------------------------------

disp(" ");
disp("==============================================");
disp(" OUT-OF-SAMPLE FORECAST PERFORMANCE");
disp("==============================================");

fprintf("Econometric Model RMSE: %.4f\n",RMSE);
fprintf("Econometric Model MAE: %.4f\n",MAE);
fprintf("Forecast Correlation: %.4f\n",ForecastCorrelation);
fprintf("Directional Accuracy: %.2f %%\n",DirectionalAccuracy);

fprintf("\nNaive Model RMSE: %.4f\n",NaiveRMSE);
fprintf("Naive Model MAE: %.4f\n",NaiveMAE);

fprintf("\nRMSE Improvement vs Naive: %.2f %%\n", ...
    RMSEImprovement);

fprintf("MAE Improvement vs Naive: %.2f %%\n", ...
    MAEImprovement);

%% ---------------------------------------------------------
% Save coefficient table
% ----------------------------------------------------------

Variable = design.VariableNames';

FORECAST_COEFFICIENTS = table( ...
    Variable, ...
    beta, ...
    'VariableNames', ...
    {'Variable','Coefficient'});

writetable( ...
    FORECAST_COEFFICIENTS, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Forecast_Model_Coefficients.csv"));

%% ---------------------------------------------------------
% Save forecast performance summary
% ----------------------------------------------------------

FORECAST_SUMMARY = table( ...
    RMSE, ...
    MAE, ...
    ForecastCorrelation, ...
    DirectionalAccuracy, ...
    NaiveRMSE, ...
    NaiveMAE, ...
    RMSEImprovement, ...
    MAEImprovement, ...
    'VariableNames', ...
    {'ModelRMSE', ...
     'ModelMAE', ...
     'ForecastCorrelation', ...
     'DirectionalAccuracyPercent', ...
     'NaiveRMSE', ...
     'NaiveMAE', ...
     'RMSEImprovementPercent', ...
     'MAEImprovementPercent'});

writetable( ...
    FORECAST_SUMMARY, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Out_of_Sample_Forecast_Summary.csv"));

%% ---------------------------------------------------------
% Save forecast-by-quarter results
% ----------------------------------------------------------

FORECAST_RESULTS = table( ...
    datesTest, ...
    Y_test, ...
    Y_forecast, ...
    naiveForecast, ...
    forecastErrors, ...
    'VariableNames', ...
    {'Date', ...
     'ActualGDPGrowth', ...
     'EconometricForecast', ...
     'NaiveForecast', ...
     'ForecastError'});

writetable( ...
    FORECAST_RESULTS, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Out_of_Sample_Forecasts.csv"));

%% ---------------------------------------------------------
% Figure 23 - Actual vs Econometric Forecast
% ----------------------------------------------------------

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1200 650]);

plot( ...
    datesTest, ...
    Y_test, ...
    'LineWidth',1.6);

hold on;

plot( ...
    datesTest, ...
    Y_forecast, ...
    '--', ...
    'LineWidth',1.7);

yline(0,'--');

grid on;

title("Out-of-Sample U.S. GDP Growth Forecast");

subtitle( ...
    "Econometric Forecast vs Actual GDP Growth");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual GDP Growth", ...
    "Econometric Forecast", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig1, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "23_Out_of_Sample_Forecast.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 24 - Forecast comparison
% ----------------------------------------------------------

fig2 = figure( ...
    'Position',[100 100 1200 650]);

plot( ...
    datesTest, ...
    Y_test, ...
    'LineWidth',1.6);

hold on;

plot( ...
    datesTest, ...
    Y_forecast, ...
    '--', ...
    'LineWidth',1.6);

plot( ...
    datesTest, ...
    naiveForecast, ...
    ':', ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("Forecast Model Comparison");

subtitle( ...
    "Econometric Forecast vs Naive Persistence Benchmark");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual", ...
    "Econometric Forecast", ...
    "Naive Forecast", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig2, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "24_Forecast_Model_Comparison.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 25 - Forecast error
% ----------------------------------------------------------

fig3 = figure( ...
    'Position',[100 100 1200 600]);

plot( ...
    datesTest, ...
    forecastErrors, ...
    'LineWidth',1.4);

yline(0,'--');

grid on;

title("Out-of-Sample Forecast Errors");

subtitle( ...
    "Actual GDP Growth Minus Econometric Forecast");

xlabel("Year");
ylabel("Forecast Error");

exportgraphics( ...
    fig3, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "25_Out_of_Sample_Forecast_Errors.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 26 - RMSE benchmark comparison
% ----------------------------------------------------------

fig4 = figure;

bar( ...
    categorical(["Econometric Model","Naive Model"]), ...
    [RMSE NaiveRMSE]);

grid on;

title("Out-of-Sample RMSE Comparison");

ylabel("RMSE");

exportgraphics( ...
    fig4, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "26_Forecast_RMSE_Comparison.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 8 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/Forecast_Model_Coefficients.csv");
disp("results/Out_of_Sample_Forecast_Summary.csv");
disp("results/Out_of_Sample_Forecasts.csv");

disp(" ");

disp("Figures saved:");
disp("figures/23_Out_of_Sample_Forecast.png");
disp("figures/24_Forecast_Model_Comparison.png");
disp("figures/25_Out_of_Sample_Forecast_Errors.png");
disp("figures/26_Forecast_RMSE_Comparison.png");

output = struct("Design",design, ...
    "TrainIndex",trainIndex, ...
    "TestIndex",testIndex, ...
    "Model",MODEL, ...
    "Metrics",METRICS, ...
    "ForecastCoefficients",FORECAST_COEFFICIENTS, ...
    "ForecastSummary",FORECAST_SUMMARY, ...
    "ForecastResults",FORECAST_RESULTS, ...
    "FigureFiles",[ ...
        "23_Out_of_Sample_Forecast.png"; ...
        "24_Forecast_Model_Comparison.png"; ...
        "25_Out_of_Sample_Forecast_Errors.png"; ...
        "26_Forecast_RMSE_Comparison.png"]);
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
        error("macro:phase08:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
