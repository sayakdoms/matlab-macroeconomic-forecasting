classdef TestStationarityHAC < matlab.unittest.TestCase
    %TESTSTATIONARITYHAC Deterministic V2.2 diagnostics and inference tests.

    properties
        ProjectRoot string
        OutputRoot string
        Cfg struct
    end

    methods (TestMethodSetup)
        function createConfiguration(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=false);
        end
    end

    methods (TestMethodTeardown)
        function removeConfiguration(testCase)
            removeSafeTemporaryFolder(testCase.OutputRoot);
        end
    end

    methods (Test)
        function protocolPredeclaresTermsLagsAndBandwidth(testCase)
            protocol = macro.v2.inferenceProtocol();
            testCase.verifyEqual(protocol.ADFMaximumLagCap,8);
            testCase.verifyEqual(protocol.ADFLagBoundRule, ...
                "min(8,floor(12*(n/100)^(1/4)),floor((n-5)/2))");
            testCase.verifyEqual(protocol.ADFLagSelectionCriterion, ...
                "AIC on a common pmax-trimmed sample");
            testCase.verifyEqual(protocol.BandwidthRule, ...
                "min(n-1,floor(4*(n/100)^(2/9)))");
            specs = protocol.Specifications;
            testCase.verifyEqual(specs.ADFModel( ...
                ismember(specs.Variable,["RealGDP","CPI"])),["TS";"TS"]);
            testCase.verifyFalse(any(specs.KPSSTrend( ...
                ismember(specs.Variable,["Unemployment","InterestRate"]))));
        end

        function stationaryARProcessIsDetected(testCase)
            rng(42,"twister");
            series = filter(1,[1 -0.5],randn(500,1));
            diagnostic = macro.v2.stationarityDiagnostics( ...
                series,"StationaryAR",ADFModel="ARD",KPSSTrend=false);
            testCase.verifyTrue(diagnostic.ADFRejectUnitRoot);
            testCase.verifyFalse(diagnostic.KPSSRejectStationarity);
            testCase.verifyEqual(diagnostic.Conclusion,"Stationary");
        end

        function randomWalkIsDetected(testCase)
            rng(42,"twister");
            series = cumsum(randn(500,1));
            diagnostic = macro.v2.stationarityDiagnostics( ...
                series,"RandomWalk",ADFModel="ARD",KPSSTrend=false);
            testCase.verifyFalse(diagnostic.ADFRejectUnitRoot);
            testCase.verifyTrue(diagnostic.KPSSRejectStationarity);
            testCase.verifyEqual(diagnostic.Conclusion,"Nonstationary");
        end

        function deterministicTrendUsesTrendSpecification(testCase)
            rng(42,"twister");
            series = 0.03*(1:500)'+ ...
                filter(1,[1 -0.4],randn(500,1));
            diagnostic = macro.v2.stationarityDiagnostics( ...
                series,"TrendStationary",ADFModel="TS",KPSSTrend=true);
            testCase.verifyEqual(diagnostic.ADFModel,"TS");
            testCase.verifyTrue(diagnostic.KPSSTrend);
            testCase.verifyEqual(diagnostic.Conclusion,"Stationary");
        end

        function nearUnitRootIsReportedAmbiguous(testCase)
            rng(42,"twister");
            randn(500,1); %#ok<RAND>
            randn(500,1); %#ok<RAND>
            series = filter(1,[1 -0.98],randn(500,1));
            diagnostic = macro.v2.stationarityDiagnostics( ...
                series,"NearUnitRoot",ADFModel="ARD",KPSSTrend=false);
            testCase.verifyTrue(diagnostic.ADFRejectUnitRoot);
            testCase.verifyTrue(diagnostic.KPSSRejectStationarity);
            testCase.verifyEqual(diagnostic.Conclusion,"Ambiguous");
        end

        function fixedSeedLagSelectionIsReproducible(testCase)
            first = seededDiagnostic();
            second = seededDiagnostic();
            testCase.verifyEqual(first.ADFSelectedLag,second.ADFSelectedLag);
            testCase.verifyEqual(first.ADFPValue,second.ADFPValue);
            testCase.verifyEqual(first.KPSSPValue,second.KPSSPValue);
            testCase.verifyLessThanOrEqual( ...
                first.ADFSelectedLag,first.ADFMaximumLag);
            testCase.verifyTrue(first.LagSelection.CommonSample);
        end

        function handWorkedHACCovarianceMatches(testCase)
            X = [ones(6,1),(1:6)'];
            Y = [1;2;1;3;5;4];
            result = macro.v2.neweyWestCovariance(X,Y,Bandwidth=1);
            expectedCoefficients = [ ...
                0.0666666666666669;0.742857142857143];
            expectedCovariance = [ ...
                0.163256437389772,-0.0337850340136057; ...
               -0.0337850340136057,0.0117519922254617];
            testCase.verifyEqual(result.Coefficients,expectedCoefficients, ...
                AbsTol=1e-14);
            testCase.verifyEqual(result.Covariance,expectedCovariance, ...
                AbsTol=1e-14);
            testCase.verifyEqual(result.StandardErrors, ...
                sqrt(diag(expectedCovariance)),AbsTol=1e-14);
        end

        function matchesMathWorksHACWhenAvailable(testCase)
            testCase.assumeTrue(exist("hac","file") == 2, ...
                "Econometrics Toolbox hac is unavailable.");
            rng(7,"twister");
            n = 80;
            predictors = randn(n,2);
            X = [ones(n,1),predictors];
            Y = X*[1;0.5;-0.2]+filter(1,[1 -0.4],randn(n,1));
            ours = macro.v2.neweyWestCovariance(X,Y,Bandwidth=3);
            [expectedCovariance,expectedSE,expectedCoefficients] = hac( ...
                predictors,Y,Intercept=true,Weights="BT",Bandwidth=4, ...
                SmallT=false,Whiten=0,Display="off");
            testCase.verifyEqual(ours.Covariance,expectedCovariance, ...
                AbsTol=1e-12);
            testCase.verifyEqual(ours.StandardErrors,expectedSE, ...
                AbsTol=1e-12);
            testCase.verifyEqual(ours.Coefficients,expectedCoefficients, ...
                AbsTol=1e-12);
        end

        function bandwidthEdgesAndCovariancePropertiesHold(testCase)
            testCase.verifyEqual(macro.v2.bandwidthRule(1),0);
            testCase.verifyEqual(macro.v2.bandwidthRule(100),4);
            testCase.verifyEqual(macro.v2.bandwidthRule(266),4);
            testCase.verifyEqual(macro.v2.bandwidthRule(1000),6);
            X = [ones(20,1),(1:20)',sin((1:20)')];
            Y = cos((1:20)')+0.1*(1:20)';
            result = macro.v2.neweyWestCovariance(X,Y,Bandwidth=0);
            testCase.verifyEqual(result.Covariance,result.Covariance', ...
                AbsTol=1e-14);
            testCase.verifyTrue(all(isfinite(result.Covariance),"all"));
            testCase.verifyTrue(all(diag(result.Covariance) >= 0));
            testCase.verifyError(@() macro.v2.neweyWestCovariance( ...
                X,Y,Bandwidth=20), ...
                "macro:v2:neweyWestCovariance:BandwidthTooLarge");
        end

        function committedAnalysisPreservesCoefficientsAndReportsAmbiguity(testCase)
            output = macro.v2.runStationarityHACAnalysis(testCase.Cfg);
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Regression_Results.csv"),TextType="string");
            testCase.verifyEqual( ...
                output.InferenceComparison.Coefficient, ...
                committed.Coefficient,AbsTol=1e-12);
            testCase.verifyEqual(output.HACModel.Bandwidth,4);
            testCase.verifyGreaterThan( ...
                output.InferenceComparison.HACStandardError, ...
                output.InferenceComparison.ClassicalStandardError);
            results = output.StationarityResults;
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "RealGDP"),"Nonstationary");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "CPI"),"Nonstationary");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "GDPGrowth"),"Ambiguous");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "Inflation"),"Ambiguous");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "Unemployment"),"Stationary");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "InterestRate"),"Nonstationary");
            testCase.verifyEqual(results.Conclusion( ...
                results.Series == "DeltaInterestRate"),"Ambiguous");
            testCase.verifyFalse(results.ADFValid( ...
                results.Series == "DeltaInterestRate"));
            testCase.verifyTrue(contains(results.ADFDiagnostic( ...
                results.Series == "DeltaInterestRate"), ...
                "Possible multiple unit roots"));
        end

        function outputsAndFiguresUseOnlyV2Root(testCase)
            figureCfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=true);
            output = macro.v2.runStationarityHACAnalysis(figureCfg);
            expectedResults = ["Stationarity_Test_Results.csv"; ...
                "Transformation_Decisions.csv"; ...
                "Classical_vs_HAC_Inference.csv"];
            expectedFigures = ["V2_Stationarity_Diagnostics.png"; ...
                "V2_Classical_vs_HAC_Standard_Errors.png"];
            testCase.verifyEqual(fileNames(output.ResultFiles), ...
                expectedResults);
            testCase.verifyEqual(fileNames(output.FigureFiles), ...
                expectedFigures);
            testCase.verifyTrue(all(isfile(output.ResultFiles)));
            testCase.verifyTrue(all(isfile(output.FigureFiles)));
            testCase.verifyTrue(all(startsWith( ...
                canonical(output.ResultFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
            testCase.verifyTrue(all(startsWith( ...
                canonical(output.FigureFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
        end
    end
end

function diagnostic = seededDiagnostic
rng(314159,"twister");
series = filter(1,[1 -0.7],randn(350,1));
diagnostic = macro.v2.stationarityDiagnostics( ...
    series,"Seeded",ADFModel="ARD",KPSSTrend=false);
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
if ~startsWith(lower(canonicalPath), ...
        lower(temporaryRoot+string(filesep)))
    error("TestStationarityHAC:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonicalPath);
end
rmdir(canonicalPath,"s");
end
