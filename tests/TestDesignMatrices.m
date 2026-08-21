classdef TestDesignMatrices < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
    end

    methods (TestClassSetup)
        function locateProject(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(testFile)));
        end
    end

    methods (Test)
        function alignsEveryPhase6Lag(testCase)
            data = syntheticQuarterlyData(10);

            for lag = 0:4
                design = macro.buildCommonLagDesign(data,lag);
                responseRows = ((1+lag):height(data))';
                predictorRows = (1:(height(data)-lag))';

                expectedX = [ ...
                    ones(numel(responseRows),1), ...
                    data.Inflation(predictorRows), ...
                    data.Unemployment(predictorRows), ...
                    data.InterestRate(predictorRows)];

                testCase.verifyEqual(design.X,expectedX);
                testCase.verifyEqual(design.Y,data.GDPGrowth(responseRows));
                testCase.verifyEqual(design.Dates, ...
                    data.observation_date(responseRows));
                testCase.verifyEqual(design.ResponseRows,responseRows);
                testCase.verifyEqual(design.PredictorSourceRows(:,2:end), ...
                    repmat(predictorRows,1,3));
                testCase.verifyTrue(all(isnan( ...
                    design.PredictorSourceRows(:,1))));
            end
        end

        function preservesPhase6VaryingSamples(testCase)
            data = syntheticQuarterlyData(10);
            observedSizes = zeros(1,5);
            firstResponseRows = zeros(1,5);

            for lag = 0:4
                design = macro.buildCommonLagDesign(data,lag);
                observedSizes(lag+1) = numel(design.Y);
                firstResponseRows(lag+1) = design.ResponseRows(1);
            end

            testCase.verifyEqual(observedSizes,10:-1:6);
            testCase.verifyEqual(firstResponseRows,1:5);
        end

        function returnsPhase6OrderingAndDimensions(testCase)
            design = macro.buildCommonLagDesign(syntheticQuarterlyData(10),2);

            testCase.verifySize(design.X,[8 4]);
            testCase.verifySize(design.PredictorSourceRows,[8 4]);
            testCase.verifyEqual(design.VariableNames, ...
                ["Intercept","Inflation","Unemployment","InterestRate"]);
            testCase.verifyEqual(design.Lag,2);
        end

        function buildsExactPhase7Design(testCase)
            data = syntheticQuarterlyData(10);
            design = macro.buildDynamicDesign(data);
            responseRows = (5:10)';
            lagRows = responseRows - (0:4);

            expectedX = [ ...
                ones(6,1), ...
                data.GDPGrowth(responseRows-1), ...
                data.Inflation(lagRows), ...
                data.Unemployment(lagRows), ...
                data.InterestRate(lagRows)];
            expectedNames = [ ...
                "Intercept","GDPGrowth_L1", ...
                "Inflation_0","Inflation_L1","Inflation_L2", ...
                "Inflation_L3","Inflation_L4", ...
                "Unemployment_0","Unemployment_L1","Unemployment_L2", ...
                "Unemployment_L3","Unemployment_L4", ...
                "InterestRate_0","InterestRate_L1","InterestRate_L2", ...
                "InterestRate_L3","InterestRate_L4"];

            testCase.verifyEqual(design.X,expectedX);
            testCase.verifyEqual(design.Y,data.GDPGrowth(responseRows));
            testCase.verifyEqual(design.Dates, ...
                data.observation_date(responseRows));
            testCase.verifyEqual(design.VariableNames,expectedNames);
            testCase.verifyEqual(design.ResponseRows,responseRows);
            testCase.verifyEqual(design.PredictorSourceRows, ...
                [NaN(6,1),responseRows-1,lagRows,lagRows,lagRows]);
            testCase.verifySize(design.X,[6 17]);
        end

        function buildsExactForecastDesign(testCase)
            data = syntheticQuarterlyData(10);
            design = macro.buildForecastDesign(data);
            responseRows = (5:10)';
            lagRows = responseRows - (1:4);

            expectedX = [ ...
                ones(6,1), ...
                data.GDPGrowth(responseRows-1), ...
                data.Inflation(lagRows), ...
                data.Unemployment(lagRows), ...
                data.InterestRate(lagRows)];
            expectedNames = [ ...
                "Intercept","GDPGrowth_L1", ...
                "Inflation_L1","Inflation_L2","Inflation_L3","Inflation_L4", ...
                "Unemployment_L1","Unemployment_L2", ...
                "Unemployment_L3","Unemployment_L4", ...
                "InterestRate_L1","InterestRate_L2", ...
                "InterestRate_L3","InterestRate_L4"];

            testCase.verifyEqual(design.X,expectedX);
            testCase.verifyEqual(design.Y,data.GDPGrowth(responseRows));
            testCase.verifyEqual(design.Dates, ...
                data.observation_date(responseRows));
            testCase.verifyEqual(design.VariableNames,expectedNames);
            testCase.verifyEqual(design.ResponseRows,responseRows);
            testCase.verifyEqual(design.PredictorSourceRows, ...
                [NaN(6,1),responseRows-1,lagRows,lagRows,lagRows]);
            testCase.verifySize(design.X,[6 14]);
        end

        function forecastDesignHasNoContemporaneousLeakage(testCase)
            design = macro.buildForecastDesign(syntheticQuarterlyData(12));
            sourceRows = design.PredictorSourceRows(:,2:end);
            latestPermittedRows = repmat(design.ResponseRows-1,1,size(sourceRows,2));

            testCase.verifyLessThanOrEqual(sourceRows,latestPermittedRows);
            testCase.verifyFalse(any(contains( ...
                design.VariableNames(2:end),"_0")));
        end

        function dynamicDesignIncludesOnlySpecifiedContemporaneousColumns(testCase)
            design = macro.buildDynamicDesign(syntheticQuarterlyData(10));
            contemporaneousColumns = find(endsWith(design.VariableNames,"_0"));

            testCase.verifyEqual(contemporaneousColumns,[3 8 13]);
            testCase.verifyEqual( ...
                design.PredictorSourceRows(:,contemporaneousColumns), ...
                repmat(design.ResponseRows,1,3));
            testCase.verifyEqual(design.PredictorSourceRows(:,2), ...
                design.ResponseRows-1);
        end

        function phase6DesignMatchesCommittedBestLagOutput(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            design = macro.buildCommonLagDesign(data,1);
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Best_Lag_Model_Output.csv"));
            fitted = design.X * (design.X \ design.Y);

            testCase.verifyEqual(design.Dates,toDatetime(committed.Date));
            testCase.verifyEqual(design.Y,committed.ActualGDPGrowth, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(fitted,committed.PredictedGDPGrowth, ...
                'AbsTol',1e-10);
            testCase.verifyEqual(design.Y-fitted,committed.Residual, ...
                'AbsTol',1e-10);
        end

        function phase7DesignMatchesCommittedDynamicOutput(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            design = macro.buildDynamicDesign(data);
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Dynamic_Model_Predictions.csv"));
            fitted = design.X * (design.X \ design.Y);

            testCase.verifyEqual(design.Dates,toDatetime(committed.Date));
            testCase.verifyEqual(design.Y,committed.ActualGDPGrowth, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(fitted,committed.PredictedGDPGrowth, ...
                'AbsTol',1e-9);
            testCase.verifyEqual(design.Y-fitted,committed.Residual, ...
                'AbsTol',1e-9);
        end

        function forecastDesignMatchesCommittedOutOfSampleOutput(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            design = macro.buildForecastDesign(data);
            splitDate = datetime(2016,1,1);
            trainRows = design.Dates < splitDate;
            testRows = design.Dates >= splitDate;
            beta = design.X(trainRows,:) \ design.Y(trainRows);
            forecast = design.X(testRows,:) * beta;
            naiveForecast = design.X(testRows,2);
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Out_of_Sample_Forecasts.csv"));

            testCase.verifyEqual(design.Dates(testRows), ...
                toDatetime(committed.Date));
            testCase.verifyEqual(design.Y(testRows), ...
                committed.ActualGDPGrowth,'AbsTol',1e-12);
            testCase.verifyEqual(forecast,committed.EconometricForecast, ...
                'AbsTol',1e-9);
            testCase.verifyEqual(naiveForecast,committed.NaiveForecast, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(design.Y(testRows)-forecast, ...
                committed.ForecastError,'AbsTol',1e-9);
        end
    end
end

function data = syntheticQuarterlyData(numRows)
observation_date = datetime(2000,1,1) + calmonths(3*(0:numRows-1)');
row = (1:numRows)';
RealGDP = 10000 + row;
Unemployment = 2000 + row;
CPI = 30000 + row;
InterestRate = 3000 + row;
GDPGrowth = 100 + row;
Inflation = 1000 + row;
data = table(observation_date,RealGDP,Unemployment,CPI, ...
    InterestRate,GDPGrowth,Inflation);
end

function data = committedQuarterlyData(projectRoot)
data = readtimetable(fullfile(projectRoot,"data", ...
    "Macroeconomic_Data_Quarterly.csv"));
end

function dates = toDatetime(values)
if isdatetime(values)
    dates = values;
else
    dates = datetime(values);
end
dates = dates(:);
end
