function result = recursiveStabilityDiagnostics(X,Y,dates,variableNames,options)
%RECURSIVESTABILITYDIAGNOSTICS Recursive paths, residuals, CUSUM, CUSUMSQ.
%   CUSUM uses the Brown-Durbin-Evans 5% boundary. CUSUMSQ uses a
%   fixed-seed Monte Carlo simultaneous band under iid Gaussian recursive
%   residuals, and is therefore reported as a conditional sensitivity test.

arguments
    X double
    Y double
    dates datetime
    variableNames string
    options.CoefficientMinimumObservations (1,1) double {mustBeInteger,mustBePositive} = 40
    options.CUSUMAlpha (1,1) double {mustBeGreaterThan(options.CUSUMAlpha,0),mustBeLessThan(options.CUSUMAlpha,1)} = 0.05
    options.CUSUMBoundaryConstant (1,1) double {mustBePositive} = 0.948
    options.CUSUMSQAlpha (1,1) double {mustBeGreaterThan(options.CUSUMSQAlpha,0),mustBeLessThan(options.CUSUMSQAlpha,1)} = 0.05
    options.CUSUMSQReplications (1,1) double {mustBeInteger,mustBePositive} = 5000
    options.CUSUMSQSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2606
end

validateInputs(X,Y,dates,variableNames);
Y = Y(:); dates = dates(:); variableNames = variableNames(:);
[n,k] = size(X);
coefficientStart = max(options.CoefficientMinimumObservations,k+1);
if coefficientStart > n
    error("macro:v2:recursiveStabilityDiagnostics:InsufficientHistory", ...
        "Recursive coefficient paths require at least %d observations.",coefficientStart);
end

numPathDates = n-coefficientStart+1;
EndDate = repelem(dates(coefficientStart:end),k);
Observations = repelem((coefficientStart:n)',k);
Variable = repmat(variableNames,numPathDates,1);
Coefficient = zeros(numPathDates*k,1);
StandardError = zeros(numPathDates*k,1);
for endRow = coefficientStart:n
    if rank(X(1:endRow,:)) < k
        error("macro:v2:recursiveStabilityDiagnostics:RankDeficientHistory", ...
            "Expanding design is rank deficient through row %d.",endRow);
    end
    model = macro.estimateOLS(X(1:endRow,:),Y(1:endRow), ...
        CovarianceSolver="inverse");
    rows = (endRow-coefficientStart)*k+(1:k);
    Coefficient(rows) = model.Coefficients;
    StandardError(rows) = model.StandardErrors;
end
ExPostOnly = true(height(table(EndDate)),1);
coefficientPaths = table(EndDate,Observations,Variable,Coefficient, ...
    StandardError,ExPostOnly);

recursive = zeros(n-k,1);
for row = k+1:n
    priorX = X(1:row-1,:);
    if rank(priorX) < k
        error("macro:v2:recursiveStabilityDiagnostics:RankDeficientHistory", ...
            "The recursive-residual design is rank deficient through row %d.",row-1);
    end
    beta = priorX\Y(1:row-1);
    leverage = X(row,:)*((priorX'*priorX)\X(row,:)');
    recursive(row-k) = (Y(row)-X(row,:)*beta)/sqrt(1+leverage);
end
m = numel(recursive);
scale = sqrt(sum(recursive.^2)/m);
if scale <= eps(max(abs(Y)))
    standardized = zeros(m,1);
else
    standardized = recursive/scale;
end
CUSUM = cumsum(standardized);
step = (1:m)';
CUSUMUpper = options.CUSUMBoundaryConstant*sqrt(m)+ ...
    2*options.CUSUMBoundaryConstant*step/sqrt(m);
CUSUMLower = -CUSUMUpper;

sumSquares = sum(recursive.^2);
if sumSquares <= eps(max(abs(Y)))
    CUSUMSQ = step/m;
else
    CUSUMSQ = cumsum(recursive.^2)/sumSquares;
end
criticalDeviation = cusumsqCriticalDeviation(m,options.CUSUMSQAlpha, ...
    options.CUSUMSQReplications,options.CUSUMSQSeed);
expected = step/m;
CUSUMSQUpper = min(1,expected+criticalDeviation);
CUSUMSQLower = max(0,expected-criticalDeviation);
Outlier = abs(standardized) > 3;
residualDiagnostics = table(dates(k+1:end),recursive,standardized, ...
    CUSUM,CUSUMLower,CUSUMUpper,CUSUMSQ,CUSUMSQLower,CUSUMSQUpper, ...
    Outlier,true(m,1),'VariableNames',{'Date','RecursiveResidual', ...
    'StandardizedRecursiveResidual','CUSUM','CUSUMLower', ...
    'CUSUMUpper','CUSUMSQ','CUSUMSQLower','CUSUMSQUpper', ...
    'ThreeSigmaOutlier','ExPostOnly'});

result = struct( ...
    "CoefficientPaths",coefficientPaths, ...
    "ResidualDiagnostics",residualDiagnostics, ...
    "CUSUMReject",any(CUSUM<CUSUMLower | CUSUM>CUSUMUpper), ...
    "CUSUMSQReject",any(CUSUMSQ<CUSUMSQLower | CUSUMSQ>CUSUMSQUpper), ...
    "CUSUMMaxBoundaryRatio",max(abs(CUSUM)./CUSUMUpper), ...
    "CUSUMSQMaxDeviation",max(abs(CUSUMSQ-expected)), ...
    "CUSUMSQCriticalDeviation",criticalDeviation, ...
    "RecursiveResidualScale",scale, ...
    "RecursiveResidualInitialObservations",k, ...
    "CoefficientPathInitialObservations",coefficientStart, ...
    "CUSUMSQMethod","Fixed-seed iid-Gaussian Monte Carlo simultaneous band");
end

function critical = cusumsqCriticalDeviation(m,alpha,replications,seed)
prior = rng;
cleanup = onCleanup(@() rng(prior)); %#ok<NASGU>
rng(seed,"twister");
maxDeviation = zeros(replications,1);
expected = (1:m)'/m;
for draw = 1:replications
    z = randn(m,1).^2;
    path = cumsum(z)/sum(z);
    maxDeviation(draw) = max(abs(path-expected));
end
sorted = sort(maxDeviation);
index = max(1,min(replications,ceil((1-alpha)*replications)));
critical = sorted(index);
end

function validateInputs(X,Y,dates,names)
[n,k] = size(X);
if isempty(X) || any(~isfinite(X),"all") || n <= k || rank(X)<k || ...
        ~isvector(Y) || numel(Y)~=n || any(~isfinite(Y)) || ...
        ~isvector(dates) || numel(dates)~=n || any(isnat(dates)) || ...
        any(dates(2:end)<=dates(1:end-1)) || numel(names)~=k
    error("macro:v2:recursiveStabilityDiagnostics:InvalidInput", ...
        "A full-rank finite design, aligned increasing dates, and one name per column are required.");
end
end
