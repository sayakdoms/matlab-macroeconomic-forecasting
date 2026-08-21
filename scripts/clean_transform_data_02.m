function DATA = clean_transform_data_02(cfg)
%CLEAN_TRANSFORM_DATA_02 Phase 2 - Clean and align macroeconomic data.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 2 - Clean, transform and align macroeconomic data

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 2: Data Cleaning & Transformation");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

%% Load raw datasets

GDP   = readtable(resolveDataInput(cfg,"GDP_raw.csv"));
UNEMP = readtable(resolveDataInput(cfg,"Unemployment_raw.csv"));
CPI   = readtable(resolveDataInput(cfg,"CPI_raw.csv"));
RATE  = readtable(resolveDataInput(cfg,"InterestRate_raw.csv"));

GDP = macro.validateRawFredTable(GDP,"GDPC1", ...
    DataName="GDP raw data",AllowMissingObservations=true);
UNEMP = macro.validateRawFredTable(UNEMP,"UNRATE", ...
    DataName="unemployment raw data",AllowMissingObservations=true);
CPI = macro.validateRawFredTable(CPI,"CPIAUCSL", ...
    DataName="CPI raw data",AllowMissingObservations=true);
RATE = macro.validateRawFredTable(RATE,"FEDFUNDS", ...
    DataName="interest-rate raw data",AllowMissingObservations=true);

disp("Raw datasets loaded successfully.");

%% Convert FRED date columns to datetime

GDP.observation_date   = datetime(GDP.observation_date);
UNEMP.observation_date = datetime(UNEMP.observation_date);
CPI.observation_date   = datetime(CPI.observation_date);
RATE.observation_date  = datetime(RATE.observation_date);

disp("Date variables converted successfully.");

%% Convert tables into timetables

GDP_TT = table2timetable(GDP, ...
    "RowTimes","observation_date");

UNEMP_TT = table2timetable(UNEMP, ...
    "RowTimes","observation_date");

CPI_TT = table2timetable(CPI, ...
    "RowTimes","observation_date");

RATE_TT = table2timetable(RATE, ...
    "RowTimes","observation_date");

disp("Tables converted to timetables.");

%% Convert monthly series to quarterly averages

UNEMP_Q = retime(UNEMP_TT, ...
    "quarterly","mean");

CPI_Q = retime(CPI_TT, ...
    "quarterly","mean");

RATE_Q = retime(RATE_TT, ...
    "quarterly","mean");

disp("Monthly series converted to quarterly frequency.");

%% Synchronize all datasets

DATA = synchronize( ...
    GDP_TT, ...
    UNEMP_Q, ...
    CPI_Q, ...
    RATE_Q, ...
    "intersection");

disp("Datasets synchronized successfully.");

%% Rename variables

DATA.Properties.VariableNames = ...
    ["RealGDP", ...
     "Unemployment", ...
     "CPI", ...
     "InterestRate"];

%% Calculate GDP growth
% Annualized quarter-to-quarter log growth

DATA.GDPGrowth = ...
    [NaN; 400 * diff(log(DATA.RealGDP))];

%% Calculate inflation
% Annualized quarter-to-quarter CPI inflation

DATA.Inflation = ...
    [NaN; 400 * diff(log(DATA.CPI))];

disp("GDP growth and inflation calculated.");

%% Remove missing observations

DATA = rmmissing(DATA);

%% Restrict analysis to 1960 onward

startDate = datetime(1960,1,1);

DATA = DATA(DATA.observation_date >= startDate,:);

DATA = macro.validateQuarterlyData(DATA);

%% Display cleaned dataset

disp(" ");
disp("==============================================");
disp(" CLEAN ECONOMETRIC DATASET PREVIEW");
disp("==============================================");

disp(head(DATA,10));

%% Sample information

fprintf("\nDataset begins: %s\n", ...
    string(DATA.observation_date(1)));

fprintf("Dataset ends: %s\n", ...
    string(DATA.observation_date(end)));

fprintf("Number of quarterly observations: %d\n", ...
    height(DATA));

%% Basic descriptive statistics

fprintf("\n----------------------------------------------\n");
fprintf(" BASIC DESCRIPTIVE STATISTICS\n");
fprintf("----------------------------------------------\n");

fprintf("Average GDP Growth: %.2f %%\n", ...
    mean(DATA.GDPGrowth));

fprintf("Average Inflation: %.2f %%\n", ...
    mean(DATA.Inflation));

fprintf("Average Unemployment Rate: %.2f %%\n", ...
    mean(DATA.Unemployment));

fprintf("Average Interest Rate: %.2f %%\n", ...
    mean(DATA.InterestRate));

%% Save processed dataset

outputFile = fullfile( ...
    cfg.DataDir, ...
    "Macroeconomic_Data_Quarterly.csv");

writetimetable(DATA, outputFile);

disp(" ");
disp("Processed dataset saved successfully:");
disp(outputFile);

disp("==============================================");
disp(" PHASE 2 COMPLETE");
disp("==============================================");
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
        error("macro:phase02:MissingInput", ...
            "Required raw-data file was not found: %s",fileName);
    end
    inputFile = sourceFile;
end
end
