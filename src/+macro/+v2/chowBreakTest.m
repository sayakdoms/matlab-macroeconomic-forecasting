function result = chowBreakTest(X,Y,dates,breakDate)
%CHOWBREAKTEST Reproduce the project's fixed-date Chow-style calculation.

arguments
    X double
    Y double
    dates datetime
    breakDate (1,1) datetime
end

validateInputs(X,Y,dates);
Y = Y(:);
dates = dates(:);
pre = dates < breakDate;
post = ~pre;
[n,k] = size(X);
n1 = sum(pre);
n2 = sum(post);
if n1 <= k || n2 <= k
    error("macro:v2:chowBreakTest:InsufficientRegimeSize", ...
        "Each regime must contain more than %d observations; received %d and %d.", ...
        k,n1,n2);
end
if rank(X(pre,:)) < k || rank(X(post,:)) < k
    error("macro:v2:chowBreakTest:RankDeficientRegime", ...
        "Both regime designs must have full column rank.");
end

pooled = macro.estimateOLS(X,Y,CovarianceSolver="inverse");
first = macro.estimateOLS(X(pre,:),Y(pre),CovarianceSolver="inverse");
second = macro.estimateOLS(X(post,:),Y(post),CovarianceSolver="inverse");
restrictedSSE = pooled.SSE;
unrestrictedSSE = first.SSE+second.SSE;
df1 = k;
df2 = n-2*k;
statistic = ((restrictedSSE-unrestrictedSSE)/df1)/(unrestrictedSSE/df2);
pValue = fSurvival(statistic,df1,df2);

result = struct( ...
    "BreakDate",breakDate,"Statistic",statistic,"PValue",pValue, ...
    "PreObservations",n1,"PostObservations",n2, ...
    "ParametersPerRegime",k,"NumeratorDegreesFreedom",df1, ...
    "DenominatorDegreesFreedom",df2,"PooledModel",pooled, ...
    "PreModel",first,"PostModel",second,"PreIndex",pre,"PostIndex",post);
end

function validateInputs(X,Y,dates)
if isempty(X) || ~ismatrix(X) || any(~isfinite(X),"all") || ...
        ~isvector(Y) || numel(Y) ~= size(X,1) || any(~isfinite(Y)) || ...
        ~isvector(dates) || numel(dates) ~= size(X,1) || ...
        any(isnat(dates)) || any(dates(2:end) <= dates(1:end-1))
    error("macro:v2:chowBreakTest:InvalidInput", ...
        "X, Y, and strictly increasing dates must be finite and aligned.");
end
end

function p = fSurvival(value,df1,df2)
if value <= 0
    p = 1;
    return;
end
z = (df1*value)/(df1*value+df2);
p = max(0,min(1,1-betainc(z,df1/2,df2/2)));
end
