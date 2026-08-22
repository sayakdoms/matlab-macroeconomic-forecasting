classdef TestV1BaselineIntegrity < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        Manifest (1,1) struct
    end

    methods (TestClassSetup)
        function loadManifest(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            testCase.ProjectRoot = string(fileparts(fileparts(fileparts( ...
                testFile))));
            manifestPath = fullfile(testCase.ProjectRoot,"config", ...
                "v1_baseline_manifest.json");
            testCase.Manifest = jsondecode(fileread(manifestPath));
        end
    end

    methods (Test)
        function manifestIdentifiesStableV1(testCase)
            testCase.verifyEqual(string(testCase.Manifest.baselineRelease), ...
                "v1.0.0");
            testCase.verifyEqual(string(testCase.Manifest.baselineCommit), ...
                "4db1a1e215eb5ff444c6ee8a21bcbc930847d8ed");
        end

        function keyFileSchemasAndRowsRemainUnchanged(testCase)
            contracts = testCase.Manifest.files;
            for contractIndex = 1:numel(contracts)
                contract = contracts(contractIndex);
                filePath = fullfile(testCase.ProjectRoot,string(contract.path));
                testCase.verifyTrue(isfile(filePath), ...
                    "Missing V1 baseline file: "+string(contract.path));
                actual = readtable(filePath);
                testCase.verifyEqual(height(actual),double(contract.rows), ...
                    "V1 row count changed: "+string(contract.path));
                testCase.verifyEqual( ...
                    string(actual.Properties.VariableNames), ...
                    string(contract.variables)', ...
                    "V1 schema changed: "+string(contract.path));
            end
        end

        function selectedHeadlineKPIsRemainUnchanged(testCase)
            kpis = testCase.Manifest.kpis;
            for kpiIndex = 1:numel(kpis)
                kpi = kpis(kpiIndex);
                actual = readtable(fullfile( ...
                    testCase.ProjectRoot,string(kpi.path)));
                value = actual.(kpi.variable)(kpi.row);
                if strlength(string(kpi.expectedText)) > 0
                    testCase.verifyEqual(string(value), ...
                        string(kpi.expectedText),string(kpi.name));
                else
                    testCase.verifyEqual(double(value), ...
                        double(kpi.expectedNumber), ...
                        'AbsTol',double(kpi.absoluteTolerance), ...
                        string(kpi.name));
                end
            end
        end
    end
end
