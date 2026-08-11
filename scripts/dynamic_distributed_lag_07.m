clc;
clear;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 7 - Dynamic Distributed Lag Model

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 7: Dynamic Distributed Lag Regression");
disp("==============================================");

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    fullfile("data","Macroeconomic_Data_Quarterly.csv"));

disp("Dataset loaded successfully.");

%% Maximum lag

maxLag = 4;

%% Create common estimation sample

Y_full = DATA.GDPGrowth;
INF_full = DATA.Inflation;
UNEMP_full = DATA.Unemployment;
RATE_full = DATA.InterestRate;

nTotal = height(DATA);

%% Current GDP growth begins after four lagged quarters

Y = Y_full(maxLag+1:end);

dates = DATA.observation_date(maxLag+1:end);

%% Lagged GDP growth

GDP_L1 = Y_full(maxLag:end-1);

%% Create inflation lags

INF_0 = INF_full(maxLag+1:end);
INF_1 = INF_full(maxLag:end-1);
INF_2 = INF_full(maxLag-1:end-2);
INF_3 = INF_full(maxLag-2:end-3);
INF_4 = INF_full(maxLag-3:end-4);

%% Create unemployment lags

UNEMP_0 = UNEMP_full(maxLag+1:end);
UNEMP_1 = UNEMP_full(maxLag:end-1);
UNEMP_2 = UNEMP_full(maxLag-1:end-2);
UNEMP_3 = UNEMP_full(maxLag-2:end-3);
UNEMP_4 = UNEMP_full(maxLag-3:end-4);

%% Create interest-rate lags

RATE_0 = RATE_full(maxLag+1:end);
RATE_1 = RATE_full(maxLag:end-1);
RATE_2 = RATE_full(maxLag-1:end-2);
RATE_3 = RATE_full(maxLag-2:end-3);
RATE_4 = RATE_full(maxLag-3:end-4);

%% Build design matrix

X = [ ...
    ones(length(Y),1), ...
    GDP_L1, ...
    INF_0, INF_1, INF_2, INF_3, INF_4, ...
    UNEMP_0, UNEMP_1, UNEMP_2, UNEMP_3, UNEMP_4, ...
    RATE_0, RATE_1, RATE_2, RATE_3, RATE_4];

%% Estimate model

beta = X \ Y;

Y_hat = X * beta;

residuals = Y - Y_hat;

%% Model statistics

n = length(Y);
k = size(X,2);

SSE = sum(residuals.^2);
SST = sum((Y - mean(Y)).^2);
SSR = SST - SSE;

R2 = 1 - SSE/SST;

AdjustedR2 = ...
    1 - ((SSE/(n-k)) / ...
    (SST/(n-1)));

RMSE = sqrt(mean(residuals.^2));

FStatistic = ...
    (SSR/(k-1)) / ...
    (SSE/(n-k));

%% Information criteria

logLik = ...
    -n/2 * ...
    (log(2*pi) + 1 + log(SSE/n));

AIC = 2*k - 2*logLik;

BIC = log(n)*k - 2*logLik;

%% Standard errors

sigma2 = SSE/(n-k);

VarBeta = ...
    sigma2 * pinv(X' * X);

SE = sqrt(diag(VarBeta));

TStatistic = beta ./ SE;

ApproxPValue = ...
    erfc(abs(TStatistic)/sqrt(2));

%% Variable names

Variable = [ ...
    "Intercept"
    "GDPGrowth_L1"

    "Inflation_0"
    "Inflation_L1"
    "Inflation_L2"
    "Inflation_L3"
    "Inflation_L4"

    "Unemployment_0"
    "Unemployment_L1"
    "Unemployment_L2"
    "Unemployment_L3"
    "Unemployment_L4"

    "InterestRate_0"
    "InterestRate_L1"
    "InterestRate_L2"
    "InterestRate_L3"
    "InterestRate_L4"
    ];

%% Coefficient table

DYNAMIC_RESULTS = table( ...
    Variable, ...
    beta, ...
    SE, ...
    TStatistic, ...
    ApproxPValue, ...
    'VariableNames', ...
    {'Variable', ...
     'Coefficient', ...
     'StandardError', ...
     'TStatistic', ...
     'ApproxPValue'});

disp(" ");
disp("==============================================");
disp(" DYNAMIC MODEL COEFFICIENTS");
disp("==============================================");

disp(DYNAMIC_RESULTS);

%% Display model performance

fprintf("\nObservations: %d\n",n);
fprintf("R-Squared: %.4f\n",R2);
fprintf("Adjusted R-Squared: %.4f\n",AdjustedR2);
fprintf("RMSE: %.4f\n",RMSE);
fprintf("F-Statistic: %.4f\n",FStatistic);
fprintf("AIC: %.2f\n",AIC);
fprintf("BIC: %.2f\n",BIC);

%% Save model coefficients

writetable( ...
    DYNAMIC_RESULTS, ...
    fullfile( ...
        "results", ...
        "Dynamic_Distributed_Lag_Results.csv"));

%% Model summary

MODEL_SUMMARY = table( ...
    n, ...
    R2, ...
    AdjustedR2, ...
    RMSE, ...
    FStatistic, ...
    AIC, ...
    BIC, ...
    'VariableNames', ...
    {'Observations', ...
     'RSquared', ...
     'AdjustedRSquared', ...
     'RMSE', ...
     'FStatistic', ...
     'AIC', ...
     'BIC'});

writetable( ...
    MODEL_SUMMARY, ...
    fullfile( ...
        "results", ...
        "Dynamic_Model_Summary.csv"));

%% Prediction output

PREDICTIONS = table( ...
    dates, ...
    Y, ...
    Y_hat, ...
    residuals, ...
    'VariableNames', ...
    {'Date', ...
     'ActualGDPGrowth', ...
     'PredictedGDPGrowth', ...
     'Residual'});

writetable( ...
    PREDICTIONS, ...
    fullfile( ...
        "results", ...
        "Dynamic_Model_Predictions.csv"));

%% Figure 19 - Actual vs predicted

fig1 = figure( ...
    'Position',[100 100 1200 650]);

plot( ...
    dates, ...
    Y, ...
    'LineWidth',1.5);

hold on;

plot( ...
    dates, ...
    Y_hat, ...
    '--', ...
    'LineWidth',1.6);

yline(0,'--');

grid on;

title( ...
    "Dynamic Distributed-Lag Model");

subtitle( ...
    "Actual vs Predicted U.S. Real GDP Growth");

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
        "figures", ...
        "19_Dynamic_Model_Actual_vs_Predicted.png"), ...
    'Resolution',300);

%% Figure 20 - Inflation lag effects

fig2 = figure;

inflationEffects = ...
    beta(3:7);

plot( ...
    0:4, ...
    inflationEffects, ...
    '-o', ...
    'LineWidth',1.8);

yline(0,'--');

grid on;

title("Dynamic Response: Inflation Coefficients");

xlabel("Lag (Quarters)");
ylabel("Estimated Coefficient");

exportgraphics( ...
    fig2, ...
    fullfile( ...
        "figures", ...
        "20_Inflation_Lag_Effects.png"), ...
    'Resolution',300);

%% Figure 21 - Unemployment lag effects

fig3 = figure;

unemploymentEffects = ...
    beta(8:12);

plot( ...
    0:4, ...
    unemploymentEffects, ...
    '-o', ...
    'LineWidth',1.8);

yline(0,'--');

grid on;

title("Dynamic Response: Unemployment Coefficients");

xlabel("Lag (Quarters)");
ylabel("Estimated Coefficient");

exportgraphics( ...
    fig3, ...
    fullfile( ...
        "figures", ...
        "21_Unemployment_Lag_Effects.png"), ...
    'Resolution',300);

%% Figure 22 - Interest rate lag effects

fig4 = figure;

rateEffects = ...
    beta(13:17);

plot( ...
    0:4, ...
    rateEffects, ...
    '-o', ...
    'LineWidth',1.8);

yline(0,'--');

grid on;

title("Dynamic Response: Interest Rate Coefficients");

xlabel("Lag (Quarters)");
ylabel("Estimated Coefficient");

exportgraphics( ...
    fig4, ...
    fullfile( ...
        "figures", ...
        "22_Interest_Rate_Lag_Effects.png"), ...
    'Resolution',300);

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 7 COMPLETE");
disp("==============================================");

disp("Dynamic regression completed successfully.");
disp("Outputs saved to results and figures folders.");