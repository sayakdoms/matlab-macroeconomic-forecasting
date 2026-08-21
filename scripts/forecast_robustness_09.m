function output = forecast_robustness_09(cfg)
%FORECAST_ROBUSTNESS_09 Phase 9 - Forecast robustness by regime.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 9 - Forecast Robustness Across Economic Regimes

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 9: Forecast Robustness Analysis");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load previously generated forecasts

RESULTS = readtable( ...
    resolveResultInput(cfg,"Out_of_Sample_Forecasts.csv"));

macro.requireTableVariables(RESULTS,[ ...
    "Date","ActualGDPGrowth","EconometricForecast","NaiveForecast"]);

%% Convert date variable

RESULTS.Date = datetime(RESULTS.Date);

%% Extract variables

dates = RESULTS.Date;

actual = RESULTS.ActualGDPGrowth;
modelForecast = RESULTS.EconometricForecast;
naiveForecast = RESULTS.NaiveForecast;

%% Define economic regimes

preCovid = ...
    dates < datetime(2020,1,1);

covidShock = ...
    dates >= datetime(2020,1,1) & ...
    dates < datetime(2021,1,1);

postCovid = ...
    dates >= datetime(2021,1,1);

%% ---------------------------------------------------------
% Helper calculations
% ----------------------------------------------------------

regimeNames = [ ...
    "2016-2019 Pre-COVID"
    "2020 COVID Shock"
    "2021+ Post-COVID"
    "Full Test Sample"
    ];

indices = { ...
    preCovid
    covidShock
    postCovid
    true(size(dates))
    };

numRegimes = length(regimeNames);

ModelRMSE = zeros(numRegimes,1);
NaiveRMSE = zeros(numRegimes,1);

ModelMAE = zeros(numRegimes,1);
NaiveMAE = zeros(numRegimes,1);

RMSEImprovement = zeros(numRegimes,1);
MAEImprovement = zeros(numRegimes,1);

Observations = zeros(numRegimes,1);

%% Calculate metrics for each regime

for r = 1:numRegimes

    idx = indices{r};

    y = actual(idx);

    model = modelForecast(idx);
    naive = naiveForecast(idx);

    metrics = macro.forecastMetrics(y,model,naive);

    Observations(r) = sum(idx);

    ModelRMSE(r) = metrics.RMSE;
    NaiveRMSE(r) = metrics.NaiveRMSE;
    ModelMAE(r) = metrics.MAE;
    NaiveMAE(r) = metrics.NaiveMAE;
    RMSEImprovement(r) = metrics.RMSEImprovementPercent;
    MAEImprovement(r) = metrics.MAEImprovementPercent;

end

%% Build robustness table

ROBUSTNESS = table( ...
    regimeNames, ...
    Observations, ...
    ModelRMSE, ...
    NaiveRMSE, ...
    RMSEImprovement, ...
    ModelMAE, ...
    NaiveMAE, ...
    MAEImprovement, ...
    'VariableNames', ...
    {'Regime', ...
     'Observations', ...
     'ModelRMSE', ...
     'NaiveRMSE', ...
     'RMSEImprovementPercent', ...
     'ModelMAE', ...
     'NaiveMAE', ...
     'MAEImprovementPercent'});

disp(" ");
disp("==============================================");
disp(" FORECAST ROBUSTNESS RESULTS");
disp("==============================================");

disp(ROBUSTNESS);

%% Save results

writetable( ...
    ROBUSTNESS, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Forecast_Robustness_Results.csv"));

%% Figure 27 - RMSE by regime

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1200 650]);

bar( ...
    categorical(regimeNames), ...
    [ModelRMSE NaiveRMSE]);

grid on;

title("Forecast RMSE Across Economic Regimes");

subtitle( ...
    "Econometric Model vs Naive Benchmark");

ylabel("RMSE");

legend( ...
    "Econometric Model", ...
    "Naive Benchmark", ...
    'Location','best');

exportgraphics( ...
    fig1, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "27_Forecast_RMSE_by_Regime.png"), ...
    'Resolution',300);

%% Figure 28 - MAE by regime

fig2 = figure( ...
    'Position',[100 100 1200 650]);

bar( ...
    categorical(regimeNames), ...
    [ModelMAE NaiveMAE]);

grid on;

title("Forecast MAE Across Economic Regimes");

subtitle( ...
    "Sensitivity of Forecast Performance to Structural Shocks");

ylabel("MAE");

legend( ...
    "Econometric Model", ...
    "Naive Benchmark", ...
    'Location','best');

exportgraphics( ...
    fig2, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "28_Forecast_MAE_by_Regime.png"), ...
    'Resolution',300);

%% Figure 29 - Actual vs forecasts with COVID markers

fig3 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    dates, ...
    actual, ...
    'LineWidth',1.6);

hold on;

plot( ...
    dates, ...
    modelForecast, ...
    '--', ...
    'LineWidth',1.5);

plot( ...
    dates, ...
    naiveForecast, ...
    ':', ...
    'LineWidth',1.5);

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    'COVID-19 Shock Begins');

xline( ...
    datetime(2021,1,1), ...
    '--', ...
    'Post-COVID Period');

yline(0,'--');

grid on;

title("Forecast Performance Through the COVID-19 Structural Shock");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

legend( ...
    "Actual GDP Growth", ...
    "Econometric Forecast", ...
    "Naive Benchmark", ...
    'Location','best');

hold off;

exportgraphics( ...
    fig3, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "29_Forecasts_and_COVID_Shock.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 9 COMPLETE");
disp("==============================================");

disp("Result saved:");
disp("results/Forecast_Robustness_Results.csv");

disp(" ");

disp("Figures saved:");
disp("figures/27_Forecast_RMSE_by_Regime.png");
disp("figures/28_Forecast_MAE_by_Regime.png");
disp("figures/29_Forecasts_and_COVID_Shock.png");

output = struct("Robustness",ROBUSTNESS, ...
    "RegimeIndices",{indices}, ...
    "FigureFiles",[ ...
        "27_Forecast_RMSE_by_Regime.png"; ...
        "28_Forecast_MAE_by_Regime.png"; ...
        "29_Forecasts_and_COVID_Shock.png"]);
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

function inputFile = resolveResultInput(cfg,fileName)
inputFile = fullfile(cfg.ResultsDir,fileName);
if ~isfile(inputFile)
    sourceFile = fullfile(cfg.ProjectRoot,"results",fileName);
    if ~isfile(sourceFile)
        error("macro:phase09:MissingInput", ...
            "Required result file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
