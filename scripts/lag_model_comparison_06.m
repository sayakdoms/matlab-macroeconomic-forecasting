function output = lag_model_comparison_06(cfg)
%LAG_MODEL_COMPARISON_06 Phase 6 - Common-lag model comparison.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 6 - Lag Model Comparison

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 6: Lag Model Comparison");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Clean quarterly dataset loaded successfully.");

%% Settings

maxLag = 4;                 % Compare lag 0 to lag 4
numModels = maxLag + 1;

modelNames = strings(numModels,1);

Observations = zeros(numModels,1);
RSquared = zeros(numModels,1);
AdjustedRSquared = zeros(numModels,1);
RMSE = zeros(numModels,1);
AIC = zeros(numModels,1);
BIC = zeros(numModels,1);
FStatistic = zeros(numModels,1);

InterceptCoef = zeros(numModels,1);
InflationCoef = zeros(numModels,1);
UnemploymentCoef = zeros(numModels,1);
InterestRateCoef = zeros(numModels,1);

%% Loop over lag specifications

for L = 0:maxLag

    % Model label
    modelIndex = L + 1;
    modelNames(modelIndex) = "Lag " + string(L);

    % Preserve the existing varying sample for each common lag
    design = macro.buildCommonLagDesign(DATA,L);
    model = macro.estimateOLS(design.X,design.Y, ...
        CovarianceSolver="inverse");
    beta = model.Coefficients;

    % Store metrics
    Observations(modelIndex) = model.Observations;
    RSquared(modelIndex) = model.RSquared;
    AdjustedRSquared(modelIndex) = model.AdjustedRSquared;
    RMSE(modelIndex) = model.RMSE;
    AIC(modelIndex) = model.AIC;
    BIC(modelIndex) = model.BIC;
    FStatistic(modelIndex) = model.FStatistic;

    % Store coefficients
    InterceptCoef(modelIndex) = beta(1);
    InflationCoef(modelIndex) = beta(2);
    UnemploymentCoef(modelIndex) = beta(3);
    InterestRateCoef(modelIndex) = beta(4);

end

%% Build model comparison table

MODEL_COMPARISON = table( ...
    modelNames, ...
    Observations, ...
    RSquared, ...
    AdjustedRSquared, ...
    RMSE, ...
    AIC, ...
    BIC, ...
    FStatistic, ...
    'VariableNames', ...
    {'Model', ...
     'Observations', ...
     'RSquared', ...
     'AdjustedRSquared', ...
     'RMSE', ...
     'AIC', ...
     'BIC', ...
     'FStatistic'});

disp(" ");
disp("==============================================");
disp(" LAG MODEL COMPARISON");
disp("==============================================");
disp(MODEL_COMPARISON);

%% Save comparison table

writetable( ...
    MODEL_COMPARISON, ...
    fullfile(cfg.ResultsDir,"Lag_Model_Comparison.csv"));

%% Coefficient path table

COEFFICIENT_PATHS = table( ...
    modelNames, ...
    InterceptCoef, ...
    InflationCoef, ...
    UnemploymentCoef, ...
    InterestRateCoef, ...
    'VariableNames', ...
    {'Model', ...
     'Intercept', ...
     'Inflation', ...
     'Unemployment', ...
     'InterestRate'});

disp(" ");
disp("==============================================");
disp(" COEFFICIENT PATHS ACROSS LAGS");
disp("==============================================");
disp(COEFFICIENT_PATHS);

writetable( ...
    COEFFICIENT_PATHS, ...
    fullfile(cfg.ResultsDir,"Lag_Model_Coefficients.csv"));

%% Identify best model
% Criterion: highest Adjusted R-Squared

[bestAdjR2, bestIndex] = max(AdjustedRSquared);
bestLag = bestIndex - 1;

fprintf("\nBest model based on Adjusted R-Squared: Lag %d\n", bestLag);
fprintf("Best Adjusted R-Squared: %.4f\n", bestAdjR2);

%% Re-estimate best lag model for detailed output

bestDesign = macro.buildCommonLagDesign(DATA,bestLag);
bestModel = macro.estimateOLS(bestDesign.X,bestDesign.Y, ...
    CovarianceSolver="inverse");

Best_Y = bestDesign.Y;
Best_Dates = bestDesign.Dates;
Best_Y_hat = bestModel.Fitted;
Best_residuals = bestModel.Residuals;

BEST_MODEL_OUTPUT = table( ...
    Best_Dates, ...
    Best_Y, ...
    Best_Y_hat, ...
    Best_residuals, ...
    'VariableNames', ...
    {'Date', ...
     'ActualGDPGrowth', ...
     'PredictedGDPGrowth', ...
     'Residual'});

writetable( ...
    BEST_MODEL_OUTPUT, ...
    fullfile(cfg.ResultsDir,"Best_Lag_Model_Output.csv"));

%% Save best model summary

BEST_MODEL_SUMMARY = table( ...
    "Lag " + string(bestLag), ...
    Observations(bestIndex), ...
    RSquared(bestIndex), ...
    AdjustedRSquared(bestIndex), ...
    RMSE(bestIndex), ...
    AIC(bestIndex), ...
    BIC(bestIndex), ...
    FStatistic(bestIndex), ...
    'VariableNames', ...
    {'BestModel', ...
     'Observations', ...
     'RSquared', ...
     'AdjustedRSquared', ...
     'RMSE', ...
     'AIC', ...
     'BIC', ...
     'FStatistic'});

writetable( ...
    BEST_MODEL_SUMMARY, ...
    fullfile(cfg.ResultsDir,"Best_Lag_Model_Summary.csv"));

%% Figure 15 - R-Squared comparison across lag models

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1100 600]);

plot(0:maxLag, RSquared, '-o', 'LineWidth', 1.8);
hold on;
plot(0:maxLag, AdjustedRSquared, '--s', 'LineWidth', 1.8);

grid on;

title("Lag Model Comparison: R-Squared Performance");
subtitle("GDP Growth Regressed on Lagged Inflation, Unemployment and Interest Rate");

xlabel("Lag Length (Quarters)");
ylabel("Model Fit");

legend("R-Squared", "Adjusted R-Squared", 'Location','best');
hold off;

exportgraphics( ...
    fig1, ...
    fullfile(cfg.FiguresDir,"15_Lag_Model_R2_Comparison.png"), ...
    'Resolution',300);

%% Figure 16 - RMSE comparison across lag models

fig2 = figure( ...
    'Position',[100 100 1100 600]);

plot(0:maxLag, RMSE, '-o', 'LineWidth', 1.8);

grid on;

title("Lag Model Comparison: RMSE");
subtitle("Lower RMSE Indicates Better Predictive Fit");

xlabel("Lag Length (Quarters)");
ylabel("RMSE");

exportgraphics( ...
    fig2, ...
    fullfile(cfg.FiguresDir,"16_Lag_Model_RMSE_Comparison.png"), ...
    'Resolution',300);

%% Figure 17 - Coefficient paths across lag models

fig3 = figure( ...
    'Position',[100 100 1200 650]);

plot(0:maxLag, InflationCoef, '-o', 'LineWidth', 1.6);
hold on;
plot(0:maxLag, UnemploymentCoef, '-s', 'LineWidth', 1.6);
plot(0:maxLag, InterestRateCoef, '-d', 'LineWidth', 1.6);

yline(0,'--');

grid on;

title("Coefficient Paths Across Lag Models");
subtitle("How Estimated Predictor Effects Change with Lag Length");

xlabel("Lag Length (Quarters)");
ylabel("Estimated Coefficient");

legend("Inflation", "Unemployment", "Interest Rate", 'Location','best');
hold off;

exportgraphics( ...
    fig3, ...
    fullfile(cfg.FiguresDir,"17_Coefficient_Paths_Across_Lags.png"), ...
    'Resolution',300);

%% Figure 18 - Actual vs Predicted for best lag model

fig4 = figure( ...
    'Position',[100 100 1200 650]);

plot(Best_Dates, Best_Y, 'LineWidth', 1.5);
hold on;
plot(Best_Dates, Best_Y_hat, '--', 'LineWidth', 1.6);

yline(0,'--');

grid on;

title("Best Lag Model: Actual vs Predicted GDP Growth");
subtitle("Selected by Highest Adjusted R-Squared");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual GDP Growth", ...
    "Predicted GDP Growth", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig4, ...
    fullfile(cfg.FiguresDir,"18_Best_Lag_Model_Actual_vs_Predicted.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 6 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/Lag_Model_Comparison.csv");
disp("results/Lag_Model_Coefficients.csv");
disp("results/Best_Lag_Model_Output.csv");
disp("results/Best_Lag_Model_Summary.csv");

disp(" ");

disp("Figures saved:");
disp("figures/15_Lag_Model_R2_Comparison.png");
disp("figures/16_Lag_Model_RMSE_Comparison.png");
disp("figures/17_Coefficient_Paths_Across_Lags.png");
disp("figures/18_Best_Lag_Model_Actual_vs_Predicted.png");

output = struct("ModelComparison",MODEL_COMPARISON, ...
    "CoefficientPaths",COEFFICIENT_PATHS, ...
    "BestLag",bestLag, ...
    "BestDesign",bestDesign, ...
    "BestModel",bestModel, ...
    "BestModelOutput",BEST_MODEL_OUTPUT, ...
    "BestModelSummary",BEST_MODEL_SUMMARY, ...
    "FigureFiles",[ ...
        "15_Lag_Model_R2_Comparison.png"; ...
        "16_Lag_Model_RMSE_Comparison.png"; ...
        "17_Coefficient_Paths_Across_Lags.png"; ...
        "18_Best_Lag_Model_Actual_vs_Predicted.png"]);
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
        error("macro:phase06:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
