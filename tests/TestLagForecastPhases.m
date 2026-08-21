classdef TestLagForecastPhases < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        OutputRoot (1,1) string
        OutsideFolder (1,1) string
        Cfg (1,1) struct
        Phase6Output (1,1) struct
        Phase7Output (1,1) struct
        Phase8Output (1,1) struct
    end

    methods (TestClassSetup)
        function runPhasesFromOutsideRepository(testCase)
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

            testCase.Phase6Output = lag_model_comparison_06(testCase.Cfg);
            testCase.Phase7Output = dynamic_distributed_lag_07(testCase.Cfg);
            testCase.Phase8Output = out_of_sample_forecast_08(testCase.Cfg);
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
            testCase.verifyClass(testCase.Phase6Output,"struct");
            testCase.verifyClass(testCase.Phase7Output,"struct");
            testCase.verifyClass(testCase.Phase8Output,"struct");
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.csv")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.png")));
        end

        function phase6ComparisonMatchesCommittedOutputs(testCase)
            compareTables(testCase,testCase.Phase6Output.ModelComparison, ...
                committedTable(testCase.ProjectRoot,"Lag_Model_Comparison.csv"), ...
                1e-10);
            compareTables(testCase,testCase.Phase6Output.CoefficientPaths, ...
                committedTable(testCase.ProjectRoot,"Lag_Model_Coefficients.csv"), ...
                1e-11);
            compareTables(testCase,testCase.Phase6Output.BestModelSummary, ...
                committedTable(testCase.ProjectRoot,"Best_Lag_Model_Summary.csv"), ...
                1e-10);
            compareTables(testCase,testCase.Phase6Output.BestModelOutput, ...
                committedTable(testCase.ProjectRoot,"Best_Lag_Model_Output.csv"), ...
                1e-10);
        end

        function phase6PreservesSelectionAndVaryingSamples(testCase)
            testCase.verifyEqual(testCase.Phase6Output.BestLag,1);
            testCase.verifyEqual( ...
                testCase.Phase6Output.ModelComparison.Observations, ...
                (266:-1:262)');
            testCase.verifyEqual( ...
                string(testCase.Phase6Output.BestModelSummary.BestModel), ...
                "Lag 1");
        end

        function phase7MatchesCommittedOutputs(testCase)
            compareTables(testCase,testCase.Phase7Output.DynamicResults, ...
                committedTable(testCase.ProjectRoot, ...
                "Dynamic_Distributed_Lag_Results.csv"),1e-10);
            compareTables(testCase,testCase.Phase7Output.ModelSummary, ...
                committedTable(testCase.ProjectRoot,"Dynamic_Model_Summary.csv"), ...
                1e-10);
            compareTables(testCase,testCase.Phase7Output.Predictions, ...
                committedTable(testCase.ProjectRoot, ...
                "Dynamic_Model_Predictions.csv"),1e-9);
        end

        function phase7PreservesExactSpecification(testCase)
            testCase.verifySize(testCase.Phase7Output.Design.X,[262 17]);
            testCase.verifyEqual( ...
                testCase.Phase7Output.Model.CovarianceSolver,"pseudoinverse");
            testCase.verifyEqual( ...
                testCase.Phase7Output.Design.VariableNames, ...
                ["Intercept","GDPGrowth_L1", ...
                "Inflation_0","Inflation_L1","Inflation_L2", ...
                "Inflation_L3","Inflation_L4", ...
                "Unemployment_0","Unemployment_L1","Unemployment_L2", ...
                "Unemployment_L3","Unemployment_L4", ...
                "InterestRate_0","InterestRate_L1","InterestRate_L2", ...
                "InterestRate_L3","InterestRate_L4"]);
        end

        function phase8MatchesCommittedOutputs(testCase)
            compareTables(testCase,testCase.Phase8Output.ForecastCoefficients, ...
                committedTable(testCase.ProjectRoot, ...
                "Forecast_Model_Coefficients.csv"),1e-11);
            compareTables(testCase,testCase.Phase8Output.ForecastSummary, ...
                committedTable(testCase.ProjectRoot, ...
                "Out_of_Sample_Forecast_Summary.csv"),1e-11);
            compareTables(testCase,testCase.Phase8Output.ForecastResults, ...
                committedTable(testCase.ProjectRoot, ...
                "Out_of_Sample_Forecasts.csv"),1e-9);
        end

        function phase8PredictorsAreStrictlyHistorical(testCase)
            design = testCase.Phase8Output.Design;
            sourceRows = design.PredictorSourceRows(:,2:end);
            latestPermitted = repmat(design.ResponseRows-1,1,size(sourceRows,2));

            testCase.verifyLessThanOrEqual(sourceRows,latestPermitted);
            testCase.verifyFalse(any(contains( ...
                design.VariableNames(2:end),"_0")));
            testCase.verifyTrue(all(design.Dates( ...
                testCase.Phase8Output.TrainIndex) < datetime(2016,1,1)));
            testCase.verifyTrue(all(design.Dates( ...
                testCase.Phase8Output.TestIndex) >= datetime(2016,1,1)));
        end

        function resultAndFigureNamesRemainUnchanged(testCase)
            expectedResults = sort([ ...
                "Best_Lag_Model_Output.csv","Best_Lag_Model_Summary.csv", ...
                "Dynamic_Distributed_Lag_Results.csv", ...
                "Dynamic_Model_Predictions.csv","Dynamic_Model_Summary.csv", ...
                "Forecast_Model_Coefficients.csv", ...
                "Lag_Model_Coefficients.csv","Lag_Model_Comparison.csv", ...
                "Out_of_Sample_Forecast_Summary.csv", ...
                "Out_of_Sample_Forecasts.csv"]);
            expectedFigures = sort([ ...
                "15_Lag_Model_R2_Comparison.png", ...
                "16_Lag_Model_RMSE_Comparison.png", ...
                "17_Coefficient_Paths_Across_Lags.png", ...
                "18_Best_Lag_Model_Actual_vs_Predicted.png", ...
                "19_Dynamic_Model_Actual_vs_Predicted.png", ...
                "20_Inflation_Lag_Effects.png", ...
                "21_Unemployment_Lag_Effects.png", ...
                "22_Interest_Rate_Lag_Effects.png", ...
                "23_Out_of_Sample_Forecast.png", ...
                "24_Forecast_Model_Comparison.png", ...
                "25_Out_of_Sample_Forecast_Errors.png", ...
                "26_Forecast_RMSE_Comparison.png"]);

            testCase.verifyEqual(folderFileNames(testCase.Cfg.ResultsDir), ...
                expectedResults);
            testCase.verifyEqual(folderFileNames(testCase.Cfg.FiguresDir), ...
                expectedFigures);
            testCase.verifyEqual(sort(testCase.Phase6Output.FigureFiles)', ...
                expectedFigures(1:4));
            testCase.verifyEqual(sort(testCase.Phase7Output.FigureFiles)', ...
                expectedFigures(5:8));
            testCase.verifyEqual(sort(testCase.Phase8Output.FigureFiles)', ...
                expectedFigures(9:12));
        end
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
