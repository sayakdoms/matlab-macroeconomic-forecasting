function output = final_research_dashboard_12(cfg)
%FINAL_RESEARCH_DASHBOARD_12 Phase 12 - Executive research dashboard.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 12 - Final Executive Research Dashboard
%
% Objective:
% Combine the key empirical findings from all previous phases
% into a polished portfolio-ready research dashboard.

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 12: Final Research Dashboard");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% =========================================================
% LOAD CORE DATA
% ==========================================================

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

OLS_SUMMARY = readtable( ...
    resolveResultInput(cfg,"OLS_Model_Summary.csv"));

DYNAMIC_SUMMARY = readtable( ...
    resolveResultInput(cfg,"Dynamic_Model_Summary.csv"));

ROBUSTNESS = readtable( ...
    resolveResultInput(cfg,"Forecast_Robustness_Results.csv"));

BREAK_TEST = readtable( ...
    resolveResultInput(cfg,"Structural_Break_Test.csv"));

LEADERBOARD = readtable( ...
    resolveResultInput(cfg,"Expanding_Window_Model_Leaderboard.csv"));

FORECASTS = readtable( ...
    resolveResultInput(cfg,"Expanding_Window_Forecasts.csv"));

macro.requireTableVariables(OLS_SUMMARY,["RSquared","AdjustedRSquared"]);
macro.requireTableVariables(DYNAMIC_SUMMARY, ...
    ["RSquared","AdjustedRSquared","RMSE"]);
macro.requireTableVariables(ROBUSTNESS,[ ...
    "Regime","ModelMAE","NaiveMAE", ...
    "RMSEImprovementPercent","MAEImprovementPercent"]);
macro.requireTableVariables(BREAK_TEST,["ChowFStatistic","ApproxPValue"]);
macro.requireTableVariables(LEADERBOARD,["Model","RMSE"]);
macro.requireTableVariables(FORECASTS,[ ...
    "Date","ActualGDPGrowth","ExpandingForecast","NaiveForecast"]);

disp("All project results loaded successfully.");

%% Convert forecast date if necessary

if ~isdatetime(FORECASTS.Date)
    FORECASTS.Date = datetime(FORECASTS.Date);
end

%% =========================================================
% EXTRACT HEADLINE PROJECT METRICS
% ==========================================================

numObservations = height(DATA);

startYear = year(DATA.observation_date(1));
endYear   = year(DATA.observation_date(end));

baselineR2 = ...
    OLS_SUMMARY.RSquared(1);

baselineAdjR2 = ...
    OLS_SUMMARY.AdjustedRSquared(1);

dynamicR2 = ...
    DYNAMIC_SUMMARY.RSquared(1);

dynamicAdjR2 = ...
    DYNAMIC_SUMMARY.AdjustedRSquared(1);

dynamicRMSE = ...
    DYNAMIC_SUMMARY.RMSE(1);

%% Pre-COVID robustness result

preCovidRow = contains( ...
    string(ROBUSTNESS.Regime), ...
    "Pre-COVID");

preCovidMAEImprovement = ...
    ROBUSTNESS.MAEImprovementPercent(preCovidRow);

preCovidRMSEImprovement = ...
    ROBUSTNESS.RMSEImprovementPercent(preCovidRow);

%% Structural break statistics

chowF = ...
    BREAK_TEST.ChowFStatistic(1);

chowP = ...
    BREAK_TEST.ApproxPValue(1);

%% Best out-of-sample model by RMSE

[bestRMSE,bestModelIndex] = ...
    min(LEADERBOARD.RMSE);

bestModelName = ...
    string(LEADERBOARD.Model(bestModelIndex));

%% =========================================================
% CREATE FINAL EXECUTIVE DASHBOARD
% ==========================================================

if cfg.GenerateFigures

fig = figure( ...
    'Position',[50 40 1500 950]);

layout = tiledlayout( ...
    3, ...
    2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(layout, ...
    "U.S. Macroeconomic Dynamics & GDP Growth Forecasting", ...
    'FontSize',18, ...
    'FontWeight','bold');

subtitle(layout, ...
    "MATLAB Econometrics Project | FRED Quarterly Data | " + ...
    string(startYear) + "–" + string(endYear));

%% =========================================================
% TILE 1 - GDP GROWTH HISTORY
% ==========================================================

nexttile;

plot( ...
    DATA.observation_date, ...
    DATA.GDPGrowth, ...
    'LineWidth',1.3);

hold on;

yline(0,'--');

xline( ...
    datetime(2020,1,1), ...
    '--', ...
    '2020 Shock');

grid on;

title("Real GDP Growth History");

xlabel("Year");
ylabel("Annualized Growth (%)");

hold off;

%% =========================================================
% TILE 2 - INFLATION & UNEMPLOYMENT
% ==========================================================

nexttile;

yyaxis left

plot( ...
    DATA.observation_date, ...
    DATA.Inflation, ...
    'LineWidth',1.2);

ylabel("Inflation (%)");

yyaxis right

plot( ...
    DATA.observation_date, ...
    DATA.Unemployment, ...
    'LineWidth',1.2);

ylabel("Unemployment (%)");

grid on;

title("Inflation and Unemployment Dynamics");

xlabel("Year");

%% =========================================================
% TILE 3 - MODEL FIT EVOLUTION
% ==========================================================

nexttile;

fitNames = categorical( ...
    ["Baseline OLS","Dynamic Lag Model"]);

fitValues = [ ...
    baselineAdjR2, ...
    dynamicAdjR2];

bar( ...
    fitNames, ...
    fitValues);

grid on;

title("Improvement in Model Fit");

ylabel("Adjusted R-Squared");

ylim([0 max(fitValues)*1.20]);

text( ...
    1, ...
    baselineAdjR2, ...
    sprintf(' %.3f',baselineAdjR2), ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','bottom', ...
    'FontWeight','bold');

text( ...
    2, ...
    dynamicAdjR2, ...
    sprintf(' %.3f',dynamicAdjR2), ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','bottom', ...
    'FontWeight','bold');

%% =========================================================
% TILE 4 - OUT-OF-SAMPLE FORECASTING
% ==========================================================

nexttile;

plot( ...
    FORECASTS.Date, ...
    FORECASTS.ActualGDPGrowth, ...
    'LineWidth',1.5);

hold on;

plot( ...
    FORECASTS.Date, ...
    FORECASTS.ExpandingForecast, ...
    '--', ...
    'LineWidth',1.3);

plot( ...
    FORECASTS.Date, ...
    FORECASTS.NaiveForecast, ...
    ':', ...
    'LineWidth',1.3);

xline( ...
    datetime(2020,1,1), ...
    '--');

yline(0,'--');

grid on;

title("Out-of-Sample Forecast Comparison");

xlabel("Year");
ylabel("GDP Growth (%)");

legend( ...
    "Actual", ...
    "Expanding Window", ...
    "Naive Persistence", ...
    'Location','best');

hold off;

%% =========================================================
% TILE 5 - FORECAST ROBUSTNESS BY REGIME
% ==========================================================

nexttile;

regimeLabels = categorical( ...
    string(ROBUSTNESS.Regime));

bar( ...
    regimeLabels, ...
    [ROBUSTNESS.ModelMAE ROBUSTNESS.NaiveMAE]);

grid on;

title("Forecast MAE Across Economic Regimes");

ylabel("Mean Absolute Error");

legend( ...
    "Econometric Model", ...
    "Naive Benchmark", ...
    'Location','best');

xtickangle(20);

%% =========================================================
% TILE 6 - EXECUTIVE FINDINGS
% ==========================================================

ax = nexttile;

axis(ax,'off');

findingText = { ...
    '\bfEXECUTIVE FINDINGS'
    ' '
    sprintf('Sample: %d quarterly observations (%d–%d)', ...
        numObservations,startYear,endYear)
    ' '
    sprintf('Baseline OLS Adjusted R^2: %.2f%%', ...
        baselineAdjR2*100)
    sprintf('Dynamic Model Adjusted R^2: %.2f%%', ...
        dynamicAdjR2*100)
    ' '
    sprintf('Pre-COVID RMSE improvement vs naive: %.2f%%', ...
        preCovidRMSEImprovement)
    sprintf('Pre-COVID MAE improvement vs naive: %.2f%%', ...
        preCovidMAEImprovement)
    ' '
    sprintf('2020 Structural Break F-statistic: %.2f', ...
        chowF)
    sprintf('Structural Break p-value: %.4f', ...
        chowP)
    ' '
    sprintf('Best full-sample OOS RMSE model: %s', ...
        bestModelName)
    sprintf('Best full-sample OOS RMSE: %.2f', ...
        bestRMSE)
    ' '
    '\bfKey conclusion:'
    'Dynamic lag structures dramatically improve historical'
    'explanatory fit, but structural instability limits'
    'forecast generalization during major economic shocks.'
    };

text( ...
    0.02, ...
    0.98, ...
    findingText, ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'FontSize',11, ...
    'Interpreter','tex');

%% =========================================================
% SAVE FINAL DASHBOARD
% ==========================================================

exportgraphics( ...
    fig, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "39_Final_Research_Dashboard.png"), ...
    'Resolution',300);

%% Also export high-quality PDF for portfolio use

exportgraphics( ...
    fig, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "39_Final_Research_Dashboard.pdf"), ...
    'ContentType','vector');

end

%% =========================================================
% CREATE KPI SUMMARY TABLE
% ==========================================================

Metric = [ ...
    "Quarterly Observations"
    "Baseline R-Squared"
    "Baseline Adjusted R-Squared"
    "Dynamic R-Squared"
    "Dynamic Adjusted R-Squared"
    "Dynamic Model RMSE"
    "Pre-COVID RMSE Improvement vs Naive (%)"
    "Pre-COVID MAE Improvement vs Naive (%)"
    "Structural Break F-Statistic"
    "Structural Break p-value"
    "Best Full-Sample OOS RMSE"
    ];

Value = [ ...
    numObservations
    baselineR2
    baselineAdjR2
    dynamicR2
    dynamicAdjR2
    dynamicRMSE
    preCovidRMSEImprovement
    preCovidMAEImprovement
    chowF
    chowP
    bestRMSE
    ];

KPI_SUMMARY = table( ...
    Metric, ...
    Value);

writetable( ...
    KPI_SUMMARY, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Final_Project_KPIs.csv"));

%% =========================================================
% CREATE AUTOMATIC EXECUTIVE SUMMARY TEXT FILE
% ==========================================================

summaryFile = fullfile( ...
    cfg.ResultsDir, ...
    "Executive_Research_Summary.txt");

fid = fopen(summaryFile,'w');

fprintf(fid, ...
    "MATLAB MACROECONOMETRICS PROJECT\n");

fprintf(fid, ...
    "==============================================\n\n");

fprintf(fid, ...
    "DATA\n");

fprintf(fid, ...
    "%d quarterly U.S. macroeconomic observations from %d to %d.\n\n", ...
    numObservations,startYear,endYear);

fprintf(fid, ...
    "BASELINE MODEL\n");

fprintf(fid, ...
    "The contemporaneous OLS model achieved an R-squared of %.4f and an adjusted R-squared of %.4f.\n\n", ...
    baselineR2,baselineAdjR2);

fprintf(fid, ...
    "DYNAMIC MODEL\n");

fprintf(fid, ...
    "Introducing lagged macroeconomic relationships increased adjusted R-squared to %.4f, with an RMSE of %.4f.\n\n", ...
    dynamicAdjR2,dynamicRMSE);

fprintf(fid, ...
    "OUT-OF-SAMPLE FORECASTING\n");

fprintf(fid, ...
    "During the stable 2016-2019 pre-COVID period, the econometric model improved RMSE by %.2f percent and MAE by %.2f percent relative to naive persistence.\n\n", ...
    preCovidRMSEImprovement, ...
    preCovidMAEImprovement);

fprintf(fid, ...
    "STRUCTURAL BREAK\n");

fprintf(fid, ...
    "A structural-break test around 2020 produced an F-statistic of %.4f with p-value %.6f, indicating substantial parameter instability around the pandemic shock.\n\n", ...
    chowF,chowP);

fprintf(fid, ...
    "FINAL CONCLUSION\n");

fprintf(fid, ...
    "Dynamic macroeconomic relationships substantially improve historical explanatory fit, but strong structural instability limits forecast generalization during major regime changes. Adaptive expanding-window estimation improves some forecast characteristics but does not consistently outperform naive persistence over the full post-2016 test period.\n");

fclose(fid);

%% =========================================================
% DISPLAY FINAL RESULTS
% ==========================================================

disp(" ");
disp("==============================================");
disp(" FINAL PROJECT KPI SUMMARY");
disp("==============================================");

disp(KPI_SUMMARY);

disp(" ");
disp("==============================================");
disp(" PHASE 12 COMPLETE");
disp("==============================================");

disp("Final dashboard created:");
disp("figures/39_Final_Research_Dashboard.png");
disp("figures/39_Final_Research_Dashboard.pdf");

disp(" ");

disp("Final research outputs created:");
disp("results/Final_Project_KPIs.csv");
disp("results/Executive_Research_Summary.txt");

disp(" ");
disp("MATLAB ECONOMETRIC ANALYSIS PIPELINE COMPLETE.");

output = struct("KPISummary",KPI_SUMMARY, ...
    "BestModelName",bestModelName, ...
    "BestRMSE",bestRMSE, ...
    "ExecutiveSummaryFile",summaryFile, ...
    "ResultFiles",[ ...
        "Executive_Research_Summary.txt"; ...
        "Final_Project_KPIs.csv"], ...
    "FigureFiles",[ ...
        "39_Final_Research_Dashboard.pdf"; ...
        "39_Final_Research_Dashboard.png"]);
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
        error("macro:phase12:MissingDataInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end

function inputFile = resolveResultInput(cfg,fileName)
inputFile = fullfile(cfg.ResultsDir,fileName);
if ~isfile(inputFile)
    sourceFile = fullfile(cfg.ProjectRoot,"results",fileName);
    if ~isfile(sourceFile)
        error("macro:phase12:MissingResultInput", ...
            "Required result file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
