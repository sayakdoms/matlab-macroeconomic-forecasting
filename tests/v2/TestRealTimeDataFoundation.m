classdef TestRealTimeDataFoundation < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        FixturePath (1,1) string
        Panel table
    end

    methods (TestClassSetup)
        function loadFixture(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(fileparts( ...
                testFile))));
            testCase.FixturePath = fullfile(testCase.ProjectRoot,"tests", ...
                "fixtures","v2","alfred_four_series_fixture.csv");
            testCase.Panel = macro.v2.readVintagePanel(testCase.FixturePath);
        end
    end

    methods (Test)
        function defaultConfigurationIsV2Isolated(testCase)
            cfg = macro.v2.projectConfig(testCase.ProjectRoot);
            testCase.verifyEqual(cfg.OutputRoot, ...
                canonicalPath(fullfile(testCase.ProjectRoot,"v2_outputs")));
            testCase.verifyNotEqual(cfg.DataDir,cfg.V1DataDir);
            testCase.verifyNotEqual(cfg.ResultsDir,cfg.V1ResultsDir);
            testCase.verifyNotEqual(cfg.FiguresDir,cfg.V1FiguresDir);
            testCase.verifyEqual(cfg.ForecastProtocol.TargetSeriesID,"GDPC1");
            testCase.verifyEqual(cfg.PrimaryForecastOriginRule, ...
                "primary-early-quarter");
            testCase.verifyEqual(cfg.StrictForecastOriginRule, ...
                "strict-quarter-start");
        end

        function configurationRejectsV1Locations(testCase)
            protected = [ ...
                testCase.ProjectRoot; ...
                fullfile(testCase.ProjectRoot,"data"); ...
                fullfile(testCase.ProjectRoot,"results"); ...
                fullfile(testCase.ProjectRoot,"figures")];
            for pathIndex = 1:numel(protected)
                testCase.verifyError(@() macro.v2.projectConfig( ...
                    testCase.ProjectRoot,OutputRoot=protected(pathIndex)), ...
                    "macro:v2:projectConfig:V1OutputOverlap");
            end
        end

        function isolatedDirectoriesDoNotTouchV1Outputs(testCase)
            outputRoot = string(tempname);
            cleanup = onCleanup(@() removeSafeTemporaryFolder(outputRoot)); %#ok<NASGU>
            protectedFile = fullfile(testCase.ProjectRoot,"results", ...
                "Final_Project_KPIs.csv");
            before = fileread(protectedFile);

            cfg = macro.v2.projectConfig( ...
                testCase.ProjectRoot,OutputRoot=outputRoot);
            macro.v2.ensureOutputDirectories(cfg);

            testCase.verifyTrue(isfolder(cfg.DataDir));
            testCase.verifyTrue(isfolder(cfg.VintageDataDir));
            testCase.verifyTrue(isfolder(cfg.ResultsDir));
            testCase.verifyTrue(isfolder(cfg.FiguresDir));
            testCase.verifyEqual(fileread(protectedFile),before);
            testCase.verifyFalse(isfile(fullfile(cfg.ResultsDir, ...
                "Final_Project_KPIs.csv")));
        end

        function forecastOriginRulesAreExact(testCase)
            protocol = macro.v2.forecastProtocol();
            targetQuarter = datetime(2020,4,1);
            testCase.verifyEqual(macro.v2.forecastOrigin( ...
                targetQuarter,protocol.PrimaryOriginRule,protocol), ...
                datetime(2020,5,15));
            testCase.verifyEqual(macro.v2.forecastOrigin( ...
                targetQuarter,protocol.StrictOriginRule,protocol), ...
                datetime(2020,3,31));
        end

        function forecastOriginRejectsNonQuarterStart(testCase)
            testCase.verifyError(@() macro.v2.forecastOrigin( ...
                datetime(2020,4,2),"primary-early-quarter"), ...
                "macro:v2:forecastOrigin:InvalidTargetQuarter");
        end

        function fixtureHasCanonicalSchemaAndFourSeries(testCase)
            testCase.verifyEqual( ...
                string(testCase.Panel.Properties.VariableNames), ...
                ["SeriesID","ObservationDate","RealtimeStart", ...
                 "RealtimeEnd","Value"]);
            testCase.verifyEqual(unique(testCase.Panel.SeriesID), ...
                ["CPIAUCSL";"FEDFUNDS";"GDPC1";"UNRATE"]);
            for seriesID = unique(testCase.Panel.SeriesID)'
                seriesRows = testCase.Panel.SeriesID == seriesID;
                observationCounts = groupcounts( ...
                    testCase.Panel.ObservationDate(seriesRows));
                testCase.verifyTrue(any(observationCounts > 1), ...
                    seriesID+" must contain at least one revision.");
            end
        end

        function asOfValueExcludesFutureGDPRevisions(testCase)
            selected = macro.v2.asOfValue(testCase.Panel,"GDPC1", ...
                datetime(2020,1,1),datetime(2020,5,15));
            testCase.verifyEqual(selected.Value,95);
            testCase.verifyEqual(selected.RealtimeStart,datetime(2020,4,29));
            testCase.verifyLessThanOrEqual( ...
                selected.AvailableDate,selected.ForecastOrigin);
        end

        function futureAvailabilityFailsValidation(testCase)
            information = table(datetime(2020,5,16),datetime(2020,5,15), ...
                'VariableNames',{'AvailableDate','ForecastOrigin'});
            testCase.verifyError(@() macro.v2.validateAvailability(information), ...
                "macro:v2:validateAvailability:FutureInformation");
        end

        function primaryInformationSetIsCompleteAndLeakageFree(testCase)
            reconstructed = macro.v2.reconstructQuarterlyInformationSet( ...
                testCase.Panel,datetime(2020,4,1), ...
                "primary-early-quarter");
            information = reconstructed.InformationSet;
            testCase.verifyEqual(reconstructed.ForecastOrigin,datetime(2020,5,15));
            testCase.verifyEqual(information.Feature, ...
                ["GDPGrowth_L1";"Inflation_L1"; ...
                 "Unemployment_L1";"InterestRate_L1"]);
            expected = [ ...
                400*log(95/101); ...
                400*log(mean([258.8 259.1 258.0])/ ...
                    mean([257.1 257.9 258.3])); ...
                mean([3.5 3.6 4.5]); ...
                mean([1.54 1.57 0.66])];
            testCase.verifyEqual(information.Value,expected,'AbsTol',1e-12);
            testCase.verifyLessThanOrEqual( ...
                information.AvailableDate,information.ForecastOrigin);
            testCase.verifyFalse(any(contains( ...
                information.SourceRealtimeStarts,"2020-05-28")));
            testCase.verifyFalse(any(contains( ...
                information.SourceRealtimeStarts,"2020-06-")));
        end

        function strictQuarterStartExposesIncompleteInformation(testCase)
            testCase.verifyError(@() ...
                macro.v2.reconstructQuarterlyInformationSet( ...
                    testCase.Panel,datetime(2020,4,1), ...
                    "strict-quarter-start"), ...
                ["macro:v2:reconstructQuarterlyInformationSet:" + ...
                 "IncompleteInformationSet"]);
        end

        function targetUsesFirstPublishedGDPVintage(testCase)
            target = macro.v2.firstReleaseGDPGrowth( ...
                testCase.Panel,datetime(2020,4,1));
            testCase.verifyEqual(target.FirstReleaseDate,datetime(2020,7,30));
            testCase.verifyEqual(target.TargetGDP,80);
            testCase.verifyEqual(target.PriorQuarterGDP,93);
            testCase.verifyEqual(target.GDPGrowth,400*log(80/93), ...
                'AbsTol',1e-12);
            testCase.verifyNotEqual(target.TargetGDP,82);
        end

        function overlappingVintagesAreRejected(testCase)
            invalid = testCase.Panel(1:2,:);
            invalid.SeriesID(:) = "TEST";
            invalid.ObservationDate(:) = datetime(2020,1,1);
            invalid.RealtimeStart = [datetime(2020,2,1);datetime(2020,2,15)];
            invalid.RealtimeEnd = [datetime(2020,2,20);datetime(2020,3,1)];
            testCase.verifyError(@() macro.v2.validateVintagePanel(invalid), ...
                "macro:v2:validateVintagePanel:OverlappingVintages");
        end
    end
end

function pathOut = canonicalPath(pathIn)
pathOut = string(java.io.File(char(pathIn)).getCanonicalPath());
end

function removeSafeTemporaryFolder(folderPath)
if strlength(folderPath) == 0 || ~isfolder(folderPath)
    return;
end
canonical = canonicalPath(folderPath);
tempRoot = canonicalPath(tempdir);
if ~startsWith(lower(canonical),lower(tempRoot+string(filesep)))
    error("TestRealTimeDataFoundation:UnsafeCleanup", ...
        "Refusing to remove non-temporary folder: %s",canonical);
end
rmdir(canonical,"s");
end
