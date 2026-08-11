clc;
clear;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 1 - Import real macroeconomic data from FRED

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 1: FRED Data Import");
disp("==============================================");

%% Define FRED CSV sources

gdpURL = ...
    "https://fred.stlouisfed.org/graph/fredgraph.csv?id=GDPC1";

unemploymentURL = ...
    "https://fred.stlouisfed.org/graph/fredgraph.csv?id=UNRATE";

cpiURL = ...
    "https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCSL";

interestURL = ...
    "https://fred.stlouisfed.org/graph/fredgraph.csv?id=FEDFUNDS";

%% Import datasets

disp("Downloading Real GDP...");
GDP = readtable(gdpURL);

disp("Downloading Unemployment Rate...");
UNEMP = readtable(unemploymentURL);

disp("Downloading Consumer Price Index...");
CPI = readtable(cpiURL);

disp("Downloading Federal Funds Rate...");
RATE = readtable(interestURL);

%% Preview imported data

disp(" ");
disp("GDP Preview:");
disp(head(GDP));

disp("Unemployment Preview:");
disp(head(UNEMP));

disp("CPI Preview:");
disp(head(CPI));

disp("Interest Rate Preview:");
disp(head(RATE));

%% Project status

disp("==============================================");
disp(" DATA IMPORT COMPLETE");
disp("==============================================");
%% Save raw datasets locally

writetable(GDP, fullfile("data","GDP_raw.csv"));
writetable(UNEMP, fullfile("data","Unemployment_raw.csv"));
writetable(CPI, fullfile("data","CPI_raw.csv"));
writetable(RATE, fullfile("data","InterestRate_raw.csv"));

disp("Raw datasets saved successfully in the data folder.");