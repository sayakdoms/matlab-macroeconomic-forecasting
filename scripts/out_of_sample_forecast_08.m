clc;
clear;
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

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    fullfile("data","Macroeconomic_Data_Quarterly.csv"));

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

maxLag = 4;

%% Raw series

GDP = DATA.GDPGrowth;
INF = DATA.Inflation;
UNEMP = DATA.Unemployment;
RATE = DATA.InterestRate;
DATES = DATA.observation_date;

%% Build forecast-ready dataset

Y = GDP(maxLag+1:end);
forecastDates = DATES(maxLag+1:end);

% GDP lag
GDP_L1 = GDP(maxLag:end-1);

% Inflation lags
INF_L1 = INF(maxLag:end-1);
INF_L2 = INF(maxLag-1:end-2);
INF_L3 = INF(maxLag-2:end-3);
INF_L4 = INF(maxLag-3:end-4);

% Unemployment lags
UNEMP_L1 = UNEMP(maxLag:end-1);
UNEMP_L2 = UNEMP(maxLag-1:end-2);
UNEMP_L3 = UNEMP(maxLag-2:end-3);
UNEMP_L4 = UNEMP(maxLag-3:end-4);

% Interest rate lags
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

beta = X_train \ Y_train;

%% Generate out-of-sample predictions

Y_forecast = X_test * beta;

forecastErrors = Y_test - Y_forecast;

%% ---------------------------------------------------------
% Forecast performance metrics
% ----------------------------------------------------------

RMSE = sqrt(mean(forecastErrors.^2));

MAE = mean(abs(forecastErrors));

ForecastCorrelation = corr(Y_test,Y_forecast);

%% Directional accuracy

actualDirection = sign(Y_test);
forecastDirection = sign(Y_forecast);

DirectionalAccuracy = ...
    mean(actualDirection == forecastDirection) * 100;

%% ---------------------------------------------------------
% Naive benchmark
%
% Forecast GDP growth using previous quarter's GDP growth
% ----------------------------------------------------------

naiveForecast = GDP_L1(testIndex);

naiveErrors = Y_test - naiveForecast;

NaiveRMSE = sqrt(mean(naiveErrors.^2));

NaiveMAE = mean(abs(naiveErrors));

%% Improvement relative to naive forecast

RMSEImprovement = ...
    ((NaiveRMSE - RMSE) / NaiveRMSE) * 100;

MAEImprovement = ...
    ((NaiveMAE - MAE) / NaiveMAE) * 100;

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

FORECAST_COEFFICIENTS = table( ...
    Variable, ...
    beta, ...
    'VariableNames', ...
    {'Variable','Coefficient'});

writetable( ...
    FORECAST_COEFFICIENTS, ...
    fullfile( ...
        "results", ...
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
        "results", ...
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
        "results", ...
        "Out_of_Sample_Forecasts.csv"));

%% ---------------------------------------------------------
% Figure 23 - Actual vs Econometric Forecast
% ----------------------------------------------------------

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
        "figures", ...
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
        "figures", ...
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
        "figures", ...
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
        "figures", ...
        "26_Forecast_RMSE_Comparison.png"), ...
    'Resolution',300);

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
