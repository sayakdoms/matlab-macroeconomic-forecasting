function result = dieboldMarianoTest(modelForecasts,benchmarkForecasts,options)
%DIEBOLDMARIANOTEST DM test with Harvey-Leybourne-Newbold correction.
%   Positive loss differentials mean the named model has lower loss.

arguments
    modelForecasts table
    benchmarkForecasts table
    options.Loss (1,1) string {mustBeMember(options.Loss, ...
        ["squared","absolute"])} = "squared"
    options.Horizon (1,1) double {mustBeInteger,mustBePositive} = 1
    options.Bandwidth (1,1) double {mustBeInteger} = -1
    options.SmallSampleThreshold (1,1) double ...
        {mustBeInteger,mustBePositive} = 30
end

pair = macro.v2.validateForecastPair(modelForecasts,benchmarkForecasts);
n = pair.Observations;
if options.Horizon > n
    error("macro:v2:dieboldMarianoTest:InvalidHorizon", ...
        "Forecast horizon must not exceed the comparison sample size.");
end
modelErrors = pair.Actual-pair.ModelForecast;
benchmarkErrors = pair.Actual-pair.BenchmarkForecast;
if options.Loss == "squared"
    modelLoss = modelErrors.^2;
    benchmarkLoss = benchmarkErrors.^2;
else
    modelLoss = abs(modelErrors);
    benchmarkLoss = abs(benchmarkErrors);
end
differential = benchmarkLoss-modelLoss;
raw = macro.v2.lossDifferentialInference(differential, ...
    Bandwidth=options.Bandwidth,Alternative="two-sided");
correctionTerm = (n+1-2*options.Horizon+ ...
    options.Horizon*(options.Horizon-1)/n)/n;
if correctionTerm <= 0
    error("macro:v2:dieboldMarianoTest:InvalidHLNCorrection", ...
        "The HLN correction is undefined for this sample and horizon.");
end
hlnFactor = sqrt(correctionTerm);
hlnStatistic = raw.Statistic*hlnFactor;
if raw.Status == "identical-loss"
    hlnPValue = 1;
else
    correctedDifferential = differential*hlnFactor;
    corrected = macro.v2.lossDifferentialInference( ...
        correctedDifferential,Bandwidth=raw.Bandwidth, ...
        Alternative="two-sided");
    % Scaling the differential leaves the raw t statistic unchanged, so
    % compute the HLN t tail directly using an equivalent one-point call.
    hlnPValue = studentTwoSided(hlnStatistic,n-1);
    if corrected.Status == "identical-loss"
        hlnPValue = 1;
    end
end
smallSample = n < options.SmallSampleThreshold;
if smallSample
    warning("macro:v2:dieboldMarianoTest:SmallSample", ...
        "DM/HLN inference uses only %d forecasts; interpret non-rejection cautiously.",n);
end

result = struct( ...
    "TestFamily","DM-HLN", ...
    "Loss",options.Loss, ...
    "Observations",n, ...
    "ForecastStart",pair.Dates(1), ...
    "ForecastEnd",pair.Dates(end), ...
    "Horizon",options.Horizon, ...
    "HACBandwidth",raw.Bandwidth, ...
    "MeanLossDifferential",raw.MeanDifferential, ...
    "DMStatistic",raw.Statistic, ...
    "HLNCorrectionFactor",hlnFactor, ...
    "Statistic",hlnStatistic, ...
    "PValue",hlnPValue, ...
    "Status",raw.Status, ...
    "SmallSampleWarning",smallSample);
end

function pValue = studentTwoSided(statistic,degreesFreedom)
if isinf(statistic)
    pValue = 0;
else
    pValue = betainc(degreesFreedom/(degreesFreedom+statistic^2), ...
        degreesFreedom/2,0.5);
end
end
