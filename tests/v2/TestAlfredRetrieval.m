classdef TestAlfredRetrieval < matlab.unittest.TestCase
    %TESTALFREDRETRIEVAL Offline tests for opt-in ALFRED retrieval/caching.

    properties
        ProjectRoot string
        OutputRoot string
        Cfg struct
        OriginalApiKey string
    end

    methods (TestMethodSetup)
        function createIsolatedConfiguration(testCase)
            testCase.ProjectRoot = string(fileparts(fileparts( ...
                fileparts(mfilename("fullpath")))));
            testCase.OutputRoot = string(tempname);
            testCase.Cfg = macro.v2.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=testCase.OutputRoot);
            testCase.OriginalApiKey = string(getenv("FRED_API_KEY"));
            setenv("FRED_API_KEY","");
        end
    end

    methods (TestMethodTeardown)
        function removeIsolatedConfiguration(testCase)
            setenv("FRED_API_KEY",testCase.OriginalApiKey);
            if isfolder(testCase.OutputRoot)
                rmdir(testCase.OutputRoot,"s");
            end
        end
    end

    methods (Test)
        function missingApiKeyFailsBeforeHttp(testCase)
            mock = MockAlfredHttpClient({validResponse(1,0,1, ...
                validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","1.0"))});
            testCase.verifyError(@() macro.v2.fetchAlfredSeries( ...
                testCase.Cfg,"GDPC1",RealtimeStart=datetime(2020,1,1), ...
                RealtimeEnd=datetime(2020,12,31),Refresh=true, ...
                HttpClient=@mock.request), ...
                "macro:v2:fetchAlfredSeries:MissingApiKey");
            testCase.verifyEqual(mock.CallCount,0);
        end

        function mockedValidResponseIsCachedAndValidated(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            observations = [ ...
                validObservation("2019-10-01","2020-01-30", ...
                    "2020-02-26","2.10"); ...
                validObservation("2019-10-01","2020-02-27", ...
                    "9999-12-31","2.25")];
            mock = MockAlfredHttpClient({validResponse(2,0,100,observations)});

            retrieval = fetch(testCase,"GDPC1",mock,true);

            testCase.verifyEqual(retrieval.Source,"network");
            testCase.verifyEqual(height(retrieval.Panel),2);
            testCase.verifyEqual(mock.CallCount,1);
            testCase.verifyEqual(retrieval.Metadata.rowCount,2);
            testCase.verifyEqual(retrieval.Metadata.seriesID,"GDPC1");
            testCase.verifyEqual(retrieval.Metadata.checksumAlgorithm,"SHA-256");
            testCase.verifyTrue(isfile(retrieval.DataPath));
            testCase.verifyTrue(isfile(retrieval.MetadataPath));
            testCase.verifyTrue(startsWith(canonical(retrieval.DataPath), ...
                canonical(testCase.Cfg.VintageDataDir)+string(filesep)));
            testCase.verifyEqual( ...
                macro.v2.validateVintagePanel(retrieval.Panel), ...
                retrieval.Panel);
        end

        function paginationUsesDeclaredOffsets(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            firstPage = [ ...
                validObservation("2019-10-01","2020-01-30", ...
                    "9999-12-31","2.1"); ...
                validObservation("2020-01-01","2020-04-29", ...
                    "9999-12-31","-5.0")];
            secondPage = validObservation("2020-04-01","2020-07-30", ...
                "9999-12-31","33.8");
            mock = MockAlfredHttpClient({ ...
                validResponse(3,0,2,firstPage), ...
                validResponse(3,2,2,secondPage)});

            retrieval = macro.v2.fetchAlfredSeries(testCase.Cfg,"GDPC1", ...
                RealtimeStart=datetime(2020,1,1), ...
                RealtimeEnd=datetime(2020,12,31),Refresh=true,PageSize=2, ...
                HttpClient=@mock.request);

            testCase.verifyEqual(height(retrieval.Panel),3);
            testCase.verifyEqual(mock.CallCount,2);
            testCase.verifyEqual(mock.Requests{1}.offset,0);
            testCase.verifyEqual(mock.Requests{2}.offset,2);
            testCase.verifyEqual(mock.Requests{1}.limit,2);
        end

        function emptySeriesIsRejected(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            emptyObservations = struct("date",{},"realtime_start",{}, ...
                "realtime_end",{},"value",{});
            mock = MockAlfredHttpClient({ ...
                validResponse(0,0,100,emptyObservations)});
            testCase.verifyError(@() fetch(testCase,"UNRATE",mock,true), ...
                "macro:v2:fetchAlfredSeries:EmptySeries");
        end

        function malformedObservationFieldsAreRejected(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            malformed = struct("date","2020-01-01", ...
                "realtime_start","2020-04-29","value","1.0");
            mock = MockAlfredHttpClient({validResponse(1,0,100,malformed)});
            testCase.verifyError(@() fetch(testCase,"GDPC1",mock,true), ...
                "macro:v2:fetchAlfredSeries:MalformedObservation");
        end

        function invalidRealtimeIntervalsAreRejected(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            observation = validObservation("2020-01-01","2020-05-01", ...
                "2020-04-30","1.0");
            mock = MockAlfredHttpClient({validResponse(1,0,100,observation)});
            testCase.verifyError(@() fetch(testCase,"GDPC1",mock,true), ...
                "macro:v2:validateVintagePanel:InvalidRealtimeInterval");
        end

        function apiAndHttpErrorsDoNotExposeCredentials(testCase)
            secret = "secret-never-persist-7f36";
            setenv("FRED_API_KEY",secret);
            apiMock = MockAlfredHttpClient({struct( ...
                "error_code",429,"error_message","Too many requests")});
            apiError = captureError(@() fetch(testCase,"FEDFUNDS", ...
                apiMock,true));
            testCase.verifyEqual(string(apiError.identifier), ...
                "macro:v2:fetchAlfredSeries:ApiError");
            testCase.verifyFalse(contains(string(apiError.message),secret));

            httpMock = MockAlfredHttpClient({}, ...
                "transport failure containing "+secret);
            httpError = captureError(@() fetch(testCase,"FEDFUNDS", ...
                httpMock,true));
            testCase.verifyEqual(string(httpError.identifier), ...
                "macro:v2:fetchAlfredSeries:HttpError");
            testCase.verifyFalse(contains(string(httpError.message),secret));
        end

        function hostileHttpFailureIsFullyRedactedEverywhere(testCase)
            secret = "hostile-regression-secret-b813";
            setenv("FRED_API_KEY",secret);
            hostileText = "HTTP 400 URL=https://example.invalid/path?" + ...
                "api_key="+secret+"&series_id=GDPC1 api_key:"+secret;
            httpMock = MockAlfredHttpClient({},hostileText);

            consoleText = evalc( ...
                'surfaced = captureError(@() fetch(testCase,"GDPC1",httpMock,true));');
            reportText = string(getReport(surfaced,"extended", ...
                "hyperlinks","off"));
            allSurfacedText = string(consoleText)+" "+ ...
                string(surfaced.message)+" "+reportText;

            testCase.verifyEqual(string(surfaced.identifier), ...
                "macro:v2:fetchAlfredSeries:HttpError");
            testCase.verifyFalse(contains(allSurfacedText,secret));
            testCase.verifyFalse(contains(lower(allSurfacedText),"api_key"));
            testCase.verifyEmpty(dir(fullfile( ...
                testCase.Cfg.VintageDataDir,"*.csv")));
            testCase.verifyEmpty(dir(fullfile( ...
                testCase.Cfg.VintageDataDir,"*.metadata.json")));
        end

        function unsafeCredentialBearingEndpointIsRejectedWithoutLeak(testCase)
            secret = "endpoint-secret-7c19";
            setenv("FRED_API_KEY",secret);
            unsafeCfg = testCase.Cfg;
            unsafeCfg.AlfredEndpoint = ...
                "https://example.invalid/path?api_key="+secret;
            mock = MockAlfredHttpClient({});
            consoleText = evalc( ...
                ['surfaced = captureError(@() macro.v2.fetchAlfredSeries(' ...
                 'unsafeCfg,"GDPC1",RealtimeStart=datetime(2020,1,1),' ...
                 'RealtimeEnd=datetime(2020,12,31),Refresh=true,' ...
                 'HttpClient=@mock.request));']);
            allSurfacedText = string(consoleText)+" "+ ...
                string(surfaced.message)+" "+string(getReport( ...
                surfaced,"extended","hyperlinks","off"));
            testCase.verifyEqual(string(surfaced.identifier), ...
                "macro:v2:fetchAlfredSeries:UnsafeEndpoint");
            testCase.verifyFalse(contains(allSurfacedText,secret));
            testCase.verifyFalse(contains(lower(allSurfacedText),"api_key="));
            testCase.verifyEqual(mock.CallCount,0);
        end

        function cacheHitAvoidsNetworkAndRefreshReplacesCache(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            initial = validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","1.0");
            firstMock = MockAlfredHttpClient({validResponse(1,0,100,initial)});
            first = fetch(testCase,"CPIAUCSL",firstMock,true);

            failingMock = MockAlfredHttpClient({},"must not be called");
            cached = fetch(testCase,"CPIAUCSL",failingMock,false);
            testCase.verifyEqual(cached.Source,"cache");
            testCase.verifyEqual(failingMock.CallCount,0);
            testCase.verifyEqual(cached.Panel,first.Panel);
            testCase.verifyEqual(string(cached.Metadata.checksumSHA256), ...
                string(first.Metadata.checksumSHA256));

            replacement = validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","2.0");
            secondMock = MockAlfredHttpClient({ ...
                validResponse(1,0,100,replacement)});
            refreshed = fetch(testCase,"CPIAUCSL",secondMock,true);
            testCase.verifyEqual(refreshed.Panel.Value,2);
            testCase.verifyNotEqual(string(refreshed.Metadata.checksumSHA256), ...
                string(first.Metadata.checksumSHA256));
        end

        function checksumIsSemanticAndDeterministic(testCase)
            panel = samplePanel;
            checksum = macro.v2.vintagePanelChecksum(panel);
            testCase.verifyEqual(strlength(checksum),64);
            testCase.verifyEqual( ...
                macro.v2.vintagePanelChecksum(flipud(panel)),checksum);
            changed = panel;
            changed.Value(1) = changed.Value(1) + 0.01;
            testCase.verifyNotEqual( ...
                macro.v2.vintagePanelChecksum(changed),checksum);
        end

        function credentialNeverAppearsInCacheMetadataOrConsole(testCase)
            secret = "unique-api-secret-9812";
            setenv("FRED_API_KEY",secret);
            observation = validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","1.0");
            mock = MockAlfredHttpClient({validResponse(1,0,100,observation)});
            consoleText = evalc( ...
                'retrieval = fetch(testCase,"UNRATE",mock,true);');

            persisted = string(fileread(retrieval.DataPath)) + ...
                string(fileread(retrieval.MetadataPath));
            testCase.verifyFalse(contains(string(consoleText),secret));
            testCase.verifyFalse(contains(persisted,secret));
            testCase.verifyFalse(contains( ...
                string(jsonencode(retrieval.Metadata)),secret));
            testCase.verifyFalse(contains(lower(persisted),"api_key"));
            testCase.verifyFalse(contains(lower(string( ...
                jsonencode(retrieval.Metadata))),"api_key"));
        end

        function allFourSupportedSeriesCanBeRetrieved(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            responses = cell(1,4);
            for index = 1:4
                observation = validObservation("2020-01-01", ...
                    "2020-04-29","9999-12-31",string(index));
                responses{index} = validResponse(1,0,100,observation);
            end
            mock = MockAlfredHttpClient(responses);
            retrievals = macro.v2.fetchCurrentAlfredSeries(testCase.Cfg, ...
                RealtimeStart=datetime(2020,1,1), ...
                RealtimeEnd=datetime(2020,12,31),Refresh=true, ...
                HttpClient=@mock.request);

            expected = ["GDPC1","CPIAUCSL","UNRATE","FEDFUNDS"];
            actual = strings(1,4);
            for index = 1:4
                actual(index) = string(retrievals{index}.Metadata.seriesID);
            end
            testCase.verifyEqual(actual,expected);
            testCase.verifyEqual(mock.CallCount,4);
        end

        function malformedPaginationAndCacheTamperingAreDetected(testCase)
            setenv("FRED_API_KEY","offline-test-key");
            observation = validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","1.0");
            emptyObservations = struct("date",{},"realtime_start",{}, ...
                "realtime_end",{},"value",{});
            malformed = validResponse(2,0,100,emptyObservations);
            mock = MockAlfredHttpClient({malformed});
            testCase.verifyError(@() fetch(testCase,"GDPC1",mock,true), ...
                "macro:v2:fetchAlfredSeries:MalformedResponse");

            goodMock = MockAlfredHttpClient({ ...
                validResponse(1,0,100,observation)});
            retrieval = fetch(testCase,"GDPC1",goodMock,true);
            panel = readtable(retrieval.DataPath,TextType="string");
            panel.Value(1) = 99;
            writetable(panel,retrieval.DataPath);
            testCase.verifyError(@() fetch(testCase,"GDPC1",goodMock,false), ...
                "macro:v2:fetchAlfredSeries:ChecksumMismatch");
        end

        function invalidRequestedWindowAndNonnumericValueAreRejected(testCase)
            mock = MockAlfredHttpClient({});
            testCase.verifyError(@() macro.v2.fetchAlfredSeries( ...
                testCase.Cfg,"GDPC1",RealtimeStart=datetime(2021,1,1), ...
                RealtimeEnd=datetime(2020,1,1),Refresh=false, ...
                HttpClient=@mock.request), ...
                "macro:v2:fetchAlfredSeries:InvalidRealtimeWindow");

            setenv("FRED_API_KEY","offline-test-key");
            observation = validObservation("2020-01-01","2020-04-29", ...
                "9999-12-31","not-a-number");
            malformedMock = MockAlfredHttpClient({ ...
                validResponse(1,0,100,observation)});
            testCase.verifyError(@() fetch(testCase,"GDPC1", ...
                malformedMock,true), ...
                "macro:v2:fetchAlfredSeries:MalformedObservation");
        end
    end

    methods (Access=private)
        function retrieval = fetch(testCase,seriesID,mock,refresh)
            retrieval = macro.v2.fetchAlfredSeries(testCase.Cfg,seriesID, ...
                RealtimeStart=datetime(2020,1,1), ...
                RealtimeEnd=datetime(2020,12,31),Refresh=refresh, ...
                HttpClient=@mock.request);
        end
    end
end

function response = validResponse(count,offset,limit,observations)
response = struct("count",count,"offset",offset,"limit",limit, ...
    "observations",observations);
end

function observation = validObservation(dateValue,realtimeStart, ...
        realtimeEnd,value)
observation = struct("date",char(dateValue), ...
    "realtime_start",char(realtimeStart), ...
    "realtime_end",char(realtimeEnd),"value",char(value));
end

function panel = samplePanel
panel = table( ...
    ["GDPC1";"GDPC1"], ...
    [datetime(2019,10,1);datetime(2020,1,1)], ...
    [datetime(2020,1,30);datetime(2020,4,29)], ...
    [datetime(9999,12,31);datetime(9999,12,31)], ...
    [2.1;-5.0], ...
    'VariableNames',{'SeriesID','ObservationDate','RealtimeStart', ...
    'RealtimeEnd','Value'});
end

function errorValue = captureError(functionHandle)
try
    functionHandle();
    error("tests:v2:ExpectedErrorMissing","Expected an error.");
catch errorValue
end
end

function result = canonical(pathValue)
result = string(java.io.File(char(pathValue)).getCanonicalPath());
end
