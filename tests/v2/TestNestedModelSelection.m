classdef TestNestedModelSelection < matlab.unittest.TestCase
    %TESTNESTEDMODELSELECTION Leakage-controlled V2.4 selection tests.

    properties
        ProjectRoot string
        OutputRoot string
        Cfg struct
        Modeling table
        Information table
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=false);
            [testCase.Modeling,testCase.Information] = syntheticData(68);
        end
    end

    methods (TestMethodTeardown)
        function removeFixture(testCase)
            removeSafeTemporaryFolder(testCase.OutputRoot);
        end
    end

    methods (Test)
        function protocolCandidateSetAndGridsAreExact(testCase)
            protocol = testCase.Cfg.ModelSelectionProtocol;
            testCase.verifyEqual(protocol.MaximumARLag,4);
            testCase.verifyEqual(protocol.RidgePenaltyGrid,[0.1;1;10]);
            testCase.verifyEqual(protocol.InnerValidationQuarters,12);
            testCase.verifyEqual(protocol.MinimumTrainingObservations,40);
            testCase.verifyEqual(protocol.Candidates.Candidate,[ ...
                "Persistence";"Historical mean";"AR(1)";"AR(2)"; ...
                "AR(3)";"AR(4)";"V1-style macro OLS"; ...
                "HAC-inference macro OLS"; ...
                "Ridge macro (lambda=0.1)"; ...
                "Ridge macro (lambda=1)"; ...
                "Ridge macro (lambda=10)"]);
        end

        function foldBoundariesAreExactAndOuterTargetsUntouched(testCase)
            prepared = prepare(testCase);
            [folds,outer] = macro.v2.buildNestedValidationFolds( ...
                prepared,testCase.Cfg.ModelSelectionProtocol);
            testCase.verifyEqual(outer,(61:64)');
            first = folds(folds.OuterIndex == 61,:);
            testCase.verifyEqual(first.ValidationIndex,(49:60)');
            testCase.verifyEqual(first.TrainingStartIndex,ones(12,1));
            testCase.verifyEqual(first.TrainingEndIndex,(48:59)');
            testCase.verifyEqual(first.TrainingObservations,(48:59)');
            testCase.verifyTrue(all(first.TrainingEndIndex < ...
                first.ValidationIndex));
            testCase.verifyTrue(all(first.ValidationIndex < first.OuterIndex));
        end

        function foldsContainNoUnavailableTargetsOrVintages(testCase)
            prepared = prepare(testCase);
            folds = macro.v2.buildNestedValidationFolds( ...
                prepared,testCase.Cfg.ModelSelectionProtocol);
            testCase.verifyLessThanOrEqual( ...
                folds.MaxTrainingTargetReleaseDate, ...
                folds.ValidationForecastOrigin);
            testCase.verifyLessThanOrEqual( ...
                folds.MaxTrainingPredictorAvailabilityDate, ...
                folds.ValidationForecastOrigin);
            testCase.verifyLessThanOrEqual( ...
                folds.ValidationPredictorAvailabilityDate, ...
                folds.ValidationForecastOrigin);
            testCase.verifyLessThanOrEqual( ...
                prepared.MaximumPredictorAvailabilityDate, ...
                prepared.Data.ForecastOrigin);
            testCase.verifyLessThan(prepared.PredictorSourceRows(:,1), ...
                prepared.OriginalRows+1);
        end

        function futureVintageAndIncompleteRowsFailClearly(testCase)
            future = testCase.Information;
            future.LatestSelectedVintageStart(1) = ...
                future.ForecastOrigin(1)+days(1);
            testCase.verifyError(@() macro.v2.prepareNestedModelingData( ...
                testCase.Modeling,future, ...
                testCase.Cfg.ModelSelectionProtocol), ...
                "macro:v2:validateAvailability:FutureInformation");
            incomplete = testCase.Modeling;
            incomplete.InformationSetComplete(10) = false;
            testCase.verifyError(@() macro.v2.prepareNestedModelingData( ...
                incomplete,testCase.Information, ...
                testCase.Cfg.ModelSelectionProtocol), ...
                "macro:v2:prepareNestedModelingData:IncompleteInformationSet");
        end

        function gappedAndInsufficientHistoriesFailClearly(testCase)
            gapped = testCase.Modeling;
            gapped(20,:) = [];
            gappedInformation = testCase.Information( ...
                testCase.Information.TargetQuarter ~= ...
                testCase.Modeling.TargetQuarter(20),:);
            testCase.verifyError(@() macro.v2.prepareNestedModelingData( ...
                gapped,gappedInformation, ...
                testCase.Cfg.ModelSelectionProtocol), ...
                "macro:v2:prepareNestedModelingData:QuarterlyGap");
            testCase.verifyError(@() macro.v2.prepareNestedModelingData( ...
                testCase.Modeling(1:50,:), ...
                testCase.Information(1:200,:), ...
                testCase.Cfg.ModelSelectionProtocol), ...
                "macro:v2:prepareNestedModelingData:InsufficientHistory");
        end

        function tieBreakingIsDeterministic(testCase)
            scores = table([1;1;1],[3;2;9],[NaN;NaN;0.1], ...
                ["valid";"valid";"valid"],VariableNames={ ...
                'ValidationRMSE','Priority','RidgeLambda','Status'});
            selected = macro.v2.selectBestCandidate( ...
                scores,testCase.Cfg.ModelSelectionProtocol);
            testCase.verifyEqual(selected.Priority,2);
            testCase.verifyEqual(selected.RidgeLambda,NaN);
        end

        function handWorkedARSequenceSelectsAROne(testCase)
            output = runAnalysis(testCase,false);
            testCase.verifyTrue(all(output.SelectedModels.SelectedModel == ...
                "AR(1)"));
            arScores = output.CandidateScores( ...
                output.CandidateScores.Candidate == "AR(1)",:);
            testCase.verifyLessThan(max(arScores.ValidationRMSE),1e-10);
            second = runAnalysis(testCase,false);
            testCase.verifyEqual(second.SelectedModels,output.SelectedModels);
            testCase.verifyEqual(second.CandidateScores, ...
                output.CandidateScores);
        end

        function ridgeUsesOnlyDeclaredTrainingFoldParameters(testCase)
            output = runAnalysis(testCase,false);
            ridge = output.CandidateScores.ModelFamily == "RidgeMacro";
            testCase.verifyTrue(all(ismember( ...
                output.CandidateScores.RidgeLambda(ridge), ...
                testCase.Cfg.ModelSelectionProtocol.RidgePenaltyGrid)));
            prepared = output.PreparedData;
            candidate = testCase.Cfg.ModelSelectionProtocol.Candidates(9,:);
            fit = macro.v2.forecastCandidate(prepared,(1:48)',49,candidate);
            testCase.verifyEqual(fit.TrainingMean, ...
                mean(prepared.MacroX(1:48,2:end),1),AbsTol=1e-14);
            testCase.verifyEqual(fit.TrainingScale, ...
                std(prepared.MacroX(1:48,2:end),0,1),AbsTol=1e-14);
        end

        function rankDeficientOLSIsExplicit(testCase)
            prepared = prepare(testCase);
            prepared.MacroX(:,2:end) = 1;
            candidate = testCase.Cfg.ModelSelectionProtocol.Candidates(7,:);
            fit = macro.v2.forecastCandidate(prepared,(1:48)',49,candidate);
            testCase.verifyEqual(fit.Status,"invalid-design");
            testCase.verifyTrue(contains(fit.Diagnostic, ...
                "RankDeficientDesign"));
            testCase.verifyTrue(isnan(fit.Forecast));
        end

        function mandatoryV1BenchmarkRowsAndMetricsArePresent(testCase)
            output = runAnalysis(testCase,false);
            models = unique(output.Forecasts.ForecastModel,"stable");
            testCase.verifyEqual(models,["Nested selected";"Persistence"; ...
                "V1 fixed historical OLS";"V1 expanding OLS"]);
            testCase.verifyEqual(height(output.Forecasts), ...
                4*height(output.SelectedModels));
            testCase.verifyTrue(all(ismember(["Nested selected"; ...
                "Persistence"],output.Performance.ForecastModel)));
        end

        function outputFilesSchemasAndIsolationAreStable(testCase)
            output = runAnalysis(testCase,true);
            expected = ["Time_Series_Validation_Folds.csv"; ...
                "Candidate_Model_Validation_Scores.csv"; ...
                "Selected_Model_By_Forecast_Origin.csv"; ...
                "Nested_OOS_Forecasts.csv"; ...
                "Model_Selection_Stability.csv"; ...
                "Nested_Forecast_Performance.csv"];
            testCase.verifyEqual(fileNames(output.ResultFiles),expected);
            testCase.verifyTrue(all(isfile(output.ResultFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.ResultFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
            testCase.verifyEqual( ...
                output.SelectedModels.Properties.VariableNames,{ ...
                'TargetQuarter','ForecastOrigin','SelectedModel', ...
                'SelectedFamily','SelectedARLag','SelectedRidgeLambda', ...
                'InnerValidationRMSE','InnerValidationMAE', ...
                'OuterTrainingObservations', ...
                'LatestPredictorAvailabilityDate'});
        end

        function figuresRemainInV2Root(testCase)
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=true);
            output = runAnalysis(testCase,true);
            expected = ["V2_Nested_Model_Selection_Frequency.png"; ...
                "V2_Nested_OOS_Forecasts.png"; ...
                "V2_Inner_Validation_RMSE.png"];
            testCase.verifyEqual(fileNames(output.FigureFiles),expected);
            testCase.verifyTrue(all(isfile(output.FigureFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.FigureFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
        end
    end

    methods (Access=private)
        function value = prepare(testCase)
            value = macro.v2.prepareNestedModelingData( ...
                testCase.Modeling,testCase.Information, ...
                testCase.Cfg.ModelSelectionProtocol);
        end

        function output = runAnalysis(testCase,saveOutputs)
            output = macro.v2.runNestedModelSelection(testCase.Cfg, ...
                ModelingDataset=testCase.Modeling, ...
                InformationSet=testCase.Information, ...
                SaveOutputs=saveOutputs);
        end
    end
end

function [modeling,information] = syntheticData(n)
TargetQuarter = datetime(2000,1,1)+calmonths(3*(0:n-1)');
OriginRule = repmat("primary-early-quarter",n,1);
ForecastOrigin = TargetQuarter+days(44);
InformationSetComplete = true(n,1);
target = zeros(n,1);
target(1) = 2;
for index = 2:n
    target(index) = 0.5+0.7*target(index-1);
end
GDPGrowth_L1 = [0;target(1:end-1)];
row = (1:n)';
Inflation_L1 = 2+sin(row/5)+0.01*row;
Unemployment_L1 = 5+cos(row/7)+0.005*row;
InterestRate_L1 = 1.5+sin(row/9)-0.003*row;
TargetGDPGrowthFirstRelease = target;
TargetFirstReleaseDate = dateshift(TargetQuarter,"end","quarter")+days(30);
TargetVintageStart = TargetFirstReleaseDate;
PriorGDPVintageStart = TargetFirstReleaseDate;
modeling = table(TargetQuarter,OriginRule,ForecastOrigin, ...
    InformationSetComplete,GDPGrowth_L1,Inflation_L1,Unemployment_L1, ...
    InterestRate_L1,TargetGDPGrowthFirstRelease,TargetFirstReleaseDate, ...
    TargetVintageStart,PriorGDPVintageStart);

featureNames = ["GDPGrowth_L1";"Inflation_L1"; ...
    "Unemployment_L1";"InterestRate_L1"];
TargetQuarterInfo = repelem(TargetQuarter,4);
OriginRuleInfo = repelem(OriginRule,4);
ForecastOriginInfo = repelem(ForecastOrigin,4);
Feature = repmat(featureNames,n,1);
Value = zeros(4*n,1);
for index = 1:n
    rows = (4*index-3):(4*index);
    Value(rows) = [GDPGrowth_L1(index);Inflation_L1(index); ...
        Unemployment_L1(index);InterestRate_L1(index)];
end
IsComplete = true(4*n,1);
LatestSelectedVintageStart = ForecastOriginInfo-days(5);
information = table(TargetQuarterInfo,OriginRuleInfo,ForecastOriginInfo, ...
    Feature,Value,IsComplete,LatestSelectedVintageStart,VariableNames={ ...
    'TargetQuarter','OriginRule','ForecastOrigin','Feature','Value', ...
    'IsComplete','LatestSelectedVintageStart'});
end

function names = fileNames(paths)
names = strings(numel(paths),1);
for index = 1:numel(paths)
    [~,name,extension] = fileparts(paths(index));
    names(index) = string(name)+string(extension);
end
end

function paths = canonical(paths)
for index = 1:numel(paths)
    paths(index) = string(java.io.File(char(paths(index))).getCanonicalPath());
end
end

function removeSafeTemporaryFolder(folderPath)
if strlength(folderPath) == 0 || ~isfolder(folderPath)
    return;
end
canonicalPath = string(java.io.File(char(folderPath)).getCanonicalPath());
temporaryRoot = string(java.io.File(char(tempdir)).getCanonicalPath());
if ~startsWith(lower(canonicalPath),lower(temporaryRoot+string(filesep)))
    error("TestNestedModelSelection:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonicalPath);
end
rmdir(canonicalPath,"s");
end
