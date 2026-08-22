function intervals = blockBootstrapMetricCI(actual,forecast,trainingScale,options)
%BLOCKBOOTSTRAPMETRICCI Fixed-seed circular block-bootstrap metric CIs.

arguments
    actual double
    forecast double
    trainingScale double
    options.Replications (1,1) double {mustBeInteger,mustBePositive} = 2000
    options.BlockLength (1,1) double {mustBeInteger,mustBePositive} = 4
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 2505
    options.ConfidenceLevel (1,1) double {mustBeGreaterThan(options.ConfidenceLevel,0), ...
        mustBeLessThan(options.ConfidenceLevel,1)} = 0.95
    options.HuberDelta (1,1) double {mustBePositive} = 1.345
end

point = macro.v2.forecastEvaluationMetrics(actual,forecast,trainingScale, ...
    HuberDelta=options.HuberDelta);
n = point.Observations;
if options.BlockLength > n
    error("macro:v2:blockBootstrapMetricCI:BlockTooLong", ...
        "BlockLength must not exceed the forecast sample size.");
end
actual = actual(:);
forecast = forecast(:);
trainingScale = trainingScale(:);
if isscalar(trainingScale)
    trainingScale = repmat(trainingScale,n,1);
end

Metric = ["MeanError";"RMSE";"MAE";"MedianAbsoluteError"; ...
    "MASE";"HuberLoss";"Correlation";"SignAccuracyPercent"];
Estimate = [point.MeanError;point.RMSE;point.MAE; ...
    point.MedianAbsoluteError;point.MASE;point.HuberLoss; ...
    point.Correlation;point.SignAccuracyPercent];
draws = NaN(options.Replications,numel(Metric));
previousGenerator = rng;
cleanup = onCleanup(@() rng(previousGenerator));
rng(options.Seed,"twister");
blocksNeeded = ceil(n/options.BlockLength);
for replication = 1:options.Replications
    starts = randi(n,blocksNeeded,1);
    indices = zeros(blocksNeeded*options.BlockLength,1);
    position = 0;
    for block = 1:blocksNeeded
        blockIndices = mod((starts(block)-1)+(0:options.BlockLength-1),n)+1;
        indices(position+(1:options.BlockLength)) = blockIndices;
        position = position+options.BlockLength;
    end
    indices = indices(1:n);
    metric = macro.v2.forecastEvaluationMetrics( ...
        actual(indices),forecast(indices),trainingScale(indices), ...
        HuberDelta=options.HuberDelta);
    draws(replication,:) = [metric.MeanError,metric.RMSE,metric.MAE, ...
        metric.MedianAbsoluteError,metric.MASE,metric.HuberLoss, ...
        metric.Correlation,metric.SignAccuracyPercent];
end

tail = (1-options.ConfidenceLevel)/2;
Lower = NaN(numel(Metric),1);
Upper = NaN(numel(Metric),1);
ValidReplications = zeros(numel(Metric),1);
for metricIndex = 1:numel(Metric)
    values = draws(:,metricIndex);
    values = values(isfinite(values));
    ValidReplications(metricIndex) = numel(values);
    if ~isempty(values)
        Lower(metricIndex) = empiricalQuantile(values,tail);
        Upper(metricIndex) = empiricalQuantile(values,1-tail);
    end
end
ConfidenceLevel = repmat(options.ConfidenceLevel,numel(Metric),1);
Replications = repmat(options.Replications,numel(Metric),1);
BlockLength = repmat(options.BlockLength,numel(Metric),1);
Seed = repmat(options.Seed,numel(Metric),1);
MetricMeaningful = true(numel(Metric),1);
MetricMeaningful(Metric == "Correlation") = point.CorrelationMeaningful;
MetricMeaningful(Metric == "SignAccuracyPercent") = ...
    point.SignAccuracyMeaningful;
intervals = table(Metric,Estimate,Lower,Upper,ConfidenceLevel, ...
    Replications,ValidReplications,BlockLength,Seed,MetricMeaningful);
end

function value = empiricalQuantile(values,probability)
values = sort(values(:));
if isscalar(values)
    value = values;
    return;
end
position = 1+(numel(values)-1)*probability;
lowerIndex = floor(position);
upperIndex = ceil(position);
weight = position-lowerIndex;
value = (1-weight)*values(lowerIndex)+weight*values(upperIndex);
end
