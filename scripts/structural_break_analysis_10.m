clc;
clear;
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

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    fullfile("data","Macroeconomic_Data_Quarterly.csv"));

disp("Dataset loaded successfully.");

%% ---------------------------------------------------------
% Build forecasting-style lagged model
% ----------------------------------------------------------

maxLag = 4;

GDP   = DATA.GDPGrowth;
INF   = DATA.Inflation;
UNEMP = DATA.Unemployment;
RATE  = DATA.InterestRate;
DATES = DATA.observation_date;

%% Response

Y = GDP(maxLag+1:end);
modelDates = DATES(maxLag+1:end);

%% Lagged GDP growth

GDP_L1 = GDP(maxLag:end-1);

%% Inflation lags

INF_L1 = INF(maxLag:end-1);
INF_L2 = INF(maxLag-1:end-2);
INF_L3 = INF(maxLag-2:end-3);
INF_L4 = INF(maxLag-3:end-4);

%% Unemployment lags

UNEMP_L1 = UNEMP(maxLag:end-1);
UNEMP_L2 = UNEMP(maxLag-1:end-2);
UNEMP_L3 = UNEMP(maxLag-2:end-3);
UNEMP_L4 = UNEMP(maxLag-3:end-4);

%% Interest-rate lags

RATE_L1 = RATE(maxLag:end-1);
RATE_L2 = RATE(maxLag-1:end-2);
RATE_L3 = RATE(maxLag-2:end-3);
RATE_L4 = RATE(maxLag-3:end-4);

%% Predictor matrix

X = [ ...
    ones(length(Y),1), ...
    GDP_L1, ...
    INF_L1, INF_L2, INF_L3, INF_L4, ...
    UNEMP_L1, UNEMP_L2, UNEMP_L3, UNEMP_L4, ...
    RATE_L1, RATE_L2, RATE_L3, RATE_L4];

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

betaPooled = X \ Y;

residualPooled = ...
    Y - X*betaPooled;

SSE_Pooled = ...
    sum(residualPooled.^2);

%% ---------------------------------------------------------
% Pre-COVID model
% ----------------------------------------------------------

betaPre = X_pre \ Y_pre;

residualPre = ...
    Y_pre - X_pre*betaPre;

SSE_Pre = ...
    sum(residualPre.^2);

%% ---------------------------------------------------------
% Post-COVID model
% ----------------------------------------------------------

betaPost = X_post \ Y_post;

residualPost = ...
    Y_post - X_post*betaPost;

SSE_Post = ...
    sum(residualPost.^2);

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

YhatPre = X_pre * betaPre;
YhatPost = X_post * betaPost;

SST_Pre = ...
    sum((Y_pre - mean(Y_pre)).^2);

SST_Post = ...
    sum((Y_post - mean(Y_post)).^2);

R2_Pre = ...
    1 - SSE_Pre/SST_Pre;

R2_Post = ...
    1 - SSE_Post/SST_Post;

AdjR2_Pre = ...
    1 - ((SSE_Pre/(n1-k)) / ...
    (SST_Pre/(n1-1)));

AdjR2_Post = ...
    1 - ((SSE_Post/(n2-k)) / ...
    (SST_Post/(n2-1)));

RMSE_Pre = ...
    sqrt(mean((Y_pre-YhatPre).^2));

RMSE_Post = ...
    sqrt(mean((Y_post-YhatPost).^2));

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
        "results", ...
        "Structural_Break_Regime_Summary.csv"));

%% ---------------------------------------------------------
% Coefficient comparison
% ----------------------------------------------------------

Variable = [ ...
    "Intercept"
    "GDPGrowth_L1"

    "Inflation_L1"
    "Inflation_L2"
    "Inflation_L3"
    "Inflation_L4"

    "Unemployment_L1"
    "Unemployment_L2"
    "Unemployment_L3"
    "Unemployment_L4"

    "InterestRate_L1"
    "InterestRate_L2"
    "InterestRate_L3"
    "InterestRate_L4"
    ];

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
        "results", ...
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
        "results", ...
        "Structural_Break_Test.csv"));

%% ---------------------------------------------------------
% Figure 30 - Coefficient comparison
% ----------------------------------------------------------

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
        "figures", ...
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
        "figures", ...
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
        "figures", ...
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
        "figures", ...
        "33_GDP_Growth_Structural_Break.png"), ...
    'Resolution',300);

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