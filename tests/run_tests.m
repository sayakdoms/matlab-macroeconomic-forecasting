function results = run_tests
%RUN_TESTS Run the project infrastructure test suite.

projectRoot = string(fileparts(fileparts(mfilename("fullpath"))));
sourceDir = fullfile(projectRoot,"src");
addpath(sourceDir);
pathCleanup = onCleanup(@() rmpath(sourceDir)); %#ok<NASGU>

suite = testsuite(fullfile(projectRoot,"tests"), ...
    "IncludeSubfolders",true);
results = run(suite);
assertSuccess(results);
end
