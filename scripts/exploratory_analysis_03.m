function output = exploratory_analysis_03(cfg)
%EXPLORATORY_ANALYSIS_03 Phase 3 - Exploratory data analysis.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 3 - Exploratory Data Analysis

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 3: Exploratory Analysis");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load cleaned quarterly dataset

DATA = readtimetable( ...
    resolveDataInput(cfg,"Macroeconomic_Data_Quarterly.csv"));

DATA = macro.validateQuarterlyData(DATA);

disp("Clean quarterly dataset loaded successfully.");

%% Display variable names

disp(" ");
disp("Variables available in dataset:");
disp(DATA.Properties.VariableNames');

%% Descriptive statistics

variables = [ ...
    DATA.GDPGrowth, ...
    DATA.Inflation, ...
    DATA.Unemployment, ...
    DATA.InterestRate];

variableNames = [ ...
    "GDP Growth", ...
    "Inflation", ...
    "Unemployment", ...
    "Interest Rate"];

MeanValue = mean(variables,1)';
StdDev    = std(variables,0,1)';
Minimum   = min(variables,[],1)';
Maximum   = max(variables,[],1)';

DESCRIPTIVE = table( ...
    variableNames', ...
    MeanValue, ...
    StdDev, ...
    Minimum, ...
    Maximum, ...
    'VariableNames', ...
    {'Variable','Mean','StdDev','Minimum','Maximum'});

disp(" ");
disp("==============================================");
disp(" DESCRIPTIVE STATISTICS");
disp("==============================================");

disp(DESCRIPTIVE);

%% Save descriptive statistics

writetable( ...
    DESCRIPTIVE, ...
    fullfile(cfg.ResultsDir,"Descriptive_Statistics.csv"));

disp("Descriptive statistics saved.");

%% Correlation matrix

CORR = corrcoef(variables);

CORR_TABLE = array2table( ...
    CORR, ...
    'VariableNames', ...
    {'GDPGrowth','Inflation','Unemployment','InterestRate'}, ...
    'RowNames', ...
    {'GDPGrowth','Inflation','Unemployment','InterestRate'});

disp(" ");
disp("==============================================");
disp(" CORRELATION MATRIX");
disp("==============================================");

disp(CORR_TABLE);

%% Save correlation matrix

writetable( ...
    CORR_TABLE, ...
    fullfile(cfg.ResultsDir,"Correlation_Matrix.csv"), ...
    'WriteRowNames',true);

disp("Correlation matrix saved.");

%% Figure 1 - GDP Growth

if cfg.GenerateFigures

fig1 = figure;

plot( ...
    DATA.observation_date, ...
    DATA.GDPGrowth, ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("U.S. Real GDP Growth");
subtitle("Annualized Quarter-to-Quarter Growth");

xlabel("Year");
ylabel("GDP Growth (%)");

exportgraphics( ...
    fig1, ...
    fullfile(cfg.FiguresDir,"01_GDP_Growth.png"), ...
    'Resolution',300);

%% Figure 2 - Inflation

fig2 = figure;

plot( ...
    DATA.observation_date, ...
    DATA.Inflation, ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("U.S. Inflation");
subtitle("Annualized Quarter-to-Quarter CPI Inflation");

xlabel("Year");
ylabel("Inflation (%)");

exportgraphics( ...
    fig2, ...
    fullfile(cfg.FiguresDir,"02_Inflation.png"), ...
    'Resolution',300);

%% Figure 3 - Unemployment

fig3 = figure;

plot( ...
    DATA.observation_date, ...
    DATA.Unemployment, ...
    'LineWidth',1.5);

grid on;

title("U.S. Unemployment Rate");
subtitle("Quarterly Average");

xlabel("Year");
ylabel("Unemployment Rate (%)");

exportgraphics( ...
    fig3, ...
    fullfile(cfg.FiguresDir,"03_Unemployment.png"), ...
    'Resolution',300);

%% Figure 4 - Federal Funds Rate

fig4 = figure;

plot( ...
    DATA.observation_date, ...
    DATA.InterestRate, ...
    'LineWidth',1.5);

yline(0,'--');

grid on;

title("U.S. Federal Funds Rate");
subtitle("Quarterly Average");

xlabel("Year");
ylabel("Interest Rate (%)");

exportgraphics( ...
    fig4, ...
    fullfile(cfg.FiguresDir,"04_Interest_Rate.png"), ...
    'Resolution',300);

%% Figure 5 - Macroeconomic Dashboard

fig5 = figure( ...
    'Position',[100 100 1200 750]);

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

% GDP Growth
nexttile;

plot( ...
    DATA.observation_date, ...
    DATA.GDPGrowth, ...
    'LineWidth',1.3);

yline(0,'--');
grid on;

title("Real GDP Growth");
ylabel("%");

% Inflation
nexttile;

plot( ...
    DATA.observation_date, ...
    DATA.Inflation, ...
    'LineWidth',1.3);

yline(0,'--');
grid on;

title("Inflation");
ylabel("%");

% Unemployment
nexttile;

plot( ...
    DATA.observation_date, ...
    DATA.Unemployment, ...
    'LineWidth',1.3);

grid on;

title("Unemployment Rate");
xlabel("Year");
ylabel("%");

% Interest Rate
nexttile;

plot( ...
    DATA.observation_date, ...
    DATA.InterestRate, ...
    'LineWidth',1.3);

yline(0,'--');
grid on;

title("Federal Funds Rate");
xlabel("Year");
ylabel("%");

sgtitle( ...
    "U.S. Macroeconomic Dynamics | MATLAB Econometrics Project");

exportgraphics( ...
    fig5, ...
    fullfile(cfg.FiguresDir,"05_Macroeconomic_Dashboard.png"), ...
    'Resolution',300);

%% Correlation heatmap

fig6 = figure;

imagesc(CORR);

colorbar;

axis square;

xticks(1:4);
yticks(1:4);

xticklabels( ...
    {'GDP Growth','Inflation','Unemployment','Interest Rate'});

yticklabels( ...
    {'GDP Growth','Inflation','Unemployment','Interest Rate'});

title("Correlation Matrix of U.S. Macroeconomic Variables");

%% Add correlation values to heatmap

for row = 1:4
    for col = 1:4

        text( ...
            col, ...
            row, ...
            sprintf('%.2f',CORR(row,col)), ...
            'HorizontalAlignment','center', ...
            'FontWeight','bold');

    end
end

exportgraphics( ...
    fig6, ...
    fullfile(cfg.FiguresDir,"06_Correlation_Heatmap.png"), ...
    'Resolution',300);

end

%% Finish

disp(" ");
disp("==============================================");
disp(" PHASE 3 COMPLETE");
disp("==============================================");

disp("Results saved to:");
disp("results/Descriptive_Statistics.csv");
disp("results/Correlation_Matrix.csv");

disp(" ");

disp("Figures saved to:");
disp("figures/01_GDP_Growth.png");
disp("figures/02_Inflation.png");
disp("figures/03_Unemployment.png");
disp("figures/04_Interest_Rate.png");
disp("figures/05_Macroeconomic_Dashboard.png");
disp("figures/06_Correlation_Heatmap.png");

figureFiles = [ ...
    "01_GDP_Growth.png"; ...
    "02_Inflation.png"; ...
    "03_Unemployment.png"; ...
    "04_Interest_Rate.png"; ...
    "05_Macroeconomic_Dashboard.png"; ...
    "06_Correlation_Heatmap.png"];
output = struct("Data",DATA, ...
    "DescriptiveStatistics",DESCRIPTIVE, ...
    "CorrelationMatrix",CORR_TABLE, ...
    "FigureFiles",figureFiles);
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
        error("macro:phase03:MissingInput", ...
            "Required processed-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
