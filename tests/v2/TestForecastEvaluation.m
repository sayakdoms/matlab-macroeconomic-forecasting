classdef TestForecastEvaluation < matlab.unittest.TestCase
    %TESTFORECASTEVALUATION V2.5 metric and formal-inference tests.

    properties
        ProjectRoot string
        OutputRoot string
        Cfg struct
        Forecasts table
        Scales table
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=false);
            [testCase.Forecasts,testCase.Scales] = syntheticForecasts();
        end
    end

    methods (TestMethodTeardown)
        function removeFixture(testCase)
            removeSafeTemporaryFolder(testCase.OutputRoot);
        end
    end

    methods (Test)
        function protocolIsPredeclaredAndExcludesMAPE(testCase)
            protocol = testCase.Cfg.ForecastEvaluationProtocol;
            testCase.verifyEqual(protocol.BootstrapReplications,2000);
            testCase.verifyEqual(protocol.BootstrapBlockLength,4);
            testCase.verifyEqual(protocol.BootstrapSeed,2505);
            testCase.verifyEqual(protocol.SmallSampleWarningThreshold,30);
            testCase.verifyEqual(protocol.HuberDelta,1.345);
            testCase.verifyEqual(height(protocol.Comparisons),6);
            testCase.verifyEqual(sum( ...
                protocol.Comparisons.TestFamily == "DM-HLN"),4);
            testCase.verifyEqual(sum( ...
                protocol.Comparisons.TestFamily == "Clark-West"),2);
            testCase.verifyFalse(contains(lower(jsonencode(protocol)),"mape"));
        end

        function metricsMatchHandWorkedValues(testCase)
            actual = [1;-2;3];
            forecast = [0;-1;5];
            scale = [2;2;4];
            result = macro.v2.forecastEvaluationMetrics( ...
                actual,forecast,scale);
            testCase.verifyEqual(result.MeanError,-2/3,AbsTol=1e-14);
            testCase.verifyEqual(result.RMSE,sqrt(2),AbsTol=1e-14);
            testCase.verifyEqual(result.MAE,4/3,AbsTol=1e-14);
            testCase.verifyEqual(result.MedianAbsoluteError,1,AbsTol=1e-14);
            testCase.verifyEqual(result.MASE,0.5,AbsTol=1e-14);
            testCase.verifyEqual(result.HuberLoss,0.125,AbsTol=1e-14);
            testCase.verifyEqual(result.SignAccuracyPercent,200/3, ...
                AbsTol=2e-14);
            testCase.verifyTrue(result.SignAccuracyMeaningful);
        end

        function maseUsesOnlySuppliedTrainingScale(testCase)
            actual = [1;2;3;4];
            forecast = zeros(4,1);
            first = macro.v2.forecastEvaluationMetrics( ...
                actual,forecast,ones(4,1));
            second = macro.v2.forecastEvaluationMetrics( ...
                actual,forecast,2*ones(4,1));
            testCase.verifyEqual(second.MASE,first.MASE/2,AbsTol=1e-14);
            testCase.verifyError(@() macro.v2.forecastEvaluationMetrics( ...
                actual,forecast,[1;1;0;1]), ...
                "macro:v2:forecastEvaluationMetrics:InvalidScale");
        end

        function dmAndHLNMatchHandWorkedExample(testCase)
            [model,benchmark] = handWorkedPair();
            cleanup = suppressWarning( ...
                "macro:v2:dieboldMarianoTest:SmallSample"); %#ok<NASGU>
            result = macro.v2.dieboldMarianoTest( ...
                model,benchmark,Bandwidth=0);
            testCase.verifyEqual(result.MeanLossDifferential,2/3, ...
                AbsTol=1e-14);
            testCase.verifyEqual(result.DMStatistic,sqrt(12),AbsTol=1e-13);
            testCase.verifyEqual(result.HLNCorrectionFactor,sqrt(5/6), ...
                AbsTol=1e-14);
            testCase.verifyEqual(result.Statistic,sqrt(10),AbsTol=1e-13);
            testCase.verifyGreaterThan(result.PValue,0);
            testCase.verifyLessThan(result.PValue,0.05);
        end

        function clarkWestMatchesHandWorkedExample(testCase)
            [model,benchmark] = handWorkedPair();
            cleanup = suppressWarning( ...
                "macro:v2:clarkWestTest:SmallSample"); %#ok<NASGU>
            result = macro.v2.clarkWestTest(model,benchmark,Bandwidth=0);
            testCase.verifyEqual(result.MeanLossDifferential,4/3, ...
                AbsTol=1e-14);
            testCase.verifyEqual(result.Statistic,sqrt(12),AbsTol=1e-13);
            testCase.verifyLessThan(result.PValue,0.01);
        end

        function identicalForecastsReturnNonRejection(testCase)
            [model,~] = handWorkedPair();
            cleanup1 = suppressWarning( ...
                "macro:v2:dieboldMarianoTest:SmallSample"); %#ok<NASGU>
            cleanup2 = suppressWarning( ...
                "macro:v2:clarkWestTest:SmallSample"); %#ok<NASGU>
            dm = macro.v2.dieboldMarianoTest(model,model,Bandwidth=0);
            cw = macro.v2.clarkWestTest(model,model,Bandwidth=0);
            testCase.verifyEqual(dm.PValue,1);
            testCase.verifyEqual(cw.PValue,1);
            testCase.verifyEqual(dm.Status,"identical-loss");
            testCase.verifyEqual(cw.Status,"identical-loss");
        end

        function serialCorrelationUsesHACBandwidth(testCase)
            dates = datetime(2000,1,1)+calmonths(3*(0:19)');
            actual = sin((1:20)'/3);
            modelForecast = actual-[1;filter(1,[1 -0.8],ones(19,1))]/10;
            benchmarkForecast = actual-0.4*ones(20,1);
            model = forecastTable(dates,actual,modelForecast);
            benchmark = forecastTable(dates,actual,benchmarkForecast);
            cleanup = suppressWarning( ...
                "macro:v2:dieboldMarianoTest:SmallSample"); %#ok<NASGU>
            zero = macro.v2.dieboldMarianoTest( ...
                model,benchmark,Bandwidth=0);
            hac = macro.v2.dieboldMarianoTest( ...
                model,benchmark,Bandwidth=3);
            testCase.verifyEqual(hac.HACBandwidth,3);
            testCase.verifyNotEqual(hac.DMStatistic,zero.DMStatistic);
            testCase.verifyTrue(isfinite(hac.PValue));
        end

        function blockBootstrapIsFixedSeedReproducible(testCase)
            actual = (1:12)'+sin((1:12)');
            forecast = actual+cos((1:12)')/2;
            scale = 1+0.01*(1:12)';
            first = macro.v2.blockBootstrapMetricCI( ...
                actual,forecast,scale,Replications=200,BlockLength=4,Seed=9);
            second = macro.v2.blockBootstrapMetricCI( ...
                actual,forecast,scale,Replications=200,BlockLength=4,Seed=9);
            testCase.verifyEqual(first,second);
            testCase.verifyTrue(all(first.Lower <= first.Upper | ...
                isnan(first.Lower)));
        end

        function holmAdjustmentIsMonotoneAndOrderPreserving(testCase)
            adjusted = macro.v2.holmAdjust([0.01,0.04,0.03]);
            testCase.verifyEqual(adjusted,[0.03,0.06,0.06],AbsTol=1e-14);
            [~,order] = sort([0.01,0.04,0.03]);
            testCase.verifyGreaterThanOrEqual(diff(adjusted(order)),0);
            testCase.verifyError(@() macro.v2.holmAdjust([0.1,1.1]), ...
                "macro:v2:holmAdjust:InvalidPValues");
        end

        function mismatchedDatesAndActualsFailExplicitly(testCase)
            [model,benchmark] = handWorkedPair();
            shifted = benchmark;
            shifted.TargetQuarter(2) = shifted.TargetQuarter(2)+days(1);
            testCase.verifyError(@() macro.v2.validateForecastPair( ...
                model,shifted), ...
                "macro:v2:validateForecastPair:MismatchedDates");
            changed = benchmark;
            changed.ActualGDPGrowth(1) = changed.ActualGDPGrowth(1)+1;
            testCase.verifyError(@() macro.v2.validateForecastPair( ...
                model,changed), ...
                "macro:v2:validateForecastPair:MismatchedActuals");
        end

        function analysisProducesStableSchemasAndSmallSampleWarnings(testCase)
            cleanup = suppressAllEvaluationWarnings(); %#ok<NASGU>
            output = macro.v2.runForecastEvaluation(testCase.Cfg, ...
                Forecasts=testCase.Forecasts,TrainingScales=testCase.Scales, ...
                SaveOutputs=true);
            testCase.verifyEqual(height(output.Leaderboard),4);
            testCase.verifyEqual(output.Leaderboard.Observations, ...
                12*ones(4,1));
            testCase.verifyTrue(all(output.Leaderboard.SmallSampleWarning));
            testCase.verifyFalse(any( ...
                output.Leaderboard.SignAccuracyMeaningful));
            testCase.verifyEqual(height(output.FormalTests),6);
            testCase.verifyTrue(all(output.FormalTests.Observations == 12));
            testCase.verifyTrue(all(output.FormalTests.HACBandwidth == 2));
            testCase.verifyTrue(all(output.FormalTests.HolmAdjustedPValue >= ...
                output.FormalTests.RawPValue));
            cw = output.FormalTests.TestFamily == "Clark-West";
            testCase.verifyTrue(all(strlength( ...
                output.FormalTests.ApplicabilityCaveat(cw)) > 0));
            testCase.verifyTrue(all(isfile(output.ResultFiles)));
            testCase.verifyEqual(fileNames(output.ResultFiles),[ ...
                "Forecast_Leaderboard_V2.csv"; ...
                "Forecast_Loss_By_Window.csv"; ...
                "Formal_Model_Comparison_Tests.csv"; ...
                "Forecast_Metric_Confidence_Intervals.csv"]);
            unavailable = output.LossByWindow.Window ~= ...
                "Full finalized outer sample";
            testCase.verifyTrue(all(output.LossByWindow.Status(unavailable) ~= ...
                "reported"));
        end

        function figuresStayInsideV2OutputRoot(testCase)
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=true);
            cleanup = suppressAllEvaluationWarnings(); %#ok<NASGU>
            output = macro.v2.runForecastEvaluation(testCase.Cfg, ...
                Forecasts=testCase.Forecasts,TrainingScales=testCase.Scales, ...
                SaveOutputs=true);
            testCase.verifyEqual(fileNames(output.FigureFiles),[ ...
                "V2_Cumulative_Forecast_Loss.png"; ...
                "V2_Rolling_Forecast_RMSE.png"]);
            testCase.verifyTrue(all(isfile(output.FigureFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.FigureFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
        end
    end
end

function [forecasts,scales] = syntheticForecasts()
dates = datetime(2016,1,1)+calmonths(3*(0:11)');
actual = 2+sin((1:12)'/2);
models = ["Nested selected";"Persistence"; ...
    "V1 fixed historical OLS";"V1 expanding OLS"];
TargetQuarter = repelem(dates,4);
ForecastModel = repmat(models,12,1);
ActualGDPGrowth = repelem(actual,4);
Forecast = NaN(48,1);
for index = 1:12
    rows = (4*index-3):(4*index);
    Forecast(rows) = [actual(index)+0.1*cos(index); ...
        actual(index)+0.3;actual(index)+0.2*sin(index); ...
        actual(index)+0.25*cos(index/2)];
end
forecasts = table(TargetQuarter,ForecastModel,ActualGDPGrowth,Forecast);
TrainingNaiveScale = 1+0.01*(1:12)';
scales = table(dates,TrainingNaiveScale, ...
    VariableNames={'TargetQuarter','TrainingNaiveScale'});
end

function [model,benchmark] = handWorkedPair()
dates = datetime(2000,1,1)+calmonths(3*(0:5)');
actual = (1:6)';
model = forecastTable(dates,actual,[1;2;2;4;4;6]);
benchmark = forecastTable(dates,actual,[0;1;2;3;4;5]);
end

function value = forecastTable(dates,actual,forecast)
value = table(dates,actual,forecast,VariableNames={ ...
    'TargetQuarter','ActualGDPGrowth','Forecast'});
end

function cleanup = suppressWarning(identifier)
state = warning("query",identifier);
warning("off",identifier);
cleanup = onCleanup(@() warning(state.state,identifier));
end

function cleanup = suppressAllEvaluationWarnings()
identifiers = ["macro:v2:runForecastEvaluation:VerySmallSample"; ...
    "macro:v2:dieboldMarianoTest:SmallSample"; ...
    "macro:v2:clarkWestTest:SmallSample"];
states = cell(numel(identifiers),1);
for index = 1:numel(identifiers)
    states{index} = warning("query",identifiers(index));
    warning("off",identifiers(index));
end
cleanup = onCleanup(@() restoreWarnings(states,identifiers));
end

function restoreWarnings(states,identifiers)
for index = 1:numel(identifiers)
    warning(states{index}.state,identifiers(index));
end
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
    error("TestForecastEvaluation:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonicalPath);
end
rmdir(canonicalPath,"s");
end
