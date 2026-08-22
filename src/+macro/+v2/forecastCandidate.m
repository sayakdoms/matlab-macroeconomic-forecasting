function result = forecastCandidate(prepared,trainingRows,targetRow,candidate)
%FORECASTCANDIDATE Fit one declared candidate and forecast one target.

arguments
    prepared (1,1) struct
    trainingRows (:,1) double {mustBeInteger,mustBePositive}
    targetRow (1,1) double {mustBeInteger,mustBePositive}
    candidate table
end

if height(candidate) ~= 1
    error("macro:v2:forecastCandidate:InvalidCandidate", ...
        "Candidate must contain exactly one protocol row.");
end
if any(trainingRows >= targetRow) || numel(unique(trainingRows)) ~= ...
        numel(trainingRows) || any(diff(trainingRows) <= 0)
    error("macro:v2:forecastCandidate:InvalidTrainingRows", ...
        "Training rows must be unique, sorted, and strictly before targetRow.");
end
if targetRow > numel(prepared.Y)
    error("macro:v2:forecastCandidate:TargetOutOfRange", ...
        "targetRow exceeds the prepared dataset.");
end

family = string(candidate.ModelFamily);
forecast = NaN;
status = "valid";
diagnostic = "";
coefficients = NaN(0,1);
hacBandwidth = NaN;
trainingMean = NaN(0,1);
trainingScale = NaN(0,1);
try
    switch family
        case "Persistence"
            forecast = prepared.Persistence(targetRow);
        case "HistoricalMean"
            forecast = mean(prepared.Y(trainingRows));
        case "AR"
            lag = candidate.ARLag;
            X = [ones(numel(trainingRows),1), ...
                prepared.ARLags(trainingRows,1:lag)];
            xTarget = [1,prepared.ARLags(targetRow,1:lag)];
            model = macro.estimateOLS(X,prepared.Y(trainingRows));
            coefficients = model.Coefficients;
            forecast = xTarget*coefficients;
        case {"MacroOLSClassical","MacroOLSHAC"}
            X = prepared.MacroX(trainingRows,:);
            xTarget = prepared.MacroX(targetRow,:);
            model = macro.estimateOLS(X,prepared.Y(trainingRows));
            coefficients = model.Coefficients;
            if family == "MacroOLSHAC"
                hac = macro.v2.neweyWestCovariance( ...
                    X,prepared.Y(trainingRows));
                coefficients = hac.Coefficients;
                hacBandwidth = hac.Bandwidth;
            end
            forecast = xTarget*coefficients;
        case "RidgeMacro"
            X = prepared.MacroX(trainingRows,2:end);
            xTarget = prepared.MacroX(targetRow,2:end);
            trainingMean = mean(X,1);
            trainingScale = std(X,0,1);
            trainingScale(trainingScale == 0) = 1;
            Z = [ones(size(X,1),1),(X-trainingMean)./trainingScale];
            zTarget = [1,(xTarget-trainingMean)./trainingScale];
            penalty = diag([0,repmat(candidate.RidgeLambda,1,size(X,2))]);
            coefficients = (Z'*Z+penalty)\(Z'*prepared.Y(trainingRows));
            forecast = zTarget*coefficients;
        otherwise
            error("macro:v2:forecastCandidate:UnknownFamily", ...
                "Unknown candidate family: %s",family);
    end
catch modelError
    if ismember(string(modelError.identifier),[ ...
            "macro:estimateOLS:RankDeficientDesign", ...
            "macro:estimateOLS:InsufficientDegreesOfFreedom", ...
            "macro:v2:neweyWestCovariance:InvalidDesign"])
        status = "invalid-design";
        diagnostic = string(modelError.identifier)+": "+ ...
            string(modelError.message);
    else
        rethrow(modelError);
    end
end
if status == "valid" && ~isfinite(forecast)
    status = "invalid-numerical-result";
    diagnostic = "Candidate produced a nonfinite forecast.";
    forecast = NaN;
end

result = struct( ...
    "Candidate",string(candidate.Candidate), ...
    "ModelFamily",family, ...
    "ARLag",candidate.ARLag, ...
    "RidgeLambda",candidate.RidgeLambda, ...
    "Priority",candidate.Priority, ...
    "Forecast",forecast, ...
    "Status",status, ...
    "Diagnostic",diagnostic, ...
    "Coefficients",coefficients, ...
    "HACBandwidth",hacBandwidth, ...
    "TrainingMean",trainingMean, ...
    "TrainingScale",trainingScale);
end
