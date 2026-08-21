function output = structural_break_analysis_10(cfg)
%STRUCTURAL_BREAK_ANALYSIS_10 Phase 10 - Fixed-date Chow-style test.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 10 - Structural Break Analysis
%
% Objective:
% Test whether the relationship between GDP growth and lagged
% macroeconomic predictors changed around the COVID-19 shock.

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 10: Structural Break Analysis");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Dataset loaded successfully.");

%% ---------------------------------------------------------
% Build forecasting-style lagged model
% ----------------------------------------------------------

design = macro.buildForecastDesign(DATA);
Y = design.Y;
modelDates = design.Dates;
X = design.X;

%% ---------------------------------------------------------
% Define structural break
% ----------------------------------------------------------

breakDate = datetime(2020,1,1);

preIndex  = modelDates < breakDate;
postIndex = modelDates >= breakDate;

X_pre  = X(preIndex,:);
Y_pre  = Y(preIndex);

X_post = X(postIndex,:);
Y_post = Y(postIndex);

fprintf("\nPre-break observations: %d\n", length(Y_pre));
fprintf("Post-break observations: %d\n", length(Y_post));

%% ---------------------------------------------------------
% Pooled model
% ----------------------------------------------------------

POOLED_MODEL = macro.estimateOLS(X,Y,CovarianceSolver="inverse");
betaPooled = POOLED_MODEL.Coefficients;
residualPooled = POOLED_MODEL.Residuals;
SSE_Pooled = POOLED_MODEL.SSE;

%% ---------------------------------------------------------
% Pre-COVID model
% ----------------------------------------------------------

PRE_MODEL = macro.estimateOLS(X_pre,Y_pre,CovarianceSolver="inverse");
betaPre = PRE_MODEL.Coefficients;
residualPre = PRE_MODEL.Residuals;
SSE_Pre = PRE_MODEL.SSE;

%% ---------------------------------------------------------
% Post-COVID model
% ----------------------------------------------------------

POST_MODEL = macro.estimateOLS(X_post,Y_post,CovarianceSolver="inverse");
betaPost = POST_MODEL.Coefficients;
residualPost = POST_MODEL.Residuals;
SSE_Post = POST_MODEL.SSE;

%% ---------------------------------------------------------
% Chow-style structural-break F statistic
% ----------------------------------------------------------

k = size(X,2);

n1 = length(Y_pre);
n2 = length(Y_post);

numerator = ...
    (SSE_Pooled - ...
    (SSE_Pre + SSE_Post)) / k;

denominator = ...
    (SSE_Pre + SSE_Post) / ...
    (n1 + n2 - 2*k);

ChowF = numerator / denominator;

%% Approximate F-test p-value if fcdf is available

if exist('fcdf','file') == 2

    ChowPValue = ...
        1 - fcdf( ...
        ChowF, ...
        k, ...
        n1+n2-2*k);

else

    ChowPValue = NaN;

end

disp(" ");
disp("==============================================");
disp(" STRUCTURAL BREAK TEST");
disp("==============================================");

fprintf("Break Date: %s\n",string(breakDate));
fprintf("Chow F-Statistic: %.4f\n",ChowF);
fprintf("Approximate p-value: %.6f\n",ChowPValue);

%% ---------------------------------------------------------
% Calculate model fit by regime
% ----------------------------------------------------------

YhatPre = PRE_MODEL.Fitted;
YhatPost = POST_MODEL.Fitted;
SST_Pre = PRE_MODEL.SST;
SST_Post = POST_MODEL.SST;
R2_Pre = PRE_MODEL.RSquared;
R2_Post = POST_MODEL.RSquared;
AdjR2_Pre = PRE_MODEL.AdjustedRSquared;
AdjR2_Post = POST_MODEL.AdjustedRSquared;
RMSE_Pre = PRE_MODEL.RMSE;
RMSE_Post = POST_MODEL.RMSE;

%% Save regime summary

REGIME_SUMMARY = table( ...
    ["Pre-COVID";"Post-COVID"], ...
    [n1;n2], ...
    [R2_Pre;R2_Post], ...
    [AdjR2_Pre;AdjR2_Post], ...
    [RMSE_Pre;RMSE_Post], ...
    'VariableNames', ...
    {'Regime', ...
     'Observations', ...
     'RSquared', ...
     'AdjustedRSquared', ...
     'RMSE'});

disp(" ");
disp("==============================================");
disp(" REGIME MODEL PERFORMANCE");
disp("==============================================");

disp(REGIME_SUMMARY);

writetable( ...
    REGIME_SUMMARY, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Structural_Break_Regime_Summary.csv"));

%% ---------------------------------------------------------
% Coefficient comparison
% ----------------------------------------------------------

Variable = design.VariableNames';

COEFFICIENT_COMPARISON = table( ...
    Variable, ...
    betaPre, ...
    betaPost, ...
    betaPost-betaPre, ...
    'VariableNames', ...
    {'Variable', ...
     'PreCOVID', ...
     'PostCOVID', ...
     'CoefficientChange'});

disp(" ");
disp("==============================================");
disp(" PRE vs POST COVID COEFFICIENTS");
disp("==============================================");

disp(COEFFICIENT_COMPARISON);

writetable( ...
    COEFFICIENT_COMPARISON, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Structural_Break_Coefficients.csv"));

%% Save structural-break test summary

BREAK_SUMMARY = table( ...
    breakDate, ...
    ChowF, ...
    ChowPValue, ...
    'VariableNames', ...
    {'BreakDate', ...
     'ChowFStatistic', ...
     'ApproxPValue'});

writetable( ...
    BREAK_SUMMARY, ...
    fullfile( ...
        cfg.ResultsDir, ...
        "Structural_Break_Test.csv"));

%% ---------------------------------------------------------
% Figure 30 - Coefficient comparison
% ----------------------------------------------------------

if cfg.GenerateFigures

fig1 = figure( ...
    'Position',[100 100 1350 700]);

coefficientData = ...
    [betaPre(2:end) betaPost(2:end)];

bar( ...
    categorical(Variable(2:end)), ...
    coefficientData);

grid on;

title("Macroeconomic Coefficients Before and After 2020");

subtitle( ...
    "Structural Change in Lagged GDP-Growth Relationships");

ylabel("Estimated Coefficient");

legend( ...
    "Pre-COVID", ...
    "Post-COVID", ...
    'Location','best');

xtickangle(45);

exportgraphics( ...
    fig1, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "30_Pre_vs_Post_COVID_Coefficients.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 31 - Absolute coefficient change
% ----------------------------------------------------------

fig2 = figure( ...
    'Position',[100 100 1300 650]);

coefficientChange = ...
    abs(betaPost(2:end)-betaPre(2:end));

bar( ...
    categorical(Variable(2:end)), ...
    coefficientChange);

grid on;

title("Magnitude of Structural Coefficient Change");

subtitle( ...
    "Absolute Change Between Pre- and Post-2020 Estimates");

ylabel("Absolute Coefficient Change");

xtickangle(45);

exportgraphics( ...
    fig2, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "31_Structural_Coefficient_Change.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 32 - Regime model fit
% ----------------------------------------------------------

fig3 = figure;

bar( ...
    categorical(["Pre-COVID","Post-COVID"]), ...
    [AdjR2_Pre AdjR2_Post]);

grid on;

title("Model Fit Across Economic Regimes");

ylabel("Adjusted R-Squared");

exportgraphics( ...
    fig3, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "32_Regime_Adjusted_R2.png"), ...
    'Resolution',300);

%% ---------------------------------------------------------
% Figure 33 - GDP growth with structural-break marker
% ----------------------------------------------------------

fig4 = figure( ...
    'Position',[100 100 1250 650]);

plot( ...
    modelDates, ...
    Y, ...
    'LineWidth',1.4);

hold on;

xline( ...
    breakDate, ...
    '--', ...
    '2020 Structural Break', ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("U.S. GDP Growth and the 2020 Structural Break");

xlabel("Year");
ylabel("Annualized GDP Growth (%)");

hold off;

exportgraphics( ...
    fig4, ...
    fullfile( ...
        cfg.FiguresDir, ...
        "33_GDP_Growth_Structural_Break.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 10 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/Structural_Break_Test.csv");
disp("results/Structural_Break_Regime_Summary.csv");
disp("results/Structural_Break_Coefficients.csv");

disp(" ");

disp("Figures saved:");
disp("figures/30_Pre_vs_Post_COVID_Coefficients.png");
disp("figures/31_Structural_Coefficient_Change.png");
disp("figures/32_Regime_Adjusted_R2.png");
disp("figures/33_GDP_Growth_Structural_Break.png");

output = struct("Design",design, ...
    "BreakDate",breakDate, ...
    "PreIndex",preIndex, ...
    "PostIndex",postIndex, ...
    "PooledModel",POOLED_MODEL, ...
    "PreModel",PRE_MODEL, ...
    "PostModel",POST_MODEL, ...
    "RegimeSummary",REGIME_SUMMARY, ...
    "CoefficientComparison",COEFFICIENT_COMPARISON, ...
    "BreakSummary",BREAK_SUMMARY, ...
    "FigureFiles",[ ...
        "30_Pre_vs_Post_COVID_Coefficients.png"; ...
        "31_Structural_Coefficient_Change.png"; ...
        "32_Regime_Adjusted_R2.png"; ...
        "33_GDP_Growth_Structural_Break.png"]);
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
        error("macro:phase10:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
