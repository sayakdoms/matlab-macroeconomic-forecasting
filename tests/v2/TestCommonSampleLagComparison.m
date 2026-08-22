classdef TestCommonSampleLagComparison < matlab.unittest.TestCase
    %TESTCOMMONSAMPLELAGCOMPARISON Equal-sample V2.3 lag-design tests.

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
        function protocolFixesCandidateLagsAndInterpretation(testCase)
            protocol = testCase.Cfg.LagComparisonProtocol;
            testCase.verifyEqual(protocol.CandidateLags,(0:4)');
            testCase.verifyEqual(protocol.MaximumLag,4);
            testCase.verifyEqual(protocol.V1SelectedLag,1);
            testCase.verifyTrue(contains(protocol.Interpretation, ...
                "not forecast evidence"));
        end

        function defaultV2ConfigurationDetectsRepositoryRoot(testCase)
            cfg = macro.v2.projectConfig();
            testCase.verifyEqual(canonical(cfg.ProjectRoot), ...
                canonical(testCase.ProjectRoot));
            testCase.verifyTrue(contains(canonical(cfg.OutputRoot), ...
                canonical(testCase.ProjectRoot)+string(filesep)+ ...
                "v2_outputs"));
        end

        function allCandidatesShareDatesSizesAndResponse(testCase)
            data = syntheticQuarterlyData(12);
            reference = macro.v2.buildCommonSampleLagDesign(data,0);
            testCase.verifyEqual(reference.Observations,8);
            testCase.verifyEqual(reference.ResponseRows,(5:12)');
            for lag = 1:4
                design = macro.v2.buildCommonSampleLagDesign(data,lag);
                testCase.verifyEqual(design.Dates,reference.Dates);
                testCase.verifyEqual(design.Observations, ...
                    reference.Observations);
                testCase.verifyEqual(design.Y,reference.Y);
                testCase.verifyEqual(design.ResponseRows, ...
                    reference.ResponseRows);
            end
        end

        function eachLagColumnAlignsToEconomicQuarter(testCase)
            data = syntheticQuarterlyData(12);
            responseRows = (5:12)';
            for lag = 0:4
                design = macro.v2.buildCommonSampleLagDesign(data,lag);
                predictorRows = responseRows-lag;
                expectedX = [ones(8,1),data.Inflation(predictorRows), ...
                    data.Unemployment(predictorRows), ...
                    data.InterestRate(predictorRows)];
                testCase.verifyEqual(design.X,expectedX);
                testCase.verifyEqual(design.PredictorRows,predictorRows);
                testCase.verifyEqual( ...
                    design.PredictorSourceRows(:,2:end), ...
                    repmat(predictorRows,1,3));
            end
        end

        function positiveLagsContainNoContemporaneousInformation(testCase)
            data = syntheticQuarterlyData(12);
            for lag = 1:4
                design = macro.v2.buildCommonSampleLagDesign(data,lag);
                sourceRows = design.PredictorSourceRows(:,2:end);
                latestAllowed = repmat(design.ResponseRows-1,1,3);
                testCase.verifyLessThanOrEqual(sourceRows,latestAllowed);
            end
            contemporaneous = macro.v2.buildCommonSampleLagDesign(data,0);
            testCase.verifyEqual( ...
                contemporaneous.PredictorSourceRows(:,2:end), ...
                repmat(contemporaneous.ResponseRows,1,3));
        end

        function manuallyTruncatedV1DesignsMatch(testCase)
            data = syntheticQuarterlyData(12);
            for lag = 0:4
                varying = macro.buildCommonLagDesign(data,lag);
                common = macro.v2.buildCommonSampleLagDesign(data,lag);
                retained = varying.ResponseRows >= 5;
                testCase.verifyEqual(varying.X(retained,:),common.X);
                testCase.verifyEqual(varying.Y(retained),common.Y);
                testCase.verifyEqual(varying.Dates(retained),common.Dates);
                testCase.verifyEqual( ...
                    varying.PredictorSourceRows(retained,:), ...
                    common.PredictorSourceRows);
            end
        end

        function missingQuarterFailsClearly(testCase)
            data = syntheticQuarterlyData(12);
            data(6,:) = [];
            testCase.verifyError(@() ...
                macro.v2.buildCommonSampleLagDesign(data,2), ...
                "macro:validateQuarterlyData:QuarterlyGap");
        end

        function insufficientHistoryAndInvalidLagFailClearly(testCase)
            data = syntheticQuarterlyData(8);
            testCase.verifyError(@() ...
                macro.v2.buildCommonSampleLagDesign(data,2), ...
                "macro:v2:buildCommonSampleLagDesign:InsufficientHistory");
            testCase.verifyError(@() ...
                macro.v2.buildCommonSampleLagDesign( ...
                syntheticQuarterlyData(12),5), ...
                "macro:v2:buildCommonSampleLagDesign:LagExceedsMaximum");
        end

        function committedDataUsesExactly262CommonObservations(testCase)
            data = readtable(fullfile(testCase.ProjectRoot,"data", ...
                "Macroeconomic_Data_Quarterly.csv"),TextType="string");
            reference = macro.v2.buildCommonSampleLagDesign(data,0);
            testCase.verifyEqual(reference.Observations,262);
            testCase.verifyEqual(reference.ResponseRows,(5:266)');
            for lag = 1:4
                design = macro.v2.buildCommonSampleLagDesign(data,lag);
                testCase.verifyEqual(design.Y,reference.Y);
                testCase.verifyEqual(design.Dates,reference.Dates);
            end
        end

        function analysisMatchesDirectOLSAndPreservesV1Baseline(testCase)
            output = macro.v2.runCommonSampleLagComparison(testCase.Cfg);
            data = readtable(fullfile(testCase.ProjectRoot,"data", ...
                "Macroeconomic_Data_Quarterly.csv"),TextType="string");
            for lag = 0:4
                design = macro.v2.buildCommonSampleLagDesign(data,lag);
                direct = macro.estimateOLS(design.X,design.Y);
                row = lag+1;
                testCase.verifyEqual( ...
                    output.CommonComparison.AdjustedRSquared(row), ...
                    direct.AdjustedRSquared,AbsTol=1e-14);
                testCase.verifyEqual(output.CommonComparison.AIC(row), ...
                    direct.AIC,AbsTol=1e-12);
                testCase.verifyEqual(output.CommonComparison.BIC(row), ...
                    direct.BIC,AbsTol=1e-12);
                testCase.verifyEqual(output.CommonComparison.RMSE(row), ...
                    direct.RMSE,AbsTol=1e-14);
            end
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Lag_Model_Comparison.csv"),TextType="string");
            testCase.verifyEqual(output.BaselineComparison,committed);
            testCase.verifyEqual(output.V1SelectedLag,1);
            testCase.verifyEqual( ...
                output.CombinedComparison.V1Observations,[266;265;264;263;262]);
        end

        function outputsAreIsolatedLabeledAndSchemaStable(testCase)
            output = macro.v2.runCommonSampleLagComparison(testCase.Cfg);
            expected = ["V1_Varying_vs_V2_Common_Sample_Lags.csv"; ...
                "Common_Sample_Lag_Coefficients.csv"; ...
                "Common_Sample_Lag_Ranking.csv"];
            testCase.verifyEqual(fileNames(output.ResultFiles),expected);
            testCase.verifyTrue(all(isfile(output.ResultFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.ResultFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
            testCase.verifyTrue(all(contains( ...
                output.CommonComparison.Interpretation, ...
                "not forecast evidence")));
            testCase.verifyEqual(output.CommonComparison.Observations, ...
                repmat(262,5,1));
            testCase.verifyEqual(output.Coefficients.Properties.VariableNames, ...
                {'Model','Lag','Variable','Coefficient','Interpretation'});
        end

        function figuresUseOnlyIsolatedV2Root(testCase)
            cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot,GenerateFigures=true);
            output = macro.v2.runCommonSampleLagComparison(cfg);
            expected = ["V2_Common_Sample_Lag_Fit.png"; ...
                "V2_Common_Sample_Information_Criteria.png"];
            testCase.verifyEqual(fileNames(output.FigureFiles),expected);
            testCase.verifyTrue(all(isfile(output.FigureFiles)));
            testCase.verifyTrue(all(startsWith(canonical(output.FigureFiles), ...
                canonical(testCase.OutputRoot)+string(filesep))));
        end
    end
end

function data = syntheticQuarterlyData(numRows)
observation_date = datetime(2000,1,1)+calmonths(3*(0:numRows-1)');
row = (1:numRows)';
RealGDP = 10000+row;
Unemployment = 5+sin(row/2);
CPI = 200+row;
InterestRate = 2+cos(row/3);
GDPGrowth = 1+0.2*row+sin(row);
Inflation = 2+cos(row/2);
data = table(observation_date,RealGDP,Unemployment,CPI, ...
    InterestRate,GDPGrowth,Inflation);
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
    error("TestCommonSampleLagComparison:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonicalPath);
end
rmdir(canonicalPath,"s");
end
