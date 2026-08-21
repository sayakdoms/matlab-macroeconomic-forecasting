classdef TestProjectInfrastructure < matlab.unittest.TestCase
    properties
        ProjectRoot (1,1) string
        TemporaryPaths string = strings(0,1)
    end

    methods (TestClassSetup)
        function locateRealProject(testCase)
            testFile = mfilename("fullpath");
            testCase.ProjectRoot = string(fileparts(fileparts(testFile)));
        end
    end

    methods (TestMethodTeardown)
        function removeTemporaryPaths(testCase)
            for index = numel(testCase.TemporaryPaths):-1:1
                temporaryPath = testCase.TemporaryPaths(index);
                if isfolder(temporaryPath) && isSafeTemporaryPath(temporaryPath)
                    rmdir(temporaryPath,"s");
                end
            end
            testCase.TemporaryPaths = strings(0,1);
        end
    end

    methods (Test)
        function findsRootFromRepositoryRoot(testCase)
            actual = macro.findProjectRoot(testCase.ProjectRoot);
            testCase.verifyEqual(actual,canonicalPath(testCase.ProjectRoot));
        end

        function findsRootFromNestedDirectory(testCase)
            actual = macro.findProjectRoot( ...
                fullfile(testCase.ProjectRoot,"scripts"));
            testCase.verifyEqual(actual,canonicalPath(testCase.ProjectRoot));
        end

        function findsRootFromFilePath(testCase)
            testFile = string(mfilename("fullpath")) + ".m";
            actual = macro.findProjectRoot(testFile);
            testCase.verifyEqual(actual,canonicalPath(testCase.ProjectRoot));
        end

        function findsSyntheticProjectRoot(testCase)
            syntheticRoot = testCase.newTemporaryPath();
            mkdir(fullfile(syntheticRoot,"scripts"));
            mkdir(fullfile(syntheticRoot,"data"));
            writeTextFile(fullfile(syntheticRoot,"README.md"),"test project");
            nestedPath = fullfile(syntheticRoot,"scripts","nested");
            mkdir(nestedPath);

            actual = macro.findProjectRoot(nestedPath);

            testCase.verifyEqual(actual,canonicalPath(syntheticRoot));
        end

        function rejectsMissingStartLocation(testCase)
            missingPath = fullfile(testCase.newTemporaryPath(),"missing");
            testCase.verifyError( ...
                @() macro.findProjectRoot(missingPath), ...
                "macro:findProjectRoot:StartLocationNotFound");
        end

        function rejectsDirectoryWithoutProjectMarkers(testCase)
            emptyPath = testCase.newTemporaryPath();
            testCase.verifyError( ...
                @() macro.findProjectRoot(emptyPath), ...
                "macro:findProjectRoot:ProjectRootNotFound");
        end

        function buildsDefaultConfiguration(testCase)
            cfg = macro.projectConfig(testCase.ProjectRoot);

            testCase.verifyEqual(cfg.ProjectRoot,canonicalPath(testCase.ProjectRoot));
            testCase.verifyEqual(cfg.OutputRoot,cfg.ProjectRoot);
            testCase.verifyEqual(cfg.DataDir,fullfile(cfg.ProjectRoot,"data"));
            testCase.verifyEqual(cfg.ResultsDir,fullfile(cfg.ProjectRoot,"results"));
            testCase.verifyEqual(cfg.FiguresDir,fullfile(cfg.ProjectRoot,"figures"));
            testCase.verifyFalse(cfg.RefreshData);
            testCase.verifyTrue(cfg.GenerateFigures);
            testCase.verifyTrue(cfg.StopOnError);
        end

        function supportsIsolatedOutputRootAndOptions(testCase)
            outputRoot = testCase.newTemporaryPath();
            cfg = macro.projectConfig(testCase.ProjectRoot, ...
                OutputRoot=outputRoot, ...
                RefreshData=true, ...
                GenerateFigures=false, ...
                StopOnError=false);

            testCase.verifyEqual(cfg.OutputRoot,canonicalPath(outputRoot));
            testCase.verifyEqual(cfg.SourceDataDir, ...
                fullfile(canonicalPath(testCase.ProjectRoot),"data"));
            testCase.verifyEqual(cfg.DataDir, ...
                fullfile(canonicalPath(outputRoot),"data"));
            testCase.verifyTrue(cfg.RefreshData);
            testCase.verifyFalse(cfg.GenerateFigures);
            testCase.verifyFalse(cfg.StopOnError);
        end

        function createsOutputDirectoriesIdempotently(testCase)
            outputRoot = testCase.newTemporaryPath();
            cfg = macro.projectConfig(testCase.ProjectRoot,OutputRoot=outputRoot);

            firstStatus = macro.ensureOutputDirectories(cfg);
            secondStatus = macro.ensureOutputDirectories(cfg);

            testCase.verifyTrue(all(firstStatus.Created));
            testCase.verifyFalse(any(secondStatus.Created));
            testCase.verifyTrue(isfolder(cfg.DataDir));
            testCase.verifyTrue(isfolder(cfg.ResultsDir));
            testCase.verifyTrue(isfolder(cfg.FiguresDir));
        end

        function validatesAllPathsBeforeCreatingAnything(testCase)
            outputRoot = testCase.newTemporaryPath();
            outsideRoot = testCase.newTemporaryPath();
            cfg = macro.projectConfig(testCase.ProjectRoot,OutputRoot=outputRoot);
            cfg.ResultsDir = fullfile(outsideRoot,"results");

            testCase.verifyError( ...
                @() macro.ensureOutputDirectories(cfg), ...
                "macro:ensureOutputDirectories:UnsafeOutputPath");
            testCase.verifyFalse(isfolder(cfg.DataDir));
            testCase.verifyFalse(isfolder(cfg.FiguresDir));
            testCase.verifyFalse(isfolder(cfg.ResultsDir));
        end

        function rejectsIncompleteConfiguration(testCase)
            incomplete = struct("OutputRoot",testCase.newTemporaryPath());
            testCase.verifyError( ...
                @() macro.ensureOutputDirectories(incomplete), ...
                "macro:ensureOutputDirectories:InvalidConfiguration");
        end
    end

    methods (Access=private)
        function pathOut = newTemporaryPath(testCase)
            pathOut = string(tempname);
            mkdir(pathOut);
            testCase.TemporaryPaths(end+1,1) = pathOut;
        end
    end
end

function writeTextFile(filePath,textValue)
fileIdentifier = fopen(filePath,"w");
cleanup = onCleanup(@() fclose(fileIdentifier));
fprintf(fileIdentifier,"%s\n",textValue);
end

function tf = isSafeTemporaryPath(pathValue)
temporaryRoot = canonicalPath(string(tempdir));
candidate = canonicalPath(pathValue);
if ispc
    tf = startsWith(lower(candidate),lower(temporaryRoot));
else
    tf = startsWith(candidate,temporaryRoot);
end
end

function pathOut = canonicalPath(pathIn)
pathOut = string(java.io.File(char(pathIn)).getCanonicalPath());
end
