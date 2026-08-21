classdef TestDataValidation < matlab.unittest.TestCase
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
        function requiresExistingVariables(testCase)
            data = table((1:3)',(4:6)', ...
                'VariableNames',{'First','Second'});
            testCase.verifyWarningFree( ...
                @() macro.requireTableVariables(data,["First","Second"]));
        end

        function rejectsMissingVariables(testCase)
            data = table((1:3)','VariableNames',{'Present'});
            testCase.verifyError( ...
                @() macro.requireTableVariables(data,["Present","Missing"]), ...
                "macro:requireTableVariables:MissingVariables");
        end

        function validatesCommittedFiniteRawFredData(testCase)
            files = ["GDP_raw.csv","InterestRate_raw.csv"];
            valueVariables = ["GDPC1","FEDFUNDS"];

            for index = 1:numel(files)
                raw = readtable(fullfile(testCase.ProjectRoot,"data",files(index)));
                validated = macro.validateRawFredTable(raw,valueVariables(index));
                testCase.verifyEqual(height(validated),height(raw));
                testCase.verifyTrue(isdatetime(validated.observation_date));
            end
        end

        function detectsMissingValuesInCommittedRawFredData(testCase)
            files = ["CPI_raw.csv","Unemployment_raw.csv"];
            valueVariables = ["CPIAUCSL","UNRATE"];

            for index = 1:numel(files)
                raw = readtable(fullfile(testCase.ProjectRoot,"data",files(index)));
                testCase.verifyError( ...
                    @() macro.validateRawFredTable(raw,valueVariables(index)), ...
                    "macro:validateRawFredTable:NonfiniteObservations");
            end
        end

        function optionallyAllowsMissingRawObservations(testCase)
            raw = validRawTable();
            raw.VALUE(2) = NaN;
            validated = macro.validateRawFredTable(raw,"VALUE", ...
                AllowMissingObservations=true);
            testCase.verifyTrue(isnan(validated.VALUE(2)));
        end

        function missingObservationOptionStillRejectsInfinity(testCase)
            raw = validRawTable();
            raw.VALUE(2) = Inf;
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE", ...
                    AllowMissingObservations=true), ...
                "macro:validateRawFredTable:NonfiniteObservations");
        end

        function acceptsAndNormalizesTextDates(testCase)
            raw = validRawTable();
            raw.observation_date = string(raw.observation_date,"yyyy-MM-dd");

            validated = macro.validateRawFredTable(raw,"VALUE");

            testCase.verifyTrue(isdatetime(validated.observation_date));
        end

        function rejectsRawMissingValueVariable(testCase)
            raw = validRawTable();
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"MISSING"), ...
                "macro:requireTableVariables:MissingVariables");
        end

        function rejectsDuplicateRawDates(testCase)
            raw = validRawTable();
            raw.observation_date(3) = raw.observation_date(2);
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE"), ...
                "macro:validateRawFredTable:DuplicateDates");
        end

        function rejectsInvalidRawDates(testCase)
            raw = validRawTable();
            raw.observation_date = ["2020-01-01";"not-a-date";"2020-03-01"];
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE"), ...
                "macro:validateRawFredTable:InvalidDates");
        end

        function rejectsUnsortedRawDates(testCase)
            raw = validRawTable();
            raw = raw([1 3 2],:);
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE"), ...
                "macro:validateRawFredTable:UnsortedDates");
        end

        function rejectsNonnumericRawObservations(testCase)
            raw = validRawTable();
            raw.VALUE = ["1";"2";"3"];
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE"), ...
                "macro:validateRawFredTable:NonnumericObservations");
        end

        function rejectsNonfiniteRawObservations(testCase)
            raw = validRawTable();
            raw.VALUE(2) = Inf;
            testCase.verifyError( ...
                @() macro.validateRawFredTable(raw,"VALUE"), ...
                "macro:validateRawFredTable:NonfiniteObservations");
        end

        function validatesCommittedQuarterlyData(testCase)
            data = readtimetable(fullfile(testCase.ProjectRoot,"data", ...
                "Macroeconomic_Data_Quarterly.csv"));
            validated = macro.validateQuarterlyData(data);
            testCase.verifyEqual(height(validated),height(data));
            testCase.verifyTrue(istimetable(validated));
        end

        function validatesQuarterlyTableWithTextDates(testCase)
            data = validQuarterlyTable();
            data.observation_date = string(data.observation_date,"yyyy-MM-dd");
            validated = macro.validateQuarterlyData(data);
            testCase.verifyTrue(isdatetime(validated.observation_date));
        end

        function rejectsQuarterlyMissingVariable(testCase)
            data = removevars(validQuarterlyTable(),"Inflation");
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:requireTableVariables:MissingVariables");
        end

        function rejectsDuplicateQuarterlyDates(testCase)
            data = validQuarterlyTable();
            data.observation_date(3) = data.observation_date(2);
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:DuplicateDates");
        end

        function rejectsInvalidQuarterlyDates(testCase)
            data = validQuarterlyTable();
            data.observation_date = ["2020-01-01";"invalid"; ...
                "2020-07-01";"2020-10-01"];
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:InvalidDates");
        end

        function rejectsUnsortedQuarterlyDates(testCase)
            data = validQuarterlyTable();
            data = data([1 3 2 4],:);
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:UnsortedDates");
        end

        function rejectsNonnumericQuarterlyVariable(testCase)
            data = validQuarterlyTable();
            data.Inflation = string(data.Inflation);
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:NonnumericVariable");
        end

        function rejectsQuarterlyNaN(testCase)
            data = validQuarterlyTable();
            data.GDPGrowth(2) = NaN;
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:NonfiniteValues");
        end

        function rejectsQuarterlyInf(testCase)
            data = validQuarterlyTable();
            data.InterestRate(2) = Inf;
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:NonfiniteValues");
        end

        function rejectsQuarterlyGap(testCase)
            data = validQuarterlyTable();
            data(2,:) = [];
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:QuarterlyGap");
        end

        function rejectsOffCycleQuarterlyDate(testCase)
            data = validQuarterlyTable();
            data.observation_date(1) = datetime(2020,1,15);
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:QuarterlyGap");
        end

        function rejectsNonpositiveGDP(testCase)
            data = validQuarterlyTable();
            data.RealGDP(2) = 0;
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:NonpositiveLevels");
        end

        function rejectsNonpositiveCPI(testCase)
            data = validQuarterlyTable();
            data.CPI(2) = -1;
            testCase.verifyError( ...
                @() macro.validateQuarterlyData(data), ...
                "macro:validateQuarterlyData:NonpositiveLevels");
        end
    end
end

function raw = validRawTable()
observation_date = datetime(2020,1,1) + calmonths((0:2)');
VALUE = [100;101;102];
raw = table(observation_date,VALUE);
end

function data = validQuarterlyTable()
observation_date = datetime(2020,1,1) + calmonths(3*(0:3)');
RealGDP = [100;101;102;103];
Unemployment = [4.0;4.1;4.2;4.0];
CPI = [200;201;202;203];
InterestRate = [1.0;1.1;1.2;1.3];
GDPGrowth = [2.0;2.1;2.2;2.3];
Inflation = [1.0;1.1;1.2;1.3];
data = table(observation_date,RealGDP,Unemployment,CPI, ...
    InterestRate,GDPGrowth,Inflation);
end
