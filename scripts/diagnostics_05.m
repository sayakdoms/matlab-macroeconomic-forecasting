function output = diagnostics_05(cfg)
%DIAGNOSTICS_05 Phase 5 - Baseline OLS diagnostic analysis.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 5 - Regression Diagnostics

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 5: OLS Diagnostic Analysis");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

%% Re-estimate baseline OLS model

Y = DATA.GDPGrowth;

Inflation    = DATA.Inflation;
Unemployment = DATA.Unemployment;
InterestRate = DATA.InterestRate;

n = length(Y);

X = [ ...
    ones(n,1), ...
    Inflation, ...
    Unemployment, ...
    InterestRate];

MODEL = macro.estimateOLS(X,Y,CovarianceSolver="inverse");

beta = MODEL.Coefficients;
Y_hat = MODEL.Fitted;
residuals = MODEL.Residuals;

%% =========================================================
% 1. DURBIN-WATSON STATISTIC
% ==========================================================

DW = sum(diff(residuals).^2) / ...
     sum(residuals.^2);

fprintf("\nDurbin-Watson Statistic: %.4f\n",DW);

%% =========================================================
% 2. VARIANCE INFLATION FACTOR
% ==========================================================

Predictors = [ ...
    Inflation, ...
    Unemployment, ...
    InterestRate];

predictorNames = [ ...
    "Inflation"; ...
    "Unemployment"; ...
    "Interest Rate"];

VIF = zeros(3,1);

for j = 1:3

    yj = Predictors(:,j);

    otherIndex = setdiff(1:3,j);

    Xj = [ ...
        ones(n,1), ...
        Predictors(:,otherIndex)];

    auxiliaryModel = macro.estimateOLS(Xj,yj, ...
        CovarianceSolver="inverse");

    R2_j = auxiliaryModel.RSquared;

    VIF(j) = 1 / (1 - R2_j);

end

VIF_TABLE = table( ...
    predictorNames, ...
    VIF, ...
    'VariableNames', ...
    {'Predictor','VIF'});

disp(" ");
disp("==============================================");
disp(" VARIANCE INFLATION FACTORS");
disp("==============================================");

disp(VIF_TABLE);

writetable( ...
    VIF_TABLE, ...
    fullfile(cfg.ResultsDir,"VIF_Results.csv"));

%% =========================================================
% 3. NORMALITY TEST
% ==========================================================

if exist('jbtest','file') == 2

    [JBReject,JBpValue] = jbtest(residuals);

else

    warning("macro:diagnostics:JBTestUnavailable", ...
        "jbtest is unavailable; Jarque-Bera outputs are set to NaN.");
    JBReject = NaN;
    JBpValue = NaN;

end

fprintf("\nJarque-Bera Reject Normality: %.0f\n",JBReject);
fprintf("Jarque-Bera p-value: %.6f\n",JBpValue);

%% =========================================================
% 4. ARCH TEST
% ==========================================================

if exist('archtest','file') == 2

    [ARCHReject,ARCHpValue] = ...
        archtest(residuals);

else

    warning("macro:diagnostics:ARCHTestUnavailable", ...
        "archtest is unavailable; ARCH outputs are set to NaN.");
    ARCHReject = NaN;
    ARCHpValue = NaN;

end

fprintf("\nARCH Reject Homoscedasticity: %.0f\n",ARCHReject);
fprintf("ARCH p-value: %.6f\n",ARCHpValue);

%% =========================================================
% 5. RESIDUAL AUTOCORRELATION
% ==========================================================

maxLag = 12;

acfValues = zeros(maxLag+1,1);

residualCentered = residuals - mean(residuals);

denominator = sum(residualCentered.^2);

for lag = 0:maxLag

    numerator = ...
        sum( ...
        residualCentered(1:end-lag) .* ...
        residualCentered(1+lag:end));

    acfValues(lag+1) = ...
        numerator / denominator;

end

%% Figure 11 - Residual Autocorrelation

residualStd = std(residuals);
standardizedResiduals = residuals / residualStd;

if cfg.GenerateFigures

fig1 = figure;

stem(0:maxLag,acfValues,'filled');

hold on;

confidenceLimit = 1.96 / sqrt(n);

yline(confidenceLimit,'--');
yline(-confidenceLimit,'--');

grid on;

title("Residual Autocorrelation Function");

subtitle("Baseline OLS Model");

xlabel("Lag (Quarters)");
ylabel("Autocorrelation");

hold off;

exportgraphics( ...
    fig1, ...
    fullfile(cfg.FiguresDir,"11_Residual_ACF.png"), ...
    'Resolution',300);

%% =========================================================
% 6. RESIDUAL VS FITTED
% ==========================================================

fig2 = figure;

scatter( ...
    Y_hat, ...
    residuals, ...
    35, ...
    'filled');

hold on;

yline(0,'--');

grid on;

title("Residuals vs Fitted GDP Growth");

xlabel("Predicted GDP Growth (%)");
ylabel("Residual");

hold off;

exportgraphics( ...
    fig2, ...
    fullfile(cfg.FiguresDir,"12_Residual_vs_Fitted.png"), ...
    'Resolution',300);

%% =========================================================
% 7. Q-Q PLOT
% ==========================================================

fig3 = figure;

if exist('qqplot','file') == 2

    qqplot(residuals);

    title("Q-Q Plot of OLS Residuals");

else

    warning("macro:diagnostics:QQPlotUnavailable", ...
        "qqplot is unavailable; using the existing manual Q-Q fallback.");
    sortedResiduals = sort(residuals);

    probabilities = ...
        ((1:n)' - 0.5) / n;

    theoreticalNormal = ...
        -sqrt(2) * erfcinv(2*probabilities);

    scatter( ...
        theoreticalNormal, ...
        sortedResiduals, ...
        30, ...
        'filled');

    hold on;

    p = polyfit( ...
        theoreticalNormal, ...
        sortedResiduals, ...
        1);

    fittedLine = polyval( ...
        p, ...
        theoreticalNormal);

    plot( ...
        theoreticalNormal, ...
        fittedLine, ...
        '--', ...
        'LineWidth',1.3);

    grid on;

    title("Q-Q Plot of OLS Residuals");

    xlabel("Theoretical Normal Quantiles");
    ylabel("Observed Residual Quantiles");

    hold off;

end

exportgraphics( ...
    fig3, ...
    fullfile(cfg.FiguresDir,"13_Residual_QQ_Plot.png"), ...
    'Resolution',300);

%% =========================================================
% 8. STANDARDIZED RESIDUALS
% ==========================================================

fig4 = figure;

plot( ...
    DATA.observation_date, ...
    standardizedResiduals, ...
    'LineWidth',1.2);

hold on;

yline(0,'--');
yline(2,'--');
yline(-2,'--');

grid on;

title("Standardized OLS Residuals Over Time");

subtitle("Potential Extreme Observations Beyond ±2");

xlabel("Year");
ylabel("Standardized Residual");

hold off;

exportgraphics( ...
    fig4, ...
    fullfile(cfg.FiguresDir,"14_Standardized_Residuals.png"), ...
    'Resolution',300);

end

%% =========================================================
% 9. DIAGNOSTICS SUMMARY
% ==========================================================

MaxVIF = max(VIF);

DIAGNOSTIC_SUMMARY = table( ...
    DW, ...
    MaxVIF, ...
    JBReject, ...
    JBpValue, ...
    ARCHReject, ...
    ARCHpValue, ...
    'VariableNames', ...
    {'DurbinWatson', ...
     'MaximumVIF', ...
     'JBRejectNormality', ...
     'JBPValue', ...
     'ARCHRejectHomoscedasticity', ...
     'ARCHPValue'});

disp(" ");
disp("==============================================");
disp(" DIAGNOSTIC SUMMARY");
disp("==============================================");

disp(DIAGNOSTIC_SUMMARY);

writetable( ...
    DIAGNOSTIC_SUMMARY, ...
    fullfile(cfg.ResultsDir,"Diagnostic_Summary.csv"));

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 5 COMPLETE");
disp("==============================================");

disp("Results saved:");
disp("results/VIF_Results.csv");
disp("results/Diagnostic_Summary.csv");

disp(" ");

disp("Figures saved:");
disp("figures/11_Residual_ACF.png");
disp("figures/12_Residual_vs_Fitted.png");
disp("figures/13_Residual_QQ_Plot.png");
disp("figures/14_Standardized_Residuals.png");

output = struct("Model",MODEL, ...
    "VIFResults",VIF_TABLE, ...
    "DiagnosticSummary",DIAGNOSTIC_SUMMARY, ...
    "ACFValues",acfValues, ...
    "StandardizedResiduals",standardizedResiduals, ...
    "FigureFiles",[ ...
        "11_Residual_ACF.png"; ...
        "12_Residual_vs_Fitted.png"; ...
        "13_Residual_QQ_Plot.png"; ...
        "14_Standardized_Residuals.png"]);
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
        error("macro:phase05:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
