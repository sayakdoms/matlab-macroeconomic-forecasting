function [folds,outerIndices] = buildNestedValidationFolds(prepared,protocol)
%BUILDNESTEDVALIDATIONFOLDS Construct deterministic expanding inner folds.

arguments
    prepared (1,1) struct
    protocol (1,1) struct = macro.v2.modelSelectionProtocol()
end

data = prepared.Data;
outerIndices = find(data.TargetQuarter >= protocol.OuterEvaluationStart);
minimumOuterIndex = protocol.MinimumTrainingObservations+ ...
    protocol.InnerValidationQuarters+1;
outerIndices = outerIndices(outerIndices >= minimumOuterIndex);
if isempty(outerIndices)
    error("macro:v2:buildNestedValidationFolds:NoEligibleOuterTargets", ...
        "No outer target has the required training and validation history.");
end

numFolds = numel(outerIndices)*protocol.InnerValidationQuarters;
OuterIndex = zeros(numFolds,1);
OuterTargetQuarter = NaT(numFolds,1);
OuterForecastOrigin = NaT(numFolds,1);
InnerFold = zeros(numFolds,1);
ValidationIndex = zeros(numFolds,1);
ValidationTargetQuarter = NaT(numFolds,1);
ValidationForecastOrigin = NaT(numFolds,1);
TrainingStartIndex = ones(numFolds,1);
TrainingEndIndex = zeros(numFolds,1);
TrainingStartTargetQuarter = NaT(numFolds,1);
TrainingEndTargetQuarter = NaT(numFolds,1);
TrainingObservations = zeros(numFolds,1);
MaxTrainingTargetReleaseDate = NaT(numFolds,1);
MaxTrainingPredictorAvailabilityDate = NaT(numFolds,1);
ValidationPredictorAvailabilityDate = NaT(numFolds,1);

row = 0;
for outerIndex = outerIndices'
    validationIndices = (outerIndex-protocol.InnerValidationQuarters): ...
        (outerIndex-1);
    for fold = 1:numel(validationIndices)
        row = row+1;
        validationIndex = validationIndices(fold);
        trainingEnd = validationIndex-1;
        OuterIndex(row) = outerIndex;
        OuterTargetQuarter(row) = data.TargetQuarter(outerIndex);
        OuterForecastOrigin(row) = data.ForecastOrigin(outerIndex);
        InnerFold(row) = fold;
        ValidationIndex(row) = validationIndex;
        ValidationTargetQuarter(row) = ...
            data.TargetQuarter(validationIndex);
        ValidationForecastOrigin(row) = ...
            data.ForecastOrigin(validationIndex);
        TrainingEndIndex(row) = trainingEnd;
        TrainingStartTargetQuarter(row) = data.TargetQuarter(1);
        TrainingEndTargetQuarter(row) = data.TargetQuarter(trainingEnd);
        TrainingObservations(row) = trainingEnd;
        MaxTrainingTargetReleaseDate(row) = max( ...
            data.TargetFirstReleaseDate(1:trainingEnd));
        MaxTrainingPredictorAvailabilityDate(row) = max( ...
            prepared.MaximumPredictorAvailabilityDate(1:trainingEnd));
        ValidationPredictorAvailabilityDate(row) = ...
            prepared.MaximumPredictorAvailabilityDate(validationIndex);
    end
end

folds = table(OuterIndex,OuterTargetQuarter,OuterForecastOrigin, ...
    InnerFold,ValidationIndex,ValidationTargetQuarter, ...
    ValidationForecastOrigin,TrainingStartIndex,TrainingEndIndex, ...
    TrainingStartTargetQuarter,TrainingEndTargetQuarter, ...
    TrainingObservations,MaxTrainingTargetReleaseDate, ...
    MaxTrainingPredictorAvailabilityDate, ...
    ValidationPredictorAvailabilityDate);

if any(folds.TrainingEndIndex >= folds.ValidationIndex) || ...
        any(folds.ValidationIndex >= folds.OuterIndex) || ...
        any(folds.MaxTrainingTargetReleaseDate > ...
        folds.ValidationForecastOrigin) || ...
        any(folds.MaxTrainingPredictorAvailabilityDate > ...
        folds.ValidationForecastOrigin) || ...
        any(folds.ValidationPredictorAvailabilityDate > ...
        folds.ValidationForecastOrigin)
    error("macro:v2:buildNestedValidationFolds:LeakageDetected", ...
        "A nested fold includes unavailable or non-prior information.");
end
end
