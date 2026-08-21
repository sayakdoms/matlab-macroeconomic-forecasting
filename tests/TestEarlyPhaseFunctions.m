classdef TestEarlyPhaseFunctions < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        OutputRoot (1,1) string
        OutsideFolder (1,1) string
        Cfg (1,1) struct
        Phase1Output (1,1) struct
        Phase2Data
        Phase3Output (1,1) struct
    end

    methods (TestClassSetup)
        function runEarlyPhasesFromOutsideRepository(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(testFile)));
            addpath(fullfile(testCase.ProjectRoot,"scripts"));

            testCase.OutputRoot = string(tempname);
            testCase.OutsideFolder = string(tempname);
            mkdir(testCase.OutputRoot);
            mkdir(testCase.OutsideFolder);
            testCase.Cfg = macro.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,RefreshData=false);

            originalFolder = string(pwd);
            originalVisibility = get(groot,"defaultFigureVisible");
            cleanup = onCleanup(@() restoreEnvironment( ...
                originalFolder,originalVisibility)); %#ok<NASGU>
            set(groot,"defaultFigureVisible","off");
            cd(testCase.OutsideFolder);

            testCase.Phase1Output = import_fred_data_01(testCase.Cfg);
            testCase.Phase2Data = clean_transform_data_02(testCase.Cfg);
            testCase.Phase3Output = exploratory_analysis_03(testCase.Cfg);
        end
    end

    methods (TestClassTeardown)
        function removeTemporaryArtifacts(testCase)
            close all;
            rmpath(fullfile(testCase.ProjectRoot,"scripts"));
            removeSafeTemporaryFolder(testCase.OutputRoot);
            removeSafeTemporaryFolder(testCase.OutsideFolder);
        end
    end

    methods (Test)
        function phasesAreIndependentlyCallable(testCase)
            testCase.verifyClass(testCase.Phase1Output,"struct");
            testCase.verifyTrue(istimetable(testCase.Phase2Data));
            testCase.verifyClass(testCase.Phase3Output,"struct");
            testCase.verifyTrue(isfield(testCase.Phase3Output, ...
                "DescriptiveStatistics"));
            testCase.verifyTrue(isfield(testCase.Phase3Output, ...
                "CorrelationMatrix"));
        end

        function phasesWriteOnlyToConfiguredOutputRoot(testCase)
            testCase.verifyTrue(isfolder(testCase.Cfg.DataDir));
            testCase.verifyTrue(isfolder(testCase.Cfg.ResultsDir));
            testCase.verifyTrue(isfolder(testCase.Cfg.FiguresDir));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.csv")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.png")));
        end

        function phase1SnapshotMatchesCommittedRawTables(testCase)
            names = ["GDP","Unemployment","CPI","InterestRate"];
            files = ["GDP_raw.csv","Unemployment_raw.csv", ...
                "CPI_raw.csv","InterestRate_raw.csv"];
            values = ["GDPC1","UNRATE","CPIAUCSL","FEDFUNDS"];

            for index = 1:numel(names)
                committed = readtable(fullfile(testCase.ProjectRoot,"data", ...
                    files(index)));
                committed = macro.validateRawFredTable(committed,values(index), ...
                    AllowMissingObservations=true);
                actual = testCase.Phase1Output.(names(index));
                testCase.verifyEqual(actual.Properties.VariableNames, ...
                    committed.Properties.VariableNames);
                testCase.verifyEqual(actual.observation_date, ...
                    committed.observation_date);
                testCase.verifyEqual(actual.(values(index)), ...
                    committed.(values(index)));
            end
        end

        function phase2MatchesCommittedQuarterlyDataset(testCase)
            committed = readtimetable(fullfile(testCase.ProjectRoot,"data", ...
                "Macroeconomic_Data_Quarterly.csv"));
            actual = testCase.Phase2Data;

            testCase.verifyEqual(actual.Properties.VariableNames, ...
                committed.Properties.VariableNames);
            testCase.verifyEqual(actual.Properties.RowTimes, ...
                committed.Properties.RowTimes);
            testCase.verifyEqual(actual.Variables,committed.Variables, ...
                'AbsTol',1e-12);
        end

        function phase3StatisticsMatchCommittedOutputs(testCase)
            committedDescriptive = readtable(fullfile( ...
                testCase.ProjectRoot,"results","Descriptive_Statistics.csv"));
            actualDescriptive = testCase.Phase3Output.DescriptiveStatistics;
            testCase.verifyEqual(string(actualDescriptive.Variable), ...
                string(committedDescriptive.Variable));
            testCase.verifyEqual(actualDescriptive{:,2:end}, ...
                committedDescriptive{:,2:end},'AbsTol',1e-12);

            committedCorrelation = readtable(fullfile( ...
                testCase.ProjectRoot,"results","Correlation_Matrix.csv"), ...
                'ReadRowNames',true);
            actualCorrelation = testCase.Phase3Output.CorrelationMatrix;
            testCase.verifyEqual(actualCorrelation.Properties.VariableNames, ...
                committedCorrelation.Properties.VariableNames);
            testCase.verifyEqual(actualCorrelation.Properties.RowNames, ...
                committedCorrelation.Properties.RowNames);
            testCase.verifyEqual(actualCorrelation.Variables, ...
                committedCorrelation.Variables,'AbsTol',1e-12);
        end

        function outputAndFigureNamesRemainUnchanged(testCase)
            expectedDataFiles = ["CPI_raw.csv","GDP_raw.csv", ...
                "InterestRate_raw.csv","Macroeconomic_Data_Quarterly.csv", ...
                "Unemployment_raw.csv"];
            expectedResultFiles = ["Correlation_Matrix.csv", ...
                "Descriptive_Statistics.csv"];
            expectedFigureFiles = ["01_GDP_Growth.png", ...
                "02_Inflation.png","03_Unemployment.png", ...
                "04_Interest_Rate.png","05_Macroeconomic_Dashboard.png", ...
                "06_Correlation_Heatmap.png"];

            testCase.verifyEqual(folderFileNames(testCase.Cfg.DataDir), ...
                sort(expectedDataFiles));
            testCase.verifyEqual(folderFileNames(testCase.Cfg.ResultsDir), ...
                sort(expectedResultFiles));
            testCase.verifyEqual(folderFileNames(testCase.Cfg.FiguresDir), ...
                sort(expectedFigureFiles));
            testCase.verifyEqual(sort(testCase.Phase3Output.FigureFiles), ...
                sort(expectedFigureFiles(:)));
        end

        function omittedConfigurationFindsCommittedProject(testCase)
            originalFolder = string(pwd);
            cleanup = onCleanup(@() cd(originalFolder)); %#ok<NASGU>
            cd(testCase.OutsideFolder);
            output = import_fred_data_01();

            committedGDP = readtable(fullfile(testCase.ProjectRoot,"data", ...
                "GDP_raw.csv"));
            testCase.verifyEqual(height(output.GDP),height(committedGDP));
            testCase.verifyEqual(output.GDP.GDPC1,committedGDP.GDPC1);
        end
    end
end

function names = folderFileNames(folderPath)
listing = dir(folderPath);
listing = listing(~[listing.isdir]);
names = sort(string({listing.name}));
end

function restoreEnvironment(folderPath,visibility)
cd(folderPath);
set(groot,"defaultFigureVisible",visibility);
close all;
end

function removeSafeTemporaryFolder(folderPath)
temporaryRoot = string(java.io.File(char(tempdir)).getCanonicalPath());
candidate = string(java.io.File(char(folderPath)).getCanonicalPath());
if ispc
    isSafe = startsWith(lower(candidate),lower(temporaryRoot+filesep));
else
    isSafe = startsWith(candidate,temporaryRoot+filesep);
end
if isSafe && isfolder(candidate)
    rmdir(candidate,"s");
end
end
