classdef TestFinalPhaseFunctions < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        OutputRoot (1,1) string
        OutsideFolder (1,1) string
        Cfg (1,1) struct
        AddedSourcePath (1,1) logical = false
        AddedScriptsPath (1,1) logical = false
        Phase9Output (1,1) struct
        Phase10Output (1,1) struct
        Phase11Output (1,1) struct
        Phase12Output (1,1) struct
    end

    methods (TestClassSetup)
        function runPhasesFromOutsideRepository(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(testFile)));
            sourceDir = fullfile(testCase.ProjectRoot,"src");
            scriptsDir = fullfile(testCase.ProjectRoot,"scripts");
            pathEntries = string(strsplit(path,pathsep));
            if ~any(pathEntries == sourceDir)
                addpath(sourceDir);
                testCase.AddedSourcePath = true;
            end
            if ~any(pathEntries == scriptsDir)
                addpath(scriptsDir);
                testCase.AddedScriptsPath = true;
            end

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

            testCase.Phase9Output = forecast_robustness_09(testCase.Cfg);
            testCase.Phase10Output = structural_break_analysis_10(testCase.Cfg);
            testCase.Phase11Output = expanding_window_forecast_11(testCase.Cfg);
            testCase.Phase12Output = final_research_dashboard_12(testCase.Cfg);
        end
    end

    methods (TestClassTeardown)
        function removeTemporaryArtifacts(testCase)
            close all;
            if testCase.AddedScriptsPath
                rmpath(fullfile(testCase.ProjectRoot,"scripts"));
            end
            if testCase.AddedSourcePath
                rmpath(fullfile(testCase.ProjectRoot,"src"));
            end
            removeSafeTemporaryFolder(testCase.OutputRoot);
            removeSafeTemporaryFolder(testCase.OutsideFolder);
        end
    end

    methods (Test)
        function phasesAreIndependentlyCallable(testCase)
            testCase.verifyClass(testCase.Phase9Output,"struct");
            testCase.verifyClass(testCase.Phase10Output,"struct");
            testCase.verifyClass(testCase.Phase11Output,"struct");
            testCase.verifyClass(testCase.Phase12Output,"struct");
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.csv")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.png")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.pdf")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.txt")));
        end

        function phase9RegimesMatchCommittedOutput(testCase)
            compareTables(testCase,testCase.Phase9Output.Robustness, ...
                committedTable(testCase.ProjectRoot, ...
                "Forecast_Robustness_Results.csv"),1e-10);
            testCase.verifyEqual( ...
                testCase.Phase9Output.Robustness.Observations,[16;4;22;42]);
            testCase.verifyEqual( ...
                string(testCase.Phase9Output.Robustness.Regime),[ ...
                "2016-2019 Pre-COVID";"2020 COVID Shock"; ...
                "2021+ Post-COVID";"Full Test Sample"]);
        end

        function phase10OutputsMatchCommittedResults(testCase)
            compareTables(testCase,testCase.Phase10Output.RegimeSummary, ...
                committedTable(testCase.ProjectRoot, ...
                "Structural_Break_Regime_Summary.csv"),1e-10);
            compareTables(testCase,testCase.Phase10Output.CoefficientComparison, ...
                committedTable(testCase.ProjectRoot, ...
                "Structural_Break_Coefficients.csv"),1e-9);

            committedBreak = committedTable(testCase.ProjectRoot, ...
                "Structural_Break_Test.csv");
            actualBreak = testCase.Phase10Output.BreakSummary;
            testCase.verifyEqual(actualBreak.BreakDate, ...
                datetime(committedBreak.BreakDate));
            testCase.verifyEqual(actualBreak.ChowFStatistic, ...
                committedBreak.ChowFStatistic,'AbsTol',1e-10);
            if exist('fcdf','file') == 2
                testCase.verifyEqual(actualBreak.ApproxPValue, ...
                    committedBreak.ApproxPValue,'AbsTol',1e-12);
            else
                testCase.verifyTrue(isnan(actualBreak.ApproxPValue));
            end
        end

        function phase10PreservesFixedBreakAndCalculation(testCase)
            output = testCase.Phase10Output;
            testCase.verifyEqual(output.BreakDate,datetime(2020,1,1));
            testCase.verifyEqual(sum(output.PreIndex),236);
            testCase.verifyEqual(sum(output.PostIndex),26);
            testCase.verifySize(output.Design.X,[262 14]);

            k = size(output.Design.X,2);
            n1 = output.PreModel.Observations;
            n2 = output.PostModel.Observations;
            numerator = (output.PooledModel.SSE - ...
                output.PreModel.SSE-output.PostModel.SSE)/k;
            denominator = (output.PreModel.SSE+output.PostModel.SSE) / ...
                (n1+n2-2*k);
            testCase.verifyEqual(output.BreakSummary.ChowFStatistic, ...
                numerator/denominator,'AbsTol',1e-12);
        end

        function phase11OutputsMatchCommittedResults(testCase)
            compareTables(testCase,testCase.Phase11Output.ModelLeaderboard, ...
                committedTable(testCase.ProjectRoot, ...
                "Expanding_Window_Model_Leaderboard.csv"),1e-10);
            compareTables(testCase,testCase.Phase11Output.ForecastResults, ...
                committedTable(testCase.ProjectRoot, ...
                "Expanding_Window_Forecasts.csv"),1e-9);
            compareTables(testCase,testCase.Phase11Output.CoefficientHistory, ...
                committedTable(testCase.ProjectRoot, ...
                "Expanding_Window_Coefficient_History.csv"),1e-9);
        end

        function phase11IsStrictlyRecursiveAndRollingRMSEMatches(testCase)
            output = testCase.Phase11Output;
            forecasts = output.ForecastResults;
            testCase.verifyEqual(forecasts.TrainingSize,(220:261)');

            sourceRows = output.Design.PredictorSourceRows(:,2:end);
            latestPermitted = repmat( ...
                output.Design.ResponseRows-1,1,size(sourceRows,2));
            testCase.verifyLessThanOrEqual(sourceRows,latestPermitted);

            expectedFixed = rollingRMSE(forecasts.FixedError,8);
            expectedExpanding = rollingRMSE(forecasts.ExpandingError,8);
            expectedNaive = rollingRMSE(forecasts.NaiveError,8);
            testCase.verifyEqual(output.RollingFixedRMSE,expectedFixed, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(output.RollingExpandingRMSE,expectedExpanding, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(output.RollingNaiveRMSE,expectedNaive, ...
                'AbsTol',1e-12);
        end

        function phase12KPIsAndSummaryMatchCommittedOutputs(testCase)
            compareTables(testCase,testCase.Phase12Output.KPISummary, ...
                committedTable(testCase.ProjectRoot,"Final_Project_KPIs.csv"), ...
                1e-10);
            testCase.verifyEqual(testCase.Phase12Output.BestModelName, ...
                "Naive Persistence");
            testCase.verifyEqual(testCase.Phase12Output.BestRMSE, ...
                11.5333506830437,'AbsTol',1e-10);

            generatedSummary = fileread( ...
                testCase.Phase12Output.ExecutiveSummaryFile);
            committedSummary = fileread(fullfile(testCase.ProjectRoot, ...
                "results","Executive_Research_Summary.txt"));
            testCase.verifyEqual(normalizeNewlines(generatedSummary), ...
                normalizeNewlines(committedSummary));
        end

        function resultAndFigureNamesRemainUnchanged(testCase)
            expectedResults = sort([ ...
                "Executive_Research_Summary.txt", ...
                "Expanding_Window_Coefficient_History.csv", ...
                "Expanding_Window_Forecasts.csv", ...
                "Expanding_Window_Model_Leaderboard.csv", ...
                "Final_Project_KPIs.csv", ...
                "Forecast_Robustness_Results.csv", ...
                "Structural_Break_Coefficients.csv", ...
                "Structural_Break_Regime_Summary.csv", ...
                "Structural_Break_Test.csv"]);
            expectedFigures = sort([ ...
                "27_Forecast_RMSE_by_Regime.png", ...
                "28_Forecast_MAE_by_Regime.png", ...
                "29_Forecasts_and_COVID_Shock.png", ...
                "30_Pre_vs_Post_COVID_Coefficients.png", ...
                "31_Structural_Coefficient_Change.png", ...
                "32_Regime_Adjusted_R2.png", ...
                "33_GDP_Growth_Structural_Break.png", ...
                "34_Adaptive_Forecast_Comparison.png", ...
                "35_Rolling_RMSE.png", ...
                "36_Forecast_Model_Leaderboard.png", ...
                "37_Adaptive_Coefficient_Evolution.png", ...
                "38_Cumulative_Forecast_Error.png", ...
                "39_Final_Research_Dashboard.pdf", ...
                "39_Final_Research_Dashboard.png"]);

            testCase.verifyEqual(folderFileNames(testCase.Cfg.ResultsDir), ...
                expectedResults);
            testCase.verifyEqual(folderFileNames(testCase.Cfg.FiguresDir), ...
                expectedFigures);
        end
    end
end

function values = rollingRMSE(errors,window)
values = NaN(size(errors));
for index = window:numel(errors)
    rows = (index-window+1):index;
    values(index) = sqrt(mean(errors(rows).^2));
end
end

function tableValue = committedTable(projectRoot,fileName)
tableValue = readtable(fullfile(projectRoot,"results",fileName), ...
    'ReadRowNames',false);
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
