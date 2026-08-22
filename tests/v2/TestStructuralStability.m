classdef TestStructuralStability < matlab.unittest.TestCase
    %TESTSTRUCTURALSTABILITY V2.6 ex-post regime-diagnostic tests.

    properties
        ProjectRoot string
        OutputRoot string
        Cfg struct
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=false);
            testCase.Cfg.StructuralStabilityProtocol.BreakBootstrapReplications=19;
            testCase.Cfg.StructuralStabilityProtocol.CUSUMSQSimulationReplications=200;
        end
    end

    methods (TestMethodTeardown)
        function removeFixture(testCase)
            removeSafeTemporaryFolder(testCase.OutputRoot);
        end
    end

    methods (Test)
        function protocolIsPredeclaredAndExPostOnly(testCase)
            protocol=testCase.Cfg.StructuralStabilityProtocol;
            testCase.verifyEqual(protocol.CandidateTrimFraction,0.15);
            testCase.verifyEqual(protocol.MinimumExtraRegimeObservations,5);
            testCase.verifyEqual(protocol.BreakBootstrapBlockLength,4);
            testCase.verifyEqual(protocol.V1BaselineBreakDate,datetime(2020,1,1));
            testCase.verifyTrue(protocol.ForecastUseProhibited);
            testCase.verifyFalse(protocol.MultipleBreakAnalysisImplemented);
            testCase.verifyEqual(protocol.AcuteCOVIDStart,datetime(2020,4,1));
            testCase.verifyEqual(protocol.AcuteCOVIDEnd,datetime(2020,7,1));
        end

        function fixedBreakMatchesHandCalculation(testCase)
            x=(1:20)'; X=[ones(20,1),x];
            y=1+0.2*x+3*(x>=11)+0.01*sin(x);
            dates=datetime(2000,1,1)+calmonths(3*(0:19)');
            result=macro.v2.chowBreakTest(X,y,dates,dates(11));
            pooled=y-X*(X\y);
            first=y(1:10)-X(1:10,:)*(X(1:10,:)\y(1:10));
            second=y(11:end)-X(11:end,:)*(X(11:end,:)\y(11:end));
            expected=((sum(pooled.^2)-sum(first.^2)-sum(second.^2))/2)/ ...
                ((sum(first.^2)+sum(second.^2))/(20-4));
            testCase.verifyEqual(result.Statistic,expected,RelTol=1e-11);
            testCase.verifyEqual(result.PreObservations,10);
            testCase.verifyEqual(result.PostObservations,10);
        end

        function recursiveResidualMatchesHandCalculation(testCase)
            x=(1:8)'; X=[ones(8,1),x]; y=1+0.4*x+0.1*sin(x);
            dates=datetime(2000,1,1)+calmonths(3*(0:7)');
            result=macro.v2.recursiveStabilityDiagnostics( ...
                X,y,dates,["Intercept","X"], ...
                CoefficientMinimumObservations=4,CUSUMSQReplications=50, ...
                CUSUMSQSeed=4);
            prior=X(1:2,:); beta=prior\y(1:2);
            leverage=X(3,:)*((prior'*prior)\X(3,:)');
            expected=(y(3)-X(3,:)*beta)/sqrt(1+leverage);
            testCase.verifyEqual( ...
                result.ResidualDiagnostics.RecursiveResidual(1), ...
                expected,AbsTol=1e-13);
            testCase.verifyEqual(result.CoefficientPaths.Observations(1),4);
        end

        function noBreakProcessProducesFiniteReproducibleSearch(testCase)
            prior=rng; cleanup=onCleanup(@() rng(prior)); %#ok<NASGU>
            rng(11,"twister"); n=100; x=randn(n,1);
            X=[ones(n,1),x]; y=1+0.5*x+0.2*randn(n,1);
            dates=datetime(1990,1,1)+calmonths(3*(0:n-1)');
            first=macro.v2.supWaldBreakSearch(X,y,dates, ...
                BootstrapReplications=39,BootstrapSeed=8);
            second=macro.v2.supWaldBreakSearch(X,y,dates, ...
                BootstrapReplications=39,BootstrapSeed=8);
            testCase.verifyEqual(first.SupStatistic,second.SupStatistic);
            testCase.verifyEqual(first.BootstrapSupStatistics, ...
                second.BootstrapSupStatistics);
            testCase.verifyTrue(isfinite(first.BootstrapGlobalPValue));
            testCase.verifyGreaterThan(first.BootstrapGlobalPValue,0.01);
        end

        function oneBreakProcessFindsKnownDate(testCase)
            prior=rng; cleanup=onCleanup(@() rng(prior)); %#ok<NASGU>
            rng(12,"twister"); n=120; x=randn(n,1);
            X=[ones(n,1),x]; y=1+0.4*x+0.08*randn(n,1);
            y(61:end)=5-0.8*x(61:end)+0.08*randn(60,1);
            dates=datetime(1990,1,1)+calmonths(3*(0:n-1)');
            result=macro.v2.supWaldBreakSearch(X,y,dates, ...
                BootstrapReplications=49,BootstrapSeed=9);
            quarterDistance=round(days(result.BreakDate-dates(61))/91.3125);
            testCase.verifyLessThanOrEqual(abs(quarterDistance),1);
            testCase.verifyLessThanOrEqual(result.BootstrapGlobalPValue,0.05);
        end

        function breakNearTrimmingBoundaryIsAdmissible(testCase)
            n=100; x=sin((1:n)'/7); X=[ones(n,1),x];
            y=0.1*x; y(21:end)=4-2*x(21:end);
            dates=datetime(2000,1,1)+calmonths(3*(0:n-1)');
            result=macro.v2.supWaldBreakSearch(X,y,dates, ...
                TrimFraction=.2,MinimumExtraObservations=2, ...
                BootstrapReplications=0);
            testCase.verifyEqual(result.MinimumRegimeObservations,20);
            testCase.verifyEqual(result.CandidateTable.CandidateBreakDate(1), ...
                dates(21));
            testCase.verifyEqual(result.BreakDate,dates(21));
        end

        function insufficientRegimeAndRankFailuresAreExplicit(testCase)
            n=20; dates=datetime(2000,1,1)+calmonths(3*(0:n-1)');
            X=[ones(n,1),(1:n)']; y=(1:n)';
            testCase.verifyError(@() macro.v2.supWaldBreakSearch( ...
                X,y,dates,MinimumExtraObservations=20), ...
                "macro:v2:supWaldBreakSearch:InsufficientRegimeSize");
            singular=[ones(n,1),ones(n,1)];
            testCase.verifyError(@() macro.v2.supWaldBreakSearch( ...
                singular,y,dates),"macro:v2:supWaldBreakSearch:InvalidInput");
        end

        function cusumsqSimulationIsFixedSeedReproducible(testCase)
            x=(1:50)'; X=[ones(50,1),sin(x/4)];
            y=1+0.3*X(:,2)+0.2*cos(x/3);
            dates=datetime(2000,1,1)+calmonths(3*(0:49)');
            first=macro.v2.recursiveStabilityDiagnostics(X,y,dates, ...
                ["Intercept","X"],CUSUMSQReplications=100,CUSUMSQSeed=44);
            second=macro.v2.recursiveStabilityDiagnostics(X,y,dates, ...
                ["Intercept","X"],CUSUMSQReplications=100,CUSUMSQSeed=44);
            testCase.verifyEqual(first.CUSUMSQCriticalDeviation, ...
                second.CUSUMSQCriticalDeviation);
            testCase.verifyEqual(first.ResidualDiagnostics.CUSUMSQ, ...
                second.ResidualDiagnostics.CUSUMSQ);
        end

        function empiricalAnalysisReproducesV1AndWritesStableSchemas(testCase)
            output=macro.v2.runStructuralStabilityAnalysis(testCase.Cfg);
            testCase.verifyEqual(output.Fixed2020Test.Statistic, ...
                12.4343769850432,AbsTol=1e-10);
            testCase.verifyEqual(output.Fixed2020Test.PreObservations,236);
            testCase.verifyEqual(output.Fixed2020Test.PostObservations,26);
            testCase.verifyEqual(output.SupWaldSearch.MinimumRegimeObservations,40);
            testCase.verifyFalse(output.ForecastInputsChanged);
            testCase.verifyFalse(output.MultipleBreakAnalysisImplemented);
            testCase.verifyTrue(all(output.StructuralStabilityTests.ExPostOnly(2:end)));
            testCase.verifyTrue(all(output.CandidateBreakDates.ExPostOnly));
            testCase.verifyTrue(all(output.RecursiveCoefficientPaths.ExPostOnly));
            testCase.verifyTrue(all(isfile(output.ResultFiles)));
            testCase.verifyEqual(fileNames(output.ResultFiles),[ ...
                "Structural_Stability_Tests.csv";"Candidate_Break_Dates.csv"; ...
                "Recursive_Coefficient_Paths.csv";"Regime_Summary_V2.csv"; ...
                "Recursive_Residual_Diagnostics.csv"]);
        end

        function structuralLayerCannotFeedForecastPaths(testCase)
            file=fullfile(testCase.ProjectRoot,"src","+macro","+v2", ...
                "runNestedModelSelection.m");
            before=dir(file);
            output=macro.v2.runStructuralStabilityAnalysis(testCase.Cfg);
            after=dir(file);
            testCase.verifyFalse(output.ForecastInputsChanged);
            testCase.verifyEqual(before.bytes,after.bytes);
            testCase.verifyEqual(before.datenum,after.datenum);
            testCase.verifyFalse(any(contains(string( ...
                output.StructuralStabilityTests.Scope),"real-time input")));
        end

        function figuresRemainInsideIsolatedV2Root(testCase)
            testCase.Cfg.GenerateFigures=true;
            testCase.Cfg.StructuralStabilityProtocol.BreakBootstrapReplications=0;
            output=macro.v2.runStructuralStabilityAnalysis(testCase.Cfg);
            testCase.verifyEqual(fileNames(output.FigureFiles),[ ...
                "V2_CUSUM.png";"V2_CUSUMSQ.png"; ...
                "V2_Recursive_Coefficient_Paths.png"; ...
                "V2_Sup_Wald_Break_Timeline.png"]);
            testCase.verifyTrue(all(isfile(output.FigureFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.FigureFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
        end

        function multipleBreakLogicIsExplicitlyOmitted(testCase)
            protocol=testCase.Cfg.StructuralStabilityProtocol;
            testCase.verifyFalse(protocol.MultipleBreakAnalysisImplemented);
            testCase.verifyTrue(contains(protocol.MultipleBreakReason, ...
                "do not support defensible multiple-break"));
        end
    end
end

function names=fileNames(paths)
names=strings(numel(paths),1);
for index=1:numel(paths)
    [~,name,extension]=fileparts(paths(index));
    names(index)=string(name)+string(extension);
end
end

function paths=canonical(paths)
for index=1:numel(paths)
    paths(index)=string(java.io.File(char(paths(index))).getCanonicalPath());
end
end

function removeSafeTemporaryFolder(folderPath)
if strlength(folderPath)==0 || ~isfolder(folderPath), return; end
canonicalPath=string(java.io.File(char(folderPath)).getCanonicalPath());
temporaryRoot=string(java.io.File(char(tempdir)).getCanonicalPath());
if ~startsWith(lower(canonicalPath),lower(temporaryRoot+string(filesep)))
    error("TestStructuralStability:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonicalPath);
end
rmdir(canonicalPath,"s");
end
