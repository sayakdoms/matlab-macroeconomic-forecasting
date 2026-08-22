function metrics = forecastEvaluationMetrics(actual,forecast,trainingScale,options)
%FORECASTEVALUATIONMETRICS Compute predeclared V2.5 forecast metrics.
%   Errors are actual minus forecast, so positive mean error indicates
%   systematic underprediction. MASE and Huber loss use only supplied
%   training-origin scales; they never estimate scale from test outcomes.

arguments
    actual double
    forecast double
    trainingScale double
    options.HuberDelta (1,1) double {mustBePositive} = 1.345
end

actual = validateVector(actual,"actual");
forecast = validateVector(forecast,"forecast");
trainingScale = validateVector(trainingScale,"training scale");
if numel(actual) ~= numel(forecast) || ...
        ~(isscalar(trainingScale) || numel(trainingScale) == numel(actual))
    error("macro:v2:forecastEvaluationMetrics:DimensionMismatch", ...
        "Actual, forecast, and training scales must have compatible lengths.");
end
if isscalar(trainingScale)
    trainingScale = repmat(trainingScale,numel(actual),1);
end
if any(trainingScale <= 0)
    error("macro:v2:forecastEvaluationMetrics:InvalidScale", ...
        "Every training-only naive scale must be strictly positive.");
end

errors = actual-forecast;
absoluteErrors = abs(errors);
scaledErrors = errors./trainingScale;
absoluteScaledErrors = abs(scaledErrors);
delta = options.HuberDelta;
huber = 0.5*scaledErrors.^2;
large = absoluteScaledErrors > delta;
huber(large) = delta*(absoluteScaledErrors(large)-0.5*delta);

correlation = NaN;
correlationMeaningful = numel(actual) >= 2 && ...
    std(actual) > 0 && std(forecast) > 0;
if correlationMeaningful
    correlation = corr(actual,forecast);
end
signAccuracyMeaningful = numel(unique(sign(actual))) > 1;

metrics = struct( ...
    "Observations",numel(actual), ...
    "Errors",errors, ...
    "MeanError",mean(errors), ...
    "RMSE",sqrt(mean(errors.^2)), ...
    "MAE",mean(absoluteErrors), ...
    "MedianAbsoluteError",median(absoluteErrors), ...
    "MASE",mean(absoluteScaledErrors), ...
    "HuberLoss",mean(huber), ...
    "Correlation",correlation, ...
    "CorrelationMeaningful",correlationMeaningful, ...
    "SignAccuracyPercent",100*mean(sign(forecast) == sign(actual)), ...
    "SignAccuracyMeaningful",signAccuracyMeaningful, ...
    "TrainingScaleMinimum",min(trainingScale), ...
    "TrainingScaleMaximum",max(trainingScale));
end

function value = validateVector(value,name)
if ~isvector(value) || isempty(value) || ~isreal(value) || ...
        any(~isfinite(value))
    error("macro:v2:forecastEvaluationMetrics:InvalidInput", ...
        "%s must be a nonempty finite real numeric vector.",name);
end
value = value(:);
end
