classdef TestRegressionDiagnosticPhases < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        OutputRoot (1,1) string
        OutsideFolder (1,1) string
        Cfg (1,1) struct
        Phase4Output (1,1) struct
        Phase5Output (1,1) struct
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

            testCase.Phase4Output = regression_model_04(testCase.Cfg);
            testCase.Phase5Output = diagnostics_05(testCase.Cfg);
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
            testCase.verifyClass(testCase.Phase4Output,"struct");
            testCase.verifyClass(testCase.Phase5Output,"struct");
            testCase.verifyEqual( ...
                testCase.Phase4Output.Model.Coefficients, ...
                testCase.Phase5Output.Model.Coefficients, ...
                'AbsTol',1e-14);
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.csv")));
            testCase.verifyEmpty(dir(fullfile(testCase.OutsideFolder,"*.png")));
        end

        function phase4TablesMatchCommittedOutputs(testCase)
            compareNumericTable( ...
                testCase.Phase4Output.RegressionResults, ...
                readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Regression_Results.csv")),1e-12);
            compareNumericTable( ...
                testCase.Phase4Output.ModelSummary, ...
                readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Model_Summary.csv")),1e-12);

            committedOutput = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Predictions_Residuals.csv"));
            actualOutput = testCase.Phase4Output.ModelOutput;
            testCase.verifyEqual(actualOutput.Date,toDatetime(committedOutput.Date));
            testCase.verifyEqual(actualOutput{:,2:end}, ...
                committedOutput{:,2:end},'AbsTol',1e-11);
        end

        function phase4ModelUsesExactBaselineConvention(testCase)
            model = testCase.Phase4Output.Model;
            testCase.verifyEqual(model.CovarianceSolver,"inverse");
            testCase.verifyEqual(model.Observations,266);
            testCase.verifyEqual(model.RSquared,0.0197694308583247, ...
                'AbsTol',1e-14);
            testCase.verifyEqual(model.AdjustedRSquared, ...
                0.00854541670784748,'AbsTol',1e-14);
            testCase.verifyEqual(model.ResidualStandardError, ...
                4.19072751635763,'AbsTol',1e-12);
        end

        function phase5DiagnosticsMatchCommittedOutputs(testCase)
            committedVIF = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "VIF_Results.csv"));
            actualVIF = testCase.Phase5Output.VIFResults;
            testCase.verifyEqual(string(actualVIF.Predictor), ...
                string(committedVIF.Predictor));
            testCase.verifyEqual(actualVIF.VIF,committedVIF.VIF, ...
                'AbsTol',1e-12);

            committedSummary = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Diagnostic_Summary.csv"));
            actualSummary = testCase.Phase5Output.DiagnosticSummary;
            testCase.verifyEqual(actualSummary.Properties.VariableNames, ...
                committedSummary.Properties.VariableNames);
            testCase.verifyEqual(actualSummary{:,1:4}, ...
                committedSummary{:,1:4},'AbsTol',1e-12);
            if all(isfinite(committedSummary{:,5:6}),"all")
                testCase.verifyEqual(actualSummary{:,5:6}, ...
                    committedSummary{:,5:6},'AbsTol',1e-12);
            else
                testCase.verifyTrue(exist('archtest','file') == 2);
                testCase.verifyTrue(all(isfinite(actualSummary{:,5:6}),"all"));
            end
        end

        function resultAndFigureNamesRemainUnchanged(testCase)
            expectedResults = sort([ ...
                "Diagnostic_Summary.csv","OLS_Model_Summary.csv", ...
                "OLS_Predictions_Residuals.csv", ...
                "OLS_Regression_Results.csv","VIF_Results.csv"]);
            expectedFigures = sort([ ...
                "07_Actual_vs_Predicted_GDP_Growth.png", ...
                "08_OLS_Residuals.png","09_Residual_Distribution.png", ...
                "10_Observed_vs_Fitted.png","11_Residual_ACF.png", ...
                "12_Residual_vs_Fitted.png","13_Residual_QQ_Plot.png", ...
                "14_Standardized_Residuals.png"]);

            testCase.verifyEqual(folderFileNames(testCase.Cfg.ResultsDir), ...
                expectedResults);
            testCase.verifyEqual(folderFileNames(testCase.Cfg.FiguresDir), ...
                expectedFigures);
            testCase.verifyEqual(sort(testCase.Phase4Output.FigureFiles)', ...
                expectedFigures(1:4));
            testCase.verifyEqual(sort(testCase.Phase5Output.FigureFiles)', ...
                expectedFigures(5:8));
        end

        function optionalToolboxBehaviorIsExplicit(testCase)
            summary = testCase.Phase5Output.DiagnosticSummary;
            if exist('jbtest','file') == 2
                testCase.verifyFalse(isnan(summary.JBRejectNormality));
                testCase.verifyFalse(isnan(summary.JBPValue));
            else
                testCase.verifyTrue(isnan(summary.JBRejectNormality));
                testCase.verifyTrue(isnan(summary.JBPValue));
            end

            if exist('archtest','file') == 2
                testCase.verifyFalse(isnan(summary.ARCHRejectHomoscedasticity));
                testCase.verifyFalse(isnan(summary.ARCHPValue));
            else
                testCase.verifyTrue(isnan(summary.ARCHRejectHomoscedasticity));
                testCase.verifyTrue(isnan(summary.ARCHPValue));
            end

            testCase.verifyTrue(isfile(fullfile(testCase.Cfg.FiguresDir, ...
                "13_Residual_QQ_Plot.png")));
        end
    end
end

function compareNumericTable(actual,expected,tolerance)
assert(isequal(actual.Properties.VariableNames, ...
    expected.Properties.VariableNames));
textColumns = varfun(@(value) isstring(value) || iscellstr(value), ...
    actual,'OutputFormat','uniform');
for index = find(textColumns)
    assert(isequal(string(actual{:,index}),string(expected{:,index})));
end
for index = find(~textColumns)
    difference = abs(actual{:,index}-expected{:,index});
    assert(all(difference <= tolerance,"all"));
end
end

function names = folderFileNames(folderPath)
listing = dir(folderPath);
listing = listing(~[listing.isdir]);
names = sort(string({listing.name}));
end

function dates = toDatetime(values)
if isdatetime(values)
    dates = values;
else
    dates = datetime(values);
end
dates = dates(:);
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
