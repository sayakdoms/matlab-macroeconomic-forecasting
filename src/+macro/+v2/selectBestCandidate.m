function selectedRow = selectBestCandidate(scores,protocol)
%SELECTBESTCANDIDATE Apply the deterministic V2.4 RMSE tie break.

arguments
    scores table
    protocol (1,1) struct = macro.v2.modelSelectionProtocol()
end
macro.requireTableVariables(scores, ...
    ["ValidationRMSE","Priority","RidgeLambda","Status"], ...
    DataName="candidate validation scores");
valid = string(scores.Status) == "valid" & isfinite(scores.ValidationRMSE);
if ~any(valid)
    error("macro:v2:selectBestCandidate:NoValidCandidate", ...
        "No candidate produced a complete set of valid inner forecasts.");
end
validScores = scores(valid,:);
minimumRMSE = min(validScores.ValidationRMSE);
tied = abs(validScores.ValidationRMSE-minimumRMSE) <= ...
    protocol.TieTolerance;
validScores = validScores(tied,:);
ridgeOrder = validScores.RidgeLambda;
ridgeOrder(isnan(ridgeOrder)) = Inf;
[~,order] = sortrows([validScores.Priority,ridgeOrder],[1 2]);
selectedRow = validScores(order(1),:);
end
