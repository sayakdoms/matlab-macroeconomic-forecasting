function output = regression_model_04(cfg)
%REGRESSION_MODEL_04 Phase 4 - Baseline contemporaneous OLS model.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 4 - OLS Regression Model
%
% Research model:
%
% GDP Growth =
% beta0
% + beta1 * Inflation
% + beta2 * Unemployment
% + beta3 * Interest Rate
% + error

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 4: OLS Regression Analysis");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Clean quarterly dataset loaded successfully.");

%% Define dependent variable

Y = DATA.GDPGrowth;

%% Define explanatory variables

Inflation    = DATA.Inflation;
Unemployment = DATA.Unemployment;
InterestRate = DATA.InterestRate;

%% Build regression design matrix

n = length(Y);

X = [ ...
    ones(n,1), ...
    Inflation, ...
    Unemployment, ...
    InterestRate];

%% Estimate OLS model using the project's existing conventions

MODEL = macro.estimateOLS(X,Y,CovarianceSolver="inverse");

beta = MODEL.Coefficients;
Y_hat = MODEL.Fitted;
residuals = MODEL.Residuals;
k = MODEL.Parameters;
degreesFreedom = MODEL.DegreesFreedom;
SSE = MODEL.SSE;
SST = MODEL.SST;
SSR = MODEL.SSR;
R2 = MODEL.RSquared;
AdjustedR2 = MODEL.AdjustedRSquared;
sigma2 = MODEL.ResidualVariance;
VarBeta = MODEL.Covariance;
StandardError = MODEL.StandardErrors;
TStatistic = MODEL.TStatistics;
PValue = MODEL.ApproxPValues;

%% Create coefficient names

Variable = [ ...
    "Intercept"; ...
    "Inflation"; ...
    "Unemployment"; ...
    "Interest Rate"];

%% Regression results table

REGRESSION_RESULTS = table( ...
    Variable, ...
    beta, ...
    StandardError, ...
    TStatistic, ...
    PValue, ...
    'VariableNames', ...
    {'Variable', ...
     'Coefficient', ...
     'StandardError', ...
     'TStatistic', ...
     'ApproxPValue'});

%% Display regression results

disp(" ");
disp("==============================================");
disp(" OLS REGRESSION RESULTS");
disp("==============================================");

disp(REGRESSION_RESULTS);

fprintf("\nNumber of Observations: %d\n", n);
fprintf("R-Squared: %.4f\n", R2);
fprintf("Adjusted R-Squared: %.4f\n", AdjustedR2);
fprintf("Residual Standard Error: %.4f\n", sqrt(sigma2));

%% Overall model F-statistic

numberPredictors = k - 1; %#ok<NASGU>
FStatistic = MODEL.FStatistic;

fprintf("F-Statistic: %.4f\n", FStatistic);

%% Save regression coefficients

writetable( ...
    REGRESSION_RESULTS, ...
    fullfile(cfg.ResultsDir,"OLS_Regression_Results.csv"));

%% Save model summary

MODEL_SUMMARY = table( ...
    n, ...
    R2, ...
    AdjustedR2, ...
    sqrt(sigma2), ...
    FStatistic, ...
    'VariableNames', ...
    {'Observations', ...
     'RSquared', ...
     'AdjustedRSquared', ...
     'ResidualStdError', ...
     'FStatistic'});

writetable( ...
    MODEL_SUMMARY, ...
    fullfile(cfg.ResultsDir,"OLS_Model_Summary.csv"));

%% Save actual, predicted and residual values

MODEL_OUTPUT = table( ...
    DATA.observation_date, ...
    Y, ...
    Y_hat, ...
    residuals, ...
    'VariableNames', ...
    {'Date', ...
     'ActualGDPGrowth', ...
     'PredictedGDPGrowth', ...
     'Residual'});

writetable( ...
    MODEL_OUTPUT, ...
    fullfile(cfg.ResultsDir,"OLS_Predictions_Residuals.csv"));

%% Figure 1 - Actual vs Predicted GDP Growth

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1100 600]);

plot( ...
    DATA.observation_date, ...
    Y, ...
    'LineWidth',1.4);

hold on;

plot( ...
    DATA.observation_date, ...
    Y_hat, ...
    '--', ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("Actual vs Predicted U.S. GDP Growth");

subtitle( ...
    "OLS Model: Inflation, Unemployment and Federal Funds Rate");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual GDP Growth", ...
    "Predicted GDP Growth", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig1, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "07_Actual_vs_Predicted_GDP_Growth.png"), ...
    'Resolution',300);

%% Figure 2 - Residual Time Series

fig2 = figure( ...
    'Position',[100 100 1100 600]);

plot( ...
    DATA.observation_date, ...
    residuals, ...
    'LineWidth',1.3);

yline(0,'--');

grid on;

title("OLS Regression Residuals Over Time");

subtitle( ...
    "Difference Between Actual and Predicted GDP Growth");

xlabel("Year");
ylabel("Residual");

exportgraphics( ...
    fig2, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "08_OLS_Residuals.png"), ...
    'Resolution',300);

%% Figure 3 - Residual Histogram

fig3 = figure;

histogram( ...
    residuals, ...
    20);

grid on;

title("Distribution of OLS Regression Residuals");

xlabel("Residual");
ylabel("Frequency");

exportgraphics( ...
    fig3, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "09_Residual_Distribution.png"), ...
    'Resolution',300);

%% Figure 4 - Observed vs Fitted Scatter Plot

fig4 = figure;

scatter( ...
    Y, ...
    Y_hat, ...
    35, ...
    'filled');

hold on;

minimumValue = min([Y;Y_hat]);
maximumValue = max([Y;Y_hat]);

plot( ...
    [minimumValue maximumValue], ...
    [minimumValue maximumValue], ...
    '--', ...
    'LineWidth',1.5);

grid on;
axis equal;

title("Observed vs Fitted GDP Growth");

xlabel("Actual GDP Growth (%)");
ylabel("Predicted GDP Growth (%)");

legend( ...
    "Quarterly Observations", ...
    "Perfect Prediction Line", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig4, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "10_Observed_vs_Fitted.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 4 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/OLS_Regression_Results.csv");
disp("results/OLS_Model_Summary.csv");
disp("results/OLS_Predictions_Residuals.csv");

disp(" ");

disp("Figures saved:");
disp("figures/07_Actual_vs_Predicted_GDP_Growth.png");
disp("figures/08_OLS_Residuals.png");
disp("figures/09_Residual_Distribution.png");
disp("figures/10_Observed_vs_Fitted.png");

output = struct("Model",MODEL, ...
    "RegressionResults",REGRESSION_RESULTS, ...
    "ModelSummary",MODEL_SUMMARY, ...
    "ModelOutput",MODEL_OUTPUT, ...
    "FigureFiles",[ ...
        "07_Actual_vs_Predicted_GDP_Growth.png"; ...
        "08_OLS_Residuals.png"; ...
        "09_Residual_Distribution.png"; ...
        "10_Observed_vs_Fitted.png"]);
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
        error("macro:phase04:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
