function result = neweyWestCovariance(X,Y,options)
%NEWEYWESTCOVARIANCE Compute Bartlett-kernel HAC covariance for OLS.
%   Bandwidth is the maximum included autocovariance lag. Bartlett weights
%   are 1-lag/(bandwidth+1). No small-sample scaling or prewhitening is used.

arguments
    X double
    Y double
    options.Bandwidth (1,1) double {mustBeInteger} = -1
end

if ~ismatrix(X) || isempty(X) || ~isreal(X) || any(~isfinite(X),"all")
    error("macro:v2:neweyWestCovariance:InvalidDesign", ...
        "X must be a nonempty finite real matrix.");
end
if ~isvector(Y) || numel(Y) ~= size(X,1) || ...
        ~isreal(Y) || any(~isfinite(Y))
    error("macro:v2:neweyWestCovariance:InvalidResponse", ...
        "Y must be finite and match the number of rows in X.");
end
Y = Y(:);
[n,k] = size(X);
if n <= k || rank(X) < k
    error("macro:v2:neweyWestCovariance:InvalidDesign", ...
        "HAC inference requires a full-rank design with n greater than k.");
end
if options.Bandwidth == -1
    bandwidth = macro.v2.bandwidthRule(n);
else
    if options.Bandwidth < 0
        error("macro:v2:neweyWestCovariance:InvalidBandwidth", ...
            "Bandwidth must be -1 for automatic selection or nonnegative.");
    end
    bandwidth = options.Bandwidth;
end
if bandwidth > n-1
    error("macro:v2:neweyWestCovariance:BandwidthTooLarge", ...
        "Bandwidth must not exceed n-1.");
end

coefficients = X\Y;
residuals = Y-X*coefficients;
scores = X.*residuals;
meat = scores'*scores;
for lag = 1:bandwidth
    weight = 1-lag/(bandwidth+1);
    lagCovariance = scores(lag+1:end,:)'*scores(1:end-lag,:);
    meat = meat+weight*(lagCovariance+lagCovariance');
end
crossProduct = X'*X;
covariance = (crossProduct\meat)/crossProduct;
covariance = (covariance+covariance')/2;
standardErrors = sqrt(max(diag(covariance),0));
tStatistics = coefficients./standardErrors;
approxPValues = erfc(abs(tStatistics)/sqrt(2));

result = struct( ...
    "Coefficients",coefficients, ...
    "Residuals",residuals, ...
    "Covariance",covariance, ...
    "StandardErrors",standardErrors, ...
    "TStatistics",tStatistics, ...
    "ApproxPValues",approxPValues, ...
    "Bandwidth",bandwidth, ...
    "Kernel","Bartlett", ...
    "SmallSampleCorrection",false, ...
    "PrewhiteningLags",0);
end
