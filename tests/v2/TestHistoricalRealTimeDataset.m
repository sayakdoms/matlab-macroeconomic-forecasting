classdef TestHistoricalRealTimeDataset < matlab.unittest.TestCase
    %TESTHISTORICALREALTIMEDATASET Offline V2.1C reconstruction tests.

    properties
        ProjectRoot string
        Panel table
        OutputRoot string
        Cfg struct
        OriginalApiKey string
    end

    methods (TestMethodSetup)
        function createFixtureConfiguration(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            fixturePath = fullfile(testCase.ProjectRoot,"tests", ...
                "fixtures","v2","alfred_four_series_fixture.csv");
            testCase.Panel = macro.v2.readVintagePanel(fixturePath);
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot);
            testCase.OriginalApiKey = string(getenv("FRED_API_KEY"));
            setenv("FRED_API_KEY","");
        end
    end

    methods (TestMethodTeardown)
        function removeFixtureConfiguration(testCase)
            setenv("FRED_API_KEY",testCase.OriginalApiKey);
            removeSafeTemporaryFolder(testCase.OutputRoot);
        end
    end

    methods (Test)
        function forecastOriginsAreProgrammaticAndDeterministic(testCase)
            first = macro.v2.generateForecastOrigins(testCase.Panel);
            second = macro.v2.generateForecastOrigins(flipud(testCase.Panel));
            testCase.verifyEqual(first,second);
            testCase.verifyEqual(height(first),4);
            testCase.verifyEqual(first.TargetQuarter, ...
                [datetime(2020,1,1);datetime(2020,1,1); ...
                 datetime(2020,4,1);datetime(2020,4,1)]);
            testCase.verifyEqual(first.OriginRule, ...
                ["primary-early-quarter";"strict-quarter-start"; ...
                 "primary-early-quarter";"strict-quarter-start"]);
            testCase.verifyEqual(first.ForecastOrigin, ...
                [datetime(2020,2,14);datetime(2019,12,31); ...
                 datetime(2020,5,15);datetime(2020,3,31)]);
        end

        function coverageAndRaggedEdgesAreExplicit(testCase)
            output = build(testCase,false);
            primary = output.CoverageSummary.OriginRule == ...
                "primary-early-quarter";
            strict = output.CoverageSummary.OriginRule == ...
                "strict-quarter-start";
            testCase.verifyEqual( ...
                output.CoverageSummary.TotalOrigins,[2;2]);
            testCase.verifyEqual( ...
                output.CoverageSummary.CompleteInformationSets(primary),1);
            testCase.verifyEqual( ...
                output.CoverageSummary.CompletePercent(primary),50);
            testCase.verifyEqual( ...
                output.CoverageSummary.CompleteInformationSets(strict),0);
            testCase.verifyEqual( ...
                output.CoverageSummary.CompletePercent(strict),0);

            strictRows = output.ModelingDataset.OriginRule == ...
                "strict-quarter-start";
            testCase.verifyFalse(any( ...
                output.ModelingDataset.InformationSetComplete(strictRows)));
            testCase.verifyTrue(all(all(ismissing( ...
                output.ModelingDataset{strictRows, ...
                ["GDPGrowth_L1","Inflation_L1", ...
                 "Unemployment_L1","InterestRate_L1"]}))));
        end

        function everySelectedPredictorWasAvailableAtOrigin(testCase)
            output = build(testCase,false);
            information = output.InformationSet;
            selectedRows = ~isnat(information.LatestSelectedVintageStart);
            testCase.verifyLessThanOrEqual( ...
                information.LatestSelectedVintageStart(selectedRows), ...
                information.ForecastOrigin(selectedRows));
            for rowIndex = find(selectedRows)'
                starts = datetime(split( ...
                    information.SelectedRealtimeStarts(rowIndex),"|"), ...
                    "InputFormat","yyyy-MM-dd");
                testCase.verifyLessThanOrEqual(starts, ...
                    repmat(information.ForecastOrigin(rowIndex), ...
                    numel(starts),1));
            end
        end

        function futureGDPAndMonthlyRevisionsAreExcluded(testCase)
            output = build(testCase,false);
            rows = output.InformationSet.TargetQuarter == datetime(2020,4,1) & ...
                output.InformationSet.OriginRule == "primary-early-quarter";
            information = output.InformationSet(rows,:);
            testCase.verifyFalse(any(contains( ...
                information.SelectedRealtimeStarts,"2020-05-28")));
            testCase.verifyFalse(any(contains( ...
                information.SelectedRealtimeStarts,"2020-06-")));
            testCase.verifyFalse(any(contains( ...
                information.SelectedRealtimeStarts,"2020-08-")));

            gdp = information(information.Feature == "GDPGrowth_L1",:);
            testCase.verifyEqual(gdp.Value,400*log(95/101), ...
                AbsTol=1e-12);
            testCase.verifyEqual(gdp.SelectedRealtimeStarts, ...
                "2020-04-29|2020-04-29");
        end

        function monthlyAggregationRequiresEveryReleasedMonth(testCase)
            output = build(testCase,false);
            rows = output.InformationSet.TargetQuarter == datetime(2020,4,1) & ...
                output.InformationSet.OriginRule == "primary-early-quarter";
            information = output.InformationSet(rows,:);
            inflation = information(information.Feature == "Inflation_L1",:);
            unemployment = information( ...
                information.Feature == "Unemployment_L1",:);
            rate = information(information.Feature == "InterestRate_L1",:);
            testCase.verifyEqual(inflation.AvailableObservationCount,6);
            testCase.verifyEqual(unemployment.AvailableObservationCount,3);
            testCase.verifyEqual(rate.AvailableObservationCount,3);
            testCase.verifyEqual(inflation.Value, ...
                400*log(mean([258.8 259.1 258.0])/ ...
                mean([257.1 257.9 258.3])),AbsTol=1e-12);
            testCase.verifyEqual(unemployment.Value,mean([3.5 3.6 4.5]), ...
                AbsTol=1e-12);
            testCase.verifyEqual(rate.Value,mean([1.54 1.57 0.66]), ...
                AbsTol=1e-12);

            strictRows = output.InformationSet.TargetQuarter == ...
                datetime(2020,4,1) & output.InformationSet.OriginRule == ...
                "strict-quarter-start";
            strictInformation = output.InformationSet(strictRows,:);
            testCase.verifyTrue(all(isnan(strictInformation.Value)));
            testCase.verifyTrue(all(contains( ...
                strictInformation.IncompleteReason,"not released")));
        end

        function firstReleaseTargetsAndRevisionsAreCorrect(testCase)
            output = build(testCase,false);
            comparison = output.GDPRevisionComparison;
            q1 = comparison.TargetQuarter == datetime(2020,1,1);
            q2 = comparison.TargetQuarter == datetime(2020,4,1);
            testCase.verifyEqual(comparison.FirstReleaseTargetGDP(q1),95);
            testCase.verifyEqual(comparison.FirstReleasePriorGDP(q1),101);
            testCase.verifyEqual(comparison.FirstReleaseGDPGrowth(q1), ...
                400*log(95/101),AbsTol=1e-12);
            testCase.verifyEqual(comparison.LatestTargetGDP(q1),93);
            testCase.verifyEqual(comparison.FirstReleaseDate(q2), ...
                datetime(2020,7,30));
            testCase.verifyEqual(comparison.FirstReleaseTargetGDP(q2),80);
            testCase.verifyEqual(comparison.LatestTargetGDP(q2),82);
            testCase.verifyEqual(comparison.GDPGrowthRevision(q2), ...
                400*log(82/93)-400*log(80/93),AbsTol=1e-12);
        end

        function v1RevisionComparisonIsReadOnly(testCase)
            v1Path = fullfile(testCase.ProjectRoot,"data", ...
                "Macroeconomic_Data_Quarterly.csv");
            before = macro.v2.fileChecksum(v1Path);
            output = build(testCase,false);
            after = macro.v2.fileChecksum(v1Path);
            testCase.verifyEqual(after,before);
            testCase.verifyTrue(all(isfinite( ...
                output.GDPRevisionComparison.V1RevisedGDP)));
            testCase.verifyTrue(all(isfinite( ...
                output.GDPRevisionComparison.V1RevisedGDPGrowth)));
        end

        function savedDatasetsAndMetadataAreByteDeterministic(testCase)
            first = build(testCase,true);
            pathNames = string(fieldnames(first.Paths));
            firstText = strings(numel(pathNames),1);
            for pathIndex = 1:numel(pathNames)
                firstText(pathIndex) = string(fileread( ...
                    first.Paths.(pathNames(pathIndex))));
            end
            second = build(testCase,true);
            for pathIndex = 1:numel(pathNames)
                testCase.verifyEqual(string(fileread( ...
                    second.Paths.(pathNames(pathIndex)))), ...
                    firstText(pathIndex));
            end
            testCase.verifyEqual(second.Metadata.outputChecksums, ...
                first.Metadata.outputChecksums);
        end

        function expectedOutputsAndSchemasArePreserved(testCase)
            output = build(testCase,true);
            expectedNames = [ ...
                "Forecast_Origin_Information_Set.csv"; ...
                "GDP_First_Release_vs_Latest.csv"; ...
                "Publication_Delay_Assumptions.csv"; ...
                "RealTime_Macro_Modeling_Dataset.csv"; ...
                "RealTime_Data_Coverage_Summary.csv"; ...
                "RealTime_Macro_Dataset.metadata.json"];
            actualNames = strings(6,1);
            pathNames = string(fieldnames(output.Paths));
            for pathIndex = 1:numel(pathNames)
                testCase.verifyTrue(isfile( ...
                    output.Paths.(pathNames(pathIndex))));
                [~,name,extension] = fileparts( ...
                    output.Paths.(pathNames(pathIndex)));
                actualNames(pathIndex) = string(name)+string(extension);
            end
            testCase.verifyEqual(sort(actualNames),sort(expectedNames));
            testCase.verifyEqual(height(output.InformationSet),16);
            testCase.verifyEqual(height(output.ModelingDataset),4);
            testCase.verifyEqual(height(output.GDPRevisionComparison),2);
            testCase.verifyTrue(all(contains( ...
                output.PublicationDelayAssumptions.RaggedEdgeRule, ...
                "do not impute")));
        end

        function validatedVintageCacheMatchesDirectFixtureBuild(testCase)
            realtimeStart = datetime(2019,1,1);
            realtimeEnd = datetime(2021,1,1);
            setenv("FRED_API_KEY","offline-cache-seed-key");
            seriesIDs = ["GDPC1","CPIAUCSL","UNRATE","FEDFUNDS"];
            for seriesID = seriesIDs
                seriesPanel = testCase.Panel( ...
                    testCase.Panel.SeriesID == seriesID,:);
                observations = panelToObservations(seriesPanel);
                response = struct("count",height(seriesPanel), ...
                    "offset",0,"limit",10000, ...
                    "observations",observations);
                mock = MockAlfredHttpClient({response});
                macro.v2.fetchAlfredSeries(testCase.Cfg,seriesID, ...
                    RealtimeStart=realtimeStart,RealtimeEnd=realtimeEnd, ...
                    Refresh=true,HttpClient=@mock.request);
            end

            cached = macro.v2.buildHistoricalRealTimeDataset(testCase.Cfg, ...
                RealtimeStart=realtimeStart,RealtimeEnd=realtimeEnd, ...
                SaveOutputs=false);
            direct = macro.v2.buildHistoricalRealTimeDataset(testCase.Cfg, ...
                Panel=testCase.Panel,SaveOutputs=false);
            testCase.verifyEqual(cached.ModelingDataset, ...
                direct.ModelingDataset);
            testCase.verifyEqual(cached.InformationSet,direct.InformationSet);
            testCase.verifyEqual(cached.GDPRevisionComparison, ...
                direct.GDPRevisionComparison);
            testCase.verifyEqual(cached.Metadata.sourcePanelChecksum, ...
                direct.Metadata.sourcePanelChecksum);
        end
    end

    methods (Access=private)
        function output = build(testCase,saveOutputs)
            output = macro.v2.buildHistoricalRealTimeDataset( ...
                testCase.Cfg,Panel=testCase.Panel, ...
                SaveOutputs=saveOutputs);
        end
    end
end

function observations = panelToObservations(panel)
observations = repmat(struct("date","","realtime_start","", ...
    "realtime_end","","value",""),height(panel),1);
for rowIndex = 1:height(panel)
    observations(rowIndex).date = char(string( ...
        panel.ObservationDate(rowIndex),"yyyy-MM-dd"));
    observations(rowIndex).realtime_start = char(string( ...
        panel.RealtimeStart(rowIndex),"yyyy-MM-dd"));
    observations(rowIndex).realtime_end = char(string( ...
        panel.RealtimeEnd(rowIndex),"yyyy-MM-dd"));
    observations(rowIndex).value = char(compose( ...
        "%.17g",panel.Value(rowIndex)));
end
end

function removeSafeTemporaryFolder(folderPath)
if strlength(folderPath) == 0 || ~isfolder(folderPath)
    return;
end
canonical = string(java.io.File(char(folderPath)).getCanonicalPath());
temporaryRoot = string(java.io.File(char(tempdir)).getCanonicalPath());
if ~startsWith(lower(canonical),lower(temporaryRoot+string(filesep)))
    error("TestHistoricalRealTimeDataset:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonical);
end
rmdir(canonical,"s");
end
