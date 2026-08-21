classdef TestEndToEndPipeline < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        FullOutputRoot (1,1) string
        FastOutputRoot (1,1) string
        OutsideFolder (1,1) string
        FullSummary (1,1) struct
        FastSummary (1,1) struct
        RawSnapshotsBefore (4,1) cell
        RawSnapshotsAfter (4,1) cell
        PathRestoredAfterFull (1,1) logical
        PathRestoredAfterFast (1,1) logical
        AddedProjectPath (1,1) logical = false
        AddedSourcePath (1,1) logical = false
    end

    methods (TestClassSetup)
        function runPipelinesFromOutsideRepository(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(testFile)));
            sourceDir = fullfile(testCase.ProjectRoot,"src");
            pathEntries = string(strsplit(path,pathsep));
            if ~any(pathEntries == testCase.ProjectRoot)
                addpath(testCase.ProjectRoot);
                testCase.AddedProjectPath = true;
            end
            if ~any(pathEntries == sourceDir)
                addpath(sourceDir);
                testCase.AddedSourcePath = true;
            end

            testCase.FullOutputRoot = string(tempname);
            testCase.FastOutputRoot = string(tempname);
            testCase.OutsideFolder = string(tempname);
            mkdir(testCase.FullOutputRoot);
            mkdir(testCase.FastOutputRoot);
            mkdir(testCase.OutsideFolder);

            snapshotFiles = rawSnapshotFiles(testCase.ProjectRoot);
            testCase.RawSnapshotsBefore = readFileContents(snapshotFiles);

            originalFolder = string(pwd);
            originalVisibility = get(groot,"defaultFigureVisible");
            cleanup = onCleanup(@() restoreEnvironment( ...
                originalFolder,originalVisibility)); %#ok<NASGU>
            set(groot,"defaultFigureVisible","off");
            cd(testCase.OutsideFolder);

            pathBefore = path;
            testCase.FullSummary = run_all( ...
                OutputRoot=testCase.FullOutputRoot, ...
                RefreshData=false,GenerateFigures=true,StopOnError=true);
            testCase.PathRestoredAfterFull = strcmp(path,pathBefore);

            pathBefore = path;
            testCase.FastSummary = run_all( ...
                OutputRoot=testCase.FastOutputRoot, ...
                RefreshData=false,GenerateFigures=false,StopOnError=true);
            testCase.PathRestoredAfterFast = strcmp(path,pathBefore);

            testCase.RawSnapshotsAfter = readFileContents(snapshotFiles);
        end
    end

    methods (TestClassTeardown)
        function removeTemporaryArtifacts(testCase)
            close all;
            if testCase.AddedSourcePath
                rmpath(fullfile(testCase.ProjectRoot,"src"));
            end
            if testCase.AddedProjectPath
                rmpath(testCase.ProjectRoot);
            end
            removeSafeTemporaryFolder(testCase.FullOutputRoot);
            removeSafeTemporaryFolder(testCase.FastOutputRoot);
            removeSafeTemporaryFolder(testCase.OutsideFolder);
        end
    end

    methods (Test)
        function allPhasesSucceedAndOptionsAreRecorded(testCase)
            testCase.verifyTrue(testCase.FullSummary.Success);
            testCase.verifyTrue(testCase.FastSummary.Success);
            testCase.verifyEqual(testCase.FullSummary.Phases.Phase,(1:12)');
            testCase.verifyEqual(testCase.FullSummary.Phases.Status, ...
                repmat("Succeeded",12,1));
            testCase.verifyEqual(testCase.FastSummary.Phases.Status, ...
                repmat("Succeeded",12,1));
            testCase.verifyFalse(testCase.FullSummary.Configuration.RefreshData);
            testCase.verifyTrue(testCase.FullSummary.Configuration.GenerateFigures);
            testCase.verifyFalse(testCase.FastSummary.Configuration.GenerateFigures);
            testCase.verifyTrue(testCase.FullSummary.Configuration.StopOnError);
        end

        function worksOutsideRepositoryAndRestoresPath(testCase)
            testCase.verifyTrue(testCase.PathRestoredAfterFull);
            testCase.verifyTrue(testCase.PathRestoredAfterFast);
            testCase.verifyEmpty(folderFileNames(testCase.OutsideFolder));
            testCase.verifyNotEqual(testCase.OutsideFolder,testCase.ProjectRoot);
        end

        function processedDatasetMatchesCommittedData(testCase)
            fullData = readtimetable(fullfile(testCase.FullOutputRoot, ...
                "data","Macroeconomic_Data_Quarterly.csv"));
            fastData = readtimetable(fullfile(testCase.FastOutputRoot, ...
                "data","Macroeconomic_Data_Quarterly.csv"));
            committedData = readtimetable(fullfile(testCase.ProjectRoot, ...
                "data","Macroeconomic_Data_Quarterly.csv"));
            testCase.verifyEqual(height(fullData),266);
            compareTimetables(testCase,fullData,committedData,1e-11);
            compareTimetables(testCase,fastData,committedData,1e-11);
        end

        function headlineOutputsMatchCommittedResults(testCase)
            parityFiles = [ ...
                "OLS_Regression_Results.csv";"OLS_Model_Summary.csv"; ...
                "OLS_Predictions_Residuals.csv"; ...
                "Lag_Model_Comparison.csv";"Lag_Model_Coefficients.csv"; ...
                "Best_Lag_Model_Summary.csv";"Best_Lag_Model_Output.csv"; ...
                "Dynamic_Distributed_Lag_Results.csv"; ...
                "Dynamic_Model_Summary.csv";"Dynamic_Model_Predictions.csv"; ...
                "Forecast_Model_Coefficients.csv"; ...
                "Out_of_Sample_Forecast_Summary.csv"; ...
                "Out_of_Sample_Forecasts.csv"; ...
                "Forecast_Robustness_Results.csv"; ...
                "Structural_Break_Test.csv"; ...
                "Structural_Break_Regime_Summary.csv"; ...
                "Structural_Break_Coefficients.csv"; ...
                "Expanding_Window_Model_Leaderboard.csv"; ...
                "Expanding_Window_Forecasts.csv"; ...
                "Expanding_Window_Coefficient_History.csv"; ...
                "Final_Project_KPIs.csv"];
            for fileName = parityFiles'
                actual = readtable(fullfile(testCase.FullOutputRoot, ...
                    "results",fileName));
                expected = readtable(fullfile(testCase.ProjectRoot, ...
                    "results",fileName));
                compareTables(testCase,actual,expected,1e-9);
            end
        end

        function completeGeneratedFileManifestIsCorrect(testCase)
            testCase.verifyEqual(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"data")),expectedDataFiles());
            testCase.verifyEqual(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"results")),expectedResultFiles());
            testCase.verifyEqual(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"figures")),expectedFigureFiles());
            testCase.verifyEqual(numel(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"data"))),5);
            testCase.verifyEqual(numel(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"results"))),26);
            testCase.verifyEqual(numel(folderFileNames(fullfile( ...
                testCase.FullOutputRoot,"figures"))),40);
        end

        function noFigureModePreservesAnalyticalResults(testCase)
            testCase.verifyEmpty(folderFileNames(fullfile( ...
                testCase.FastOutputRoot,"figures")));
            testCase.verifyEqual(folderFileNames(fullfile( ...
                testCase.FastOutputRoot,"data")),expectedDataFiles());
            testCase.verifyEqual(folderFileNames(fullfile( ...
                testCase.FastOutputRoot,"results")),expectedResultFiles());

            for fileName = expectedResultFiles()
                fullFile = fullfile(testCase.FullOutputRoot,"results",fileName);
                fastFile = fullfile(testCase.FastOutputRoot,"results",fileName);
                if endsWith(fileName,".csv")
                    compareTables(testCase,readtable(fullFile), ...
                        readtable(fastFile),1e-11);
                else
                    testCase.verifyEqual(normalizeNewlines(fileread(fullFile)), ...
                        normalizeNewlines(fileread(fastFile)));
                end
            end
        end

        function committedRawSnapshotsRemainByteIdentical(testCase)
            testCase.verifyEqual(testCase.RawSnapshotsAfter, ...
                testCase.RawSnapshotsBefore);
        end

        function schemasAndForecastProvenanceRemainValid(testCase)
            for fileName = expectedResultFiles()
                if ~endsWith(fileName,".csv")
                    continue
                end
                actual = readtable(fullfile(testCase.FullOutputRoot, ...
                    "results",fileName));
                committed = readtable(fullfile(testCase.ProjectRoot, ...
                    "results",fileName));
                testCase.verifyEqual(actual.Properties.VariableNames, ...
                    committed.Properties.VariableNames);
            end

            data = readtimetable(fullfile(testCase.FullOutputRoot, ...
                "data","Macroeconomic_Data_Quarterly.csv"));
            design = macro.buildForecastDesign(data);
            sourceRows = design.PredictorSourceRows(:,2:end);
            latestPermitted = repmat( ...
                design.ResponseRows-1,1,size(sourceRows,2));
            testCase.verifyLessThanOrEqual(sourceRows,latestPermitted);

            recursive = readtable(fullfile(testCase.FullOutputRoot, ...
                "results","Expanding_Window_Forecasts.csv"));
            testCase.verifyEqual(recursive.TrainingSize,(220:261)');
        end

        function executionSummaryContainsTimings(testCase)
            testCase.verifyGreaterThan(testCase.FullSummary.TotalElapsedSeconds,0);
            testCase.verifyGreaterThan(testCase.FastSummary.TotalElapsedSeconds,0);
            testCase.verifyGreaterThan( ...
                testCase.FullSummary.Phases.ElapsedSeconds,zeros(12,1));
            testCase.verifyGreaterThan( ...
                testCase.FastSummary.Phases.ElapsedSeconds,zeros(12,1));
            testCase.verifyEqual( ...
                testCase.FullSummary.Phases.ErrorIdentifier,strings(12,1));
        end
    end
end

function files = rawSnapshotFiles(projectRoot)
files = fullfile(projectRoot,"data",[ ...
    "GDP_raw.csv";"Unemployment_raw.csv"; ...
    "CPI_raw.csv";"InterestRate_raw.csv"]);
end

function contents = readFileContents(files)
contents = cell(numel(files),1);
for index = 1:numel(files)
    contents{index} = fileread(files(index));
end
end

function files = expectedDataFiles
files = sort(["CPI_raw.csv","GDP_raw.csv","InterestRate_raw.csv", ...
    "Macroeconomic_Data_Quarterly.csv","Unemployment_raw.csv"]);
end

function files = expectedResultFiles
files = sort([ ...
    "Best_Lag_Model_Output.csv","Best_Lag_Model_Summary.csv", ...
    "Correlation_Matrix.csv","Descriptive_Statistics.csv", ...
    "Diagnostic_Summary.csv","Dynamic_Distributed_Lag_Results.csv", ...
    "Dynamic_Model_Predictions.csv","Dynamic_Model_Summary.csv", ...
    "Executive_Research_Summary.txt", ...
    "Expanding_Window_Coefficient_History.csv", ...
    "Expanding_Window_Forecasts.csv", ...
    "Expanding_Window_Model_Leaderboard.csv", ...
    "Final_Project_KPIs.csv","Forecast_Model_Coefficients.csv", ...
    "Forecast_Robustness_Results.csv","Lag_Model_Coefficients.csv", ...
    "Lag_Model_Comparison.csv","OLS_Model_Summary.csv", ...
    "OLS_Predictions_Residuals.csv","OLS_Regression_Results.csv", ...
    "Out_of_Sample_Forecast_Summary.csv", ...
    "Out_of_Sample_Forecasts.csv", ...
    "Structural_Break_Coefficients.csv", ...
    "Structural_Break_Regime_Summary.csv", ...
    "Structural_Break_Test.csv","VIF_Results.csv"]);
end

function files = expectedFigureFiles
files = strings(40,1);
names = [ ...
    "GDP_Growth","Inflation","Unemployment","Interest_Rate", ...
    "Macroeconomic_Dashboard","Correlation_Heatmap", ...
    "Actual_vs_Predicted_GDP_Growth","OLS_Residuals", ...
    "Residual_Distribution","Observed_vs_Fitted","Residual_ACF", ...
    "Residual_vs_Fitted","Residual_QQ_Plot","Standardized_Residuals", ...
    "Lag_Model_R2_Comparison","Lag_Model_RMSE_Comparison", ...
    "Coefficient_Paths_Across_Lags", ...
    "Best_Lag_Model_Actual_vs_Predicted", ...
    "Dynamic_Model_Actual_vs_Predicted","Inflation_Lag_Effects", ...
    "Unemployment_Lag_Effects","Interest_Rate_Lag_Effects", ...
    "Out_of_Sample_Forecast","Forecast_Model_Comparison", ...
    "Out_of_Sample_Forecast_Errors","Forecast_RMSE_Comparison", ...
    "Forecast_RMSE_by_Regime","Forecast_MAE_by_Regime", ...
    "Forecasts_and_COVID_Shock","Pre_vs_Post_COVID_Coefficients", ...
    "Structural_Coefficient_Change","Regime_Adjusted_R2", ...
    "GDP_Growth_Structural_Break","Adaptive_Forecast_Comparison", ...
    "Rolling_RMSE","Forecast_Model_Leaderboard", ...
    "Adaptive_Coefficient_Evolution","Cumulative_Forecast_Error", ...
    "Final_Research_Dashboard"];
for index = 1:39
    files(index) = compose("%02d_%s.png",index,names(index));
end
files(40) = "39_Final_Research_Dashboard.pdf";
files = sort(files)';
end

function compareTimetables(testCase,actual,expected,tolerance)
testCase.verifyEqual(actual.Properties.VariableNames, ...
    expected.Properties.VariableNames);
testCase.verifyEqual(actual.Properties.RowTimes,expected.Properties.RowTimes);
for index = 1:width(actual)
    testCase.verifyEqual(actual{:,index},expected{:,index}, ...
        'AbsTol',tolerance);
end
end

function compareTables(testCase,actual,expected,tolerance)
testCase.verifyEqual(actual.Properties.VariableNames, ...
    expected.Properties.VariableNames);
testCase.verifyEqual(height(actual),height(expected));
for index = 1:width(actual)
    actualValue = actual.(actual.Properties.VariableNames{index});
    expectedValue = expected.(expected.Properties.VariableNames{index});
    if isdatetime(actualValue)
        if ~isdatetime(expectedValue)
            expectedValue = datetime(expectedValue);
        end
        testCase.verifyEqual(actualValue,expectedValue);
    elseif isnumeric(actualValue) || islogical(actualValue)
        testCase.verifyEqual(double(actualValue),double(expectedValue), ...
            'AbsTol',tolerance);
    else
        testCase.verifyEqual(string(actualValue),string(expectedValue));
    end
end
end

function names = folderFileNames(folderPath)
listing = dir(folderPath);
listing = listing(~[listing.isdir]);
names = sort(string({listing.name}));
end

function value = normalizeNewlines(value)
value = replace(string(value),["\r\n","\r"],"\n");
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
