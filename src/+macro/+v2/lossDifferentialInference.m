function inference = lossDifferentialInference(differential,options)
%LOSSDIFFERENTIALINFERENCE Bartlett-HAC inference for a mean differential.

arguments
    differential double
    options.Bandwidth (1,1) double {mustBeInteger} = -1
    options.Alternative (1,1) string {mustBeMember(options.Alternative, ...
        ["two-sided","greater"])} = "two-sided"
end

if ~isvector(differential) || numel(differential) < 3 || ...
        ~isreal(differential) || any(~isfinite(differential))
    error("macro:v2:lossDifferentialInference:InvalidDifferential", ...
        "The loss differential must contain at least three finite values.");
end
differential = differential(:);
n = numel(differential);
if options.Bandwidth == -1
    bandwidth = macro.v2.bandwidthRule(n);
else
    bandwidth = options.Bandwidth;
end
if bandwidth < 0 || bandwidth > n-1
    error("macro:v2:lossDifferentialInference:InvalidBandwidth", ...
        "Bandwidth must be -1 or an integer from zero through n-1.");
end

centered = differential-mean(differential);
longRunVariance = sum(centered.^2)/n;
for lag = 1:bandwidth
    weight = 1-lag/(bandwidth+1);
    autocovariance = centered(lag+1:end)'*centered(1:end-lag)/n;
    longRunVariance = longRunVariance+2*weight*autocovariance;
end
longRunVariance = max(longRunVariance,0);
varianceOfMean = longRunVariance/n;
tolerance = eps(max(1,max(abs(differential))))^2;
if varianceOfMean <= tolerance
    if all(abs(differential) <= sqrt(tolerance))
        statistic = 0;
        pValue = 1;
        status = "identical-loss";
    else
        statistic = sign(mean(differential))*Inf;
        if options.Alternative == "two-sided"
            pValue = 0;
        else
            pValue = double(statistic < 0);
        end
        status = "zero-variance-differential";
    end
else
    statistic = mean(differential)/sqrt(varianceOfMean);
    pValue = studentTPValue(statistic,n-1,options.Alternative);
    status = "valid";
end

inference = struct( ...
    "Differential",differential, ...
    "MeanDifferential",mean(differential), ...
    "LongRunVariance",longRunVariance, ...
    "VarianceOfMean",varianceOfMean, ...
    "StandardError",sqrt(varianceOfMean), ...
    "Statistic",statistic, ...
    "PValue",pValue, ...
    "Bandwidth",bandwidth, ...
    "Kernel","Bartlett", ...
    "Alternative",options.Alternative, ...
    "Status",status);
end

function pValue = studentTPValue(statistic,degreesFreedom,alternative)
if isinf(statistic)
    if alternative == "two-sided"
        pValue = 0;
    else
        pValue = double(statistic < 0);
    end
    return;
end
tail = 0.5*betainc(degreesFreedom/(degreesFreedom+statistic^2), ...
    degreesFreedom/2,0.5);
if alternative == "two-sided"
    pValue = min(1,2*tail);
elseif statistic >= 0
    pValue = tail;
else
    pValue = 1-tail;
end
end
