classdef TestNumericalHelpers < matlab.unittest.TestCase
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
        function coefficientsEqualDirectLeftDivision(testCase)
            [X,Y] = handExample();
            model = macro.estimateOLS(X,Y);
            testCase.verifyEqual(model.Coefficients,X\Y,'AbsTol',1e-14);
        end

        function fittedValuesAndResidualsAreCorrect(testCase)
            [X,Y] = handExample();
            model = macro.estimateOLS(X,Y);

            expectedFitted = [2.8;3.4;4.0;4.6;5.2];
            expectedResiduals = [-0.8;0.6;1.0;-0.6;-0.2];
            testCase.verifyEqual(model.Fitted,expectedFitted,'AbsTol',1e-14);
            testCase.verifyEqual(model.Residuals,expectedResiduals, ...
                'AbsTol',1e-14);
        end

        function summaryStatisticsMatchHandCalculations(testCase)
            [X,Y] = handExample();
            model = macro.estimateOLS(X,Y);

            expectedLogLikelihood = -5/2*(log(2*pi)+1+log(2.4/5));
            expectedAIC = 2*2-2*expectedLogLikelihood;
            expectedBIC = log(5)*2-2*expectedLogLikelihood;

            testCase.verifyEqual(model.SSE,2.4,'AbsTol',1e-14);
            testCase.verifyEqual(model.SST,6,'AbsTol',1e-14);
            testCase.verifyEqual(model.RSquared,0.6,'AbsTol',1e-14);
            testCase.verifyEqual(model.AdjustedRSquared,7/15, ...
                'AbsTol',1e-14);
            testCase.verifyEqual(model.RMSE,sqrt(2.4/5),'AbsTol',1e-14);
            testCase.verifyEqual(model.ResidualStandardError,sqrt(2.4/3), ...
                'AbsTol',1e-14);
            testCase.verifyEqual(model.FStatistic,4.5,'AbsTol',1e-13);
            testCase.verifyEqual(model.AIC,expectedAIC,'AbsTol',1e-13);
            testCase.verifyEqual(model.BIC,expectedBIC,'AbsTol',1e-13);
        end

        function classicalCovarianceMatchesHandCalculation(testCase)
            [X,Y] = handExample();
            model = macro.estimateOLS(X,Y,CovarianceSolver="inverse");
            expectedCovariance = [0.88 -0.24;-0.24 0.08];

            testCase.verifyEqual(model.Covariance,expectedCovariance, ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.StandardErrors, ...
                sqrt(diag(expectedCovariance)),'AbsTol',1e-13);
            testCase.verifyEqual(model.TStatistics, ...
                model.Coefficients./model.StandardErrors,'AbsTol',1e-14);
            testCase.verifyEqual(model.ApproxPValues, ...
                erfc(abs(model.TStatistics)/sqrt(2)),'AbsTol',1e-14);
        end

        function inverseAndPseudoinverseConventionsAgreeAtFullRank(testCase)
            [X,Y] = handExample();
            inverseModel = macro.estimateOLS(X,Y,CovarianceSolver="inverse");
            pseudoModel = macro.estimateOLS( ...
                X,Y,CovarianceSolver="pseudoinverse");

            testCase.verifyEqual(pseudoModel.Coefficients, ...
                inverseModel.Coefficients,'AbsTol',1e-14);
            testCase.verifyEqual(pseudoModel.Covariance, ...
                inverseModel.Covariance,'AbsTol',1e-13);
        end

        function rejectsRankDeficientDesign(testCase)
            X = [ones(5,1),ones(5,1)];
            Y = (1:5)';
            testCase.verifyError(@() macro.estimateOLS(X,Y), ...
                "macro:estimateOLS:RankDeficientDesign");
        end

        function forecastMetricsMatchKnownExample(testCase)
            actual = [1;-2;3;-4];
            forecast = [2;-1;2;-5];
            persistence = zeros(4,1);
            metrics = macro.forecastMetrics(actual,forecast,persistence);
            expectedCorrelation = corr(actual,forecast);

            testCase.verifyEqual(metrics.Errors,[-1;-1;1;1]);
            testCase.verifyEqual(metrics.RMSE,1,'AbsTol',1e-14);
            testCase.verifyEqual(metrics.MAE,1,'AbsTol',1e-14);
            testCase.verifyEqual(metrics.Correlation,expectedCorrelation, ...
                'AbsTol',1e-14);
            testCase.verifyEqual(metrics.DirectionalAccuracy,100);
            testCase.verifyEqual(metrics.PersistenceRMSE,sqrt(7.5), ...
                'AbsTol',1e-14);
            testCase.verifyEqual(metrics.PersistenceMAE,2.5,'AbsTol',1e-14);
            testCase.verifyEqual(metrics.RMSEImprovementPercent, ...
                ((sqrt(7.5)-1)/sqrt(7.5))*100,'AbsTol',1e-13);
            testCase.verifyEqual(metrics.MAEImprovementPercent,60, ...
                'AbsTol',1e-14);
        end

        function directionalAccuracyPreservesSignDefinition(testCase)
            actual = [1;0;-1];
            forecast = [2;0;3];
            persistence = [-1;1;-1];
            metrics = macro.forecastMetrics(actual,forecast,persistence);
            testCase.verifyEqual(metrics.DirectionalAccuracy,200/3, ...
                'AbsTol',1e-13);
        end

        function phase4ResultsMatchCommittedOutputs(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            X = [ones(height(data),1),data.Inflation, ...
                data.Unemployment,data.InterestRate];
            model = macro.estimateOLS(X,data.GDPGrowth, ...
                CovarianceSolver="inverse");
            summary = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Model_Summary.csv"));
            coefficients = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Regression_Results.csv"));
            predictions = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "OLS_Predictions_Residuals.csv"));

            testCase.verifyEqual(model.Observations,summary.Observations(1));
            testCase.verifyEqual(model.RSquared,summary.RSquared(1), ...
                'AbsTol',1e-14);
            testCase.verifyEqual(model.AdjustedRSquared, ...
                summary.AdjustedRSquared(1),'AbsTol',1e-14);
            testCase.verifyEqual(model.ResidualStandardError, ...
                summary.ResidualStdError(1),'AbsTol',1e-13);
            testCase.verifyEqual(model.FStatistic,summary.FStatistic(1), ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.Coefficients,coefficients.Coefficient, ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.StandardErrors,coefficients.StandardError, ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.TStatistics,coefficients.TStatistic, ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.ApproxPValues,coefficients.ApproxPValue, ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.Fitted,predictions.PredictedGDPGrowth, ...
                'AbsTol',1e-11);
            testCase.verifyEqual(model.Residuals,predictions.Residual, ...
                'AbsTol',1e-11);
        end

        function phase7ResultsMatchCommittedOutputs(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            design = macro.buildDynamicDesign(data);
            model = macro.estimateOLS(design.X,design.Y, ...
                CovarianceSolver="pseudoinverse");
            summary = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Dynamic_Model_Summary.csv"));
            coefficients = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Dynamic_Distributed_Lag_Results.csv"));

            testCase.verifyEqual(model.RSquared,summary.RSquared(1), ...
                'AbsTol',1e-13);
            testCase.verifyEqual(model.AdjustedRSquared, ...
                summary.AdjustedRSquared(1),'AbsTol',1e-13);
            testCase.verifyEqual(model.RMSE,summary.RMSE(1),'AbsTol',1e-12);
            testCase.verifyEqual(model.FStatistic,summary.FStatistic(1), ...
                'AbsTol',1e-11);
            testCase.verifyEqual(model.AIC,summary.AIC(1),'AbsTol',1e-10);
            testCase.verifyEqual(model.BIC,summary.BIC(1),'AbsTol',1e-10);
            testCase.verifyEqual(model.Coefficients,coefficients.Coefficient, ...
                'AbsTol',1e-11);
            testCase.verifyEqual(model.StandardErrors,coefficients.StandardError, ...
                'AbsTol',1e-11);
            testCase.verifyEqual(model.ApproxPValues,coefficients.ApproxPValue, ...
                'AbsTol',1e-11);
        end

        function phase8MetricsMatchCommittedOutput(testCase)
            data = committedQuarterlyData(testCase.ProjectRoot);
            design = macro.buildForecastDesign(data);
            trainRows = design.Dates < datetime(2016,1,1);
            testRows = ~trainRows;
            model = macro.estimateOLS( ...
                design.X(trainRows,:),design.Y(trainRows));
            forecast = design.X(testRows,:) * model.Coefficients;
            persistence = design.X(testRows,2);
            metrics = macro.forecastMetrics( ...
                design.Y(testRows),forecast,persistence);
            committed = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Out_of_Sample_Forecast_Summary.csv"));

            testCase.verifyEqual(metrics.RMSE,committed.ModelRMSE(1), ...
                'AbsTol',1e-11);
            testCase.verifyEqual(metrics.MAE,committed.ModelMAE(1), ...
                'AbsTol',1e-11);
            testCase.verifyEqual(metrics.Correlation, ...
                committed.ForecastCorrelation(1),'AbsTol',1e-12);
            testCase.verifyEqual(metrics.DirectionalAccuracy, ...
                committed.DirectionalAccuracyPercent(1),'AbsTol',1e-12);
            testCase.verifyEqual(metrics.PersistenceRMSE, ...
                committed.NaiveRMSE(1),'AbsTol',1e-11);
            testCase.verifyEqual(metrics.PersistenceMAE, ...
                committed.NaiveMAE(1),'AbsTol',1e-11);
            testCase.verifyEqual(metrics.RMSEImprovementPercent, ...
                committed.RMSEImprovementPercent(1),'AbsTol',1e-11);
            testCase.verifyEqual(metrics.MAEImprovementPercent, ...
                committed.MAEImprovementPercent(1),'AbsTol',1e-11);
        end

        function phase11MetricsMatchCommittedLeaderboard(testCase)
            forecasts = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Expanding_Window_Forecasts.csv"));
            leaderboard = readtable(fullfile(testCase.ProjectRoot,"results", ...
                "Expanding_Window_Model_Leaderboard.csv"));
            forecastColumns = ["FixedForecast","ExpandingForecast","NaiveForecast"];
            modelNames = ["Fixed Historical Model", ...
                "Expanding Window Model","Naive Persistence"];

            for index = 1:numel(forecastColumns)
                metrics = macro.forecastMetrics( ...
                    forecasts.ActualGDPGrowth, ...
                    forecasts.(forecastColumns(index)), ...
                    forecasts.NaiveForecast);
                row = string(leaderboard.Model) == modelNames(index);
                testCase.verifyEqual(metrics.RMSE,leaderboard.RMSE(row), ...
                    'AbsTol',1e-11);
                testCase.verifyEqual(metrics.MAE,leaderboard.MAE(row), ...
                    'AbsTol',1e-11);
                testCase.verifyEqual(metrics.Correlation, ...
                    leaderboard.Correlation(row),'AbsTol',1e-12);
                testCase.verifyEqual(metrics.DirectionalAccuracy, ...
                    leaderboard.DirectionalAccuracy(row),'AbsTol',1e-12);
            end
        end
    end
end

function [X,Y] = handExample()
X = [ones(5,1),(1:5)'];
Y = [2;4;5;4;5];
end

function data = committedQuarterlyData(projectRoot)
data = readtimetable(fullfile(projectRoot,"data", ...
    "Macroeconomic_Data_Quarterly.csv"));
end
