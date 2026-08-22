function selection = selectAdfLag(series,deterministicModel,options)
%SELECTADFLAG Select a bounded ADF augmentation lag using common-sample AIC.

arguments
    series double
    deterministicModel (1,1) string {mustBeMember( ...
        deterministicModel,["AR","ARD","TS"])}
    options.MaximumLagCap (1,1) double {mustBeInteger,mustBeNonnegative} = 8
end

if ~isvector(series) || numel(series) < 12 || ...
        ~isreal(series) || any(~isfinite(series))
    error("macro:v2:selectAdfLag:InvalidSeries", ...
        "ADF lag selection requires at least 12 finite real observations.");
end
series = series(:);
n = numel(series);
ruleBound = floor(12*(n/100)^(1/4));
pmax = min([options.MaximumLagCap,ruleBound,floor((n-5)/2)]);
effectiveRows = (pmax+2:n)';
dependent = diff(series);
dependent = dependent(effectiveRows-1);

CandidateLag = (0:pmax)';
AIC = NaN(pmax+1,1);
SSE = NaN(pmax+1,1);
Parameters = NaN(pmax+1,1);
for lagIndex = 0:pmax
    design = deterministicTerms(effectiveRows,deterministicModel);
    design = [design,series(effectiveRows-1)]; %#ok<AGROW>
    for differenceLag = 1:lagIndex
        design = [design, ...
            dependentAt(diff(series),effectiveRows-1-differenceLag)]; %#ok<AGROW>
    end
    coefficients = design\dependent;
    residuals = dependent-design*coefficients;
    SSE(lagIndex+1) = sum(residuals.^2);
    Parameters(lagIndex+1) = size(design,2);
    AIC(lagIndex+1) = numel(dependent)*log( ...
        SSE(lagIndex+1)/numel(dependent))+2*Parameters(lagIndex+1);
end
[~,bestIndex] = min(AIC);
selection = struct( ...
    "SelectedLag",CandidateLag(bestIndex), ...
    "MaximumLag",pmax, ...
    "EffectiveObservations",numel(dependent), ...
    "DeterministicModel",deterministicModel, ...
    "Criterion","AIC", ...
    "CommonSample",true, ...
    "Candidates",table(CandidateLag,AIC,SSE,Parameters));
end

function terms = deterministicTerms(timeIndex,model)
switch model
    case "AR"
        terms = zeros(numel(timeIndex),0);
    case "ARD"
        terms = ones(numel(timeIndex),1);
    case "TS"
        terms = [ones(numel(timeIndex),1),timeIndex];
end
end

function values = dependentAt(differences,indices)
values = differences(indices);
end
