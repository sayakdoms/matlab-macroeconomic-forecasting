function output = import_fred_data_01(cfg)
%IMPORT_FRED_DATA_01 Phase 1 - Import or load raw FRED data.
%   OUTPUT = import_fred_data_01() uses the committed raw-data snapshot.
%   Set cfg.RefreshData=true to retain the original live-download behavior.

if nargin < 1
    cfg = [];
end
[cfg,pathCleanup] = initializePhaseConfiguration( ...
    cfg,mfilename("fullpath")); %#ok<ASGLU>

clc;
close all;

%% MATLAB MACROECONOMETRICS PROJECT
% Phase 1 - Import real macroeconomic data from FRED

disp("==============================================");
disp(" MATLAB MACROECONOMETRICS PROJECT");
disp(" Phase 1: FRED Data Import");
disp("==============================================");

macro.ensureOutputDirectories(cfg);

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

if cfg.RefreshData
    disp("Downloading Real GDP...");
    GDP = readtable(gdpURL);

    disp("Downloading Unemployment Rate...");
    UNEMP = readtable(unemploymentURL);

    disp("Downloading Consumer Price Index...");
    CPI = readtable(cpiURL);

    disp("Downloading Federal Funds Rate...");
    RATE = readtable(interestURL);
else
    disp("Loading committed raw FRED data snapshot...");
    GDP = readtable(fullfile(cfg.SourceDataDir,"GDP_raw.csv"));
    UNEMP = readtable(fullfile(cfg.SourceDataDir,"Unemployment_raw.csv"));
    CPI = readtable(fullfile(cfg.SourceDataDir,"CPI_raw.csv"));
    RATE = readtable(fullfile(cfg.SourceDataDir,"InterestRate_raw.csv"));
end

%% Validate imported datasets

GDP = macro.validateRawFredTable(GDP,"GDPC1", ...
    DataName="GDP raw data",AllowMissingObservations=true);
UNEMP = macro.validateRawFredTable(UNEMP,"UNRATE", ...
    DataName="unemployment raw data",AllowMissingObservations=true);
CPI = macro.validateRawFredTable(CPI,"CPIAUCSL", ...
    DataName="CPI raw data",AllowMissingObservations=true);
RATE = macro.validateRawFredTable(RATE,"FEDFUNDS", ...
    DataName="interest-rate raw data",AllowMissingObservations=true);

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

writeRawTableIfNeeded(GDP,fullfile(cfg.DataDir,"GDP_raw.csv"),cfg);
writeRawTableIfNeeded(UNEMP,fullfile(cfg.DataDir,"Unemployment_raw.csv"),cfg);
writeRawTableIfNeeded(CPI,fullfile(cfg.DataDir,"CPI_raw.csv"),cfg);
writeRawTableIfNeeded(RATE,fullfile(cfg.DataDir,"InterestRate_raw.csv"),cfg);

disp("Raw datasets saved successfully in the data folder.");

output = struct("GDP",GDP,"Unemployment",UNEMP,"CPI",CPI, ...
    "InterestRate",RATE);
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

function writeRawTableIfNeeded(data,destination,cfg)
[~,baseName,extension] = fileparts(destination);
source = fullfile(cfg.SourceDataDir,baseName+extension);
sameCommittedFile = ~cfg.RefreshData && sameCanonicalPath(destination,source);
if ~sameCommittedFile
    writetable(data,destination);
end
end

function tf = sameCanonicalPath(firstPath,secondPath)
firstCanonical = string(java.io.File(char(firstPath)).getCanonicalPath());
secondCanonical = string(java.io.File(char(secondPath)).getCanonicalPath());
if ispc
    tf = strcmpi(firstCanonical,secondCanonical);
else
    tf = firstCanonical == secondCanonical;
end
end
