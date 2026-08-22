function result = supWaldBreakSearch(X,Y,dates,options)
%SUPWALDBREAKSEARCH Trimmed Quandt-Andrews-style single-break search.
%   The maximum fixed-date Chow/Wald F statistic is evaluated over a
%   predeclared trimmed set. A fixed-seed residual bootstrap supplies a
%   global null p-value and a conditional break-date interval.

arguments
    X double
    Y double
    dates datetime
    options.TrimFraction (1,1) double {mustBeGreaterThanOrEqual(options.TrimFraction,0),mustBeLessThan(options.TrimFraction,0.5)} = 0.15
    options.MinimumExtraObservations (1,1) double {mustBeInteger,mustBeNonnegative} = 5
    options.BootstrapReplications (1,1) double {mustBeInteger,mustBeNonnegative} = 499
    options.BootstrapBlockLength (1,1) double {mustBeInteger,mustBePositive} = 4
    options.BootstrapSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2610
    options.ConfidenceLevel (1,1) double {mustBeGreaterThan(options.ConfidenceLevel,0),mustBeLessThan(options.ConfidenceLevel,1)} = 0.95
end

validateInputs(X,Y,dates);
Y=Y(:); dates=dates(:);
[n,k] = size(X);
minimumRegime = max(ceil(options.TrimFraction*n),k+options.MinimumExtraObservations);
splits = (minimumRegime:(n-minimumRegime))';
if isempty(splits)
    error("macro:v2:supWaldBreakSearch:InsufficientRegimeSize", ...
        "No admissible break remains after requiring %d observations per regime.",minimumRegime);
end

pooledBeta = X\Y;
pooledFitted = X*pooledBeta;
pooledResiduals = Y-pooledFitted;
[statistics,valid] = statisticPath(X,Y,splits);
if ~all(valid)
    error("macro:v2:supWaldBreakSearch:RankDeficientRegime", ...
        "At least one admissible regime design is rank deficient.");
end
[supStatistic,maxIndex] = max(statistics);
bestSplit = splits(maxIndex);
candidateDates = dates(splits+1);
df1 = k;
df2 = n-2*k;
naiveP = arrayfun(@(v) fSurvival(v,df1,df2),statistics);

bootstrapP = NaN;
uncertaintyStart = NaT;
uncertaintyEnd = NaT;
bootstrapSup = NaN(options.BootstrapReplications,1);
bootstrapBreakRows = NaN(options.BootstrapReplications,1);
if options.BootstrapReplications > 0
    prior = rng;
    cleanup = onCleanup(@() rng(prior)); %#ok<NASGU>
    rng(options.BootstrapSeed,"twister");
    centeredNullResiduals = pooledResiduals-mean(pooledResiduals);
    firstBeta = X(1:bestSplit,:)\Y(1:bestSplit);
    secondBeta = X(bestSplit+1:end,:)\Y(bestSplit+1:end);
    alternativeFitted = [X(1:bestSplit,:)*firstBeta; ...
        X(bestSplit+1:end,:)*secondBeta];
    firstResiduals = Y(1:bestSplit)-alternativeFitted(1:bestSplit);
    secondResiduals = Y(bestSplit+1:end)-alternativeFitted(bestSplit+1:end);
    firstResiduals = firstResiduals-mean(firstResiduals);
    secondResiduals = secondResiduals-mean(secondResiduals);
    for draw = 1:options.BootstrapReplications
        nullY = pooledFitted+circularBlockResample( ...
            centeredNullResiduals,n,options.BootstrapBlockLength);
        nullStatistics = statisticPath(X,nullY,splits);
        bootstrapSup(draw) = max(nullStatistics);
        alternativeY = alternativeFitted+[ ...
            circularBlockResample(firstResiduals,bestSplit, ...
                options.BootstrapBlockLength); ...
            circularBlockResample(secondResiduals,n-bestSplit, ...
                options.BootstrapBlockLength)];
        alternativeStatistics = statisticPath(X,alternativeY,splits);
        [~,bootstrapMaximum] = max(alternativeStatistics);
        bootstrapBreakRows(draw) = splits(bootstrapMaximum)+1;
    end
    bootstrapP = (1+sum(bootstrapSup>=supStatistic))/ ...
        (options.BootstrapReplications+1);
    alpha = 1-options.ConfidenceLevel;
    lowerRow = empiricalQuantile(bootstrapBreakRows,alpha/2);
    upperRow = empiricalQuantile(bootstrapBreakRows,1-alpha/2);
    uncertaintyStart = dates(lowerRow);
    uncertaintyEnd = dates(upperRow);
end

IsMaximum = false(numel(splits),1); IsMaximum(maxIndex)=true;
Within95PercentOfMaximum = statistics >= 0.95*supStatistic;
candidateTable = table(candidateDates,splits,n-splits,statistics,naiveP, ...
    IsMaximum,Within95PercentOfMaximum,repmat(true,numel(splits),1), ...
    'VariableNames',{'CandidateBreakDate','PreObservations', ...
    'PostObservations','WaldFStatistic','NaivePointwisePValue', ...
    'IsMaximum','Within95PercentOfMaximum','ExPostOnly'});

result = struct( ...
    "CandidateTable",candidateTable,"SupStatistic",supStatistic, ...
    "BreakDate",dates(bestSplit+1),"BestSplit",bestSplit, ...
    "NaivePointwisePValue",naiveP(maxIndex), ...
    "BootstrapGlobalPValue",bootstrapP, ...
    "BreakDateUncertaintyStart",uncertaintyStart, ...
    "BreakDateUncertaintyEnd",uncertaintyEnd, ...
    "TrimFraction",options.TrimFraction, ...
    "MinimumRegimeObservations",minimumRegime, ...
    "NumeratorDegreesFreedom",df1,"DenominatorDegreesFreedom",df2, ...
    "BootstrapReplications",options.BootstrapReplications, ...
    "BootstrapBlockLength",options.BootstrapBlockLength, ...
    "BootstrapSeed",options.BootstrapSeed, ...
    "BootstrapSupStatistics",bootstrapSup, ...
    "BootstrapBreakRows",bootstrapBreakRows, ...
    "InferenceCaveat","Circular moving-block residual-bootstrap p-value; break-date interval is conditional on a selected single-break model and is not post-selection exact.");
end

function sample=circularBlockResample(values,sampleSize,blockLength)
values=values(:); sourceSize=numel(values);
effectiveLength=min(blockLength,sourceSize);
numberBlocks=ceil(sampleSize/effectiveLength);
sample=zeros(numberBlocks*effectiveLength,1);
for block=1:numberBlocks
    start=randi(sourceSize);
    indices=mod((start-1)+(0:effectiveLength-1),sourceSize)+1;
    rows=(block-1)*effectiveLength+(1:effectiveLength);
    sample(rows)=values(indices);
end
sample=sample(1:sampleSize);
end

function [statistics,valid] = statisticPath(X,Y,splits)
n=size(X,1); k=size(X,2);
pooledResidual=Y-X*(X\Y);
pooledSSE=sum(pooledResidual.^2);
statistics=NaN(numel(splits),1); valid=false(numel(splits),1);
for index=1:numel(splits)
    split=splits(index);
    firstX=X(1:split,:); secondX=X(split+1:end,:);
    if rank(firstX)<k || rank(secondX)<k, continue; end
    firstResidual=Y(1:split)-firstX*(firstX\Y(1:split));
    secondResidual=Y(split+1:end)-secondX*(secondX\Y(split+1:end));
    unrestricted=sum(firstResidual.^2)+sum(secondResidual.^2);
    statistics(index)=max(0,((pooledSSE-unrestricted)/k)/(unrestricted/(n-2*k)));
    valid(index)=isfinite(statistics(index));
end
end

function row=empiricalQuantile(values,probability)
values=sort(values(:));
index=max(1,min(numel(values),ceil(probability*numel(values))));
row=round(values(index));
end

function validateInputs(X,Y,dates)
[n,k]=size(X);
if isempty(X) || n<=2*k || rank(X)<k || any(~isfinite(X),"all") || ...
        ~isvector(Y) || numel(Y)~=n || any(~isfinite(Y)) || ...
        ~isvector(dates) || numel(dates)~=n || any(isnat(dates)) || ...
        any(dates(2:end)<=dates(1:end-1))
    error("macro:v2:supWaldBreakSearch:InvalidInput", ...
        "A full-rank finite design with aligned increasing dates is required.");
end
end

function p=fSurvival(value,df1,df2)
if value<=0, p=1; return; end
z=(df1*value)/(df1*value+df2);
p=max(0,min(1,1-betainc(z,df1/2,df2/2)));
end
