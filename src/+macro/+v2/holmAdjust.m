function adjusted = holmAdjust(pValues)
%HOLMADJUST Holm family-wise adjusted p-values in original order.

arguments
    pValues double
end
if ~isvector(pValues) || isempty(pValues) || ...
        any(pValues(~isnan(pValues)) < 0 | pValues(~isnan(pValues)) > 1)
    error("macro:v2:holmAdjust:InvalidPValues", ...
        "P-values must be a nonempty vector containing values in [0,1] or NaN.");
end
inputSize = size(pValues);
pValues = pValues(:);
adjusted = NaN(size(pValues));
validIndices = find(~isnan(pValues));
[sortedValues,order] = sort(pValues(validIndices));
m = numel(sortedValues);
sortedAdjusted = zeros(m,1);
runningMaximum = 0;
for index = 1:m
    runningMaximum = max(runningMaximum, ...
        (m-index+1)*sortedValues(index));
    sortedAdjusted(index) = min(1,runningMaximum);
end
adjusted(validIndices(order)) = sortedAdjusted;
adjusted = reshape(adjusted,inputSize);
end
