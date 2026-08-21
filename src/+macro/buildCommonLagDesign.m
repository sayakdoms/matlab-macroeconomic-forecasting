function design = buildCommonLagDesign(data,lag)
%BUILDCOMMONLAGDESIGN Reproduce the Phase 6 common-lag design matrix.
%   DESIGN = macro.buildCommonLagDesign(DATA,LAG) aligns current GDP growth
%   with one common lag of inflation, unemployment, and interest rates.
%   Each lag intentionally uses its own available sample, matching Phase 6.

arguments
    data
    lag (1,1) double {mustBeInteger,mustBeNonnegative}
end

data = macro.validateQuarterlyData(data);
numRows = height(data);
if lag >= numRows
    error("macro:buildCommonLagDesign:InsufficientObservations", ...
        "Lag %d requires more than %d observations.",lag,numRows);
end

responseRows = ((1+lag):numRows)';
predictorRows = (1:(numRows-lag))';
numObservations = numel(responseRows);

design = struct;
design.X = [ ...
    ones(numObservations,1), ...
    data.Inflation(predictorRows), ...
    data.Unemployment(predictorRows), ...
    data.InterestRate(predictorRows)];
design.Y = data.GDPGrowth(responseRows);
design.Dates = observationDates(data,responseRows);
design.VariableNames = [ ...
    "Intercept","Inflation","Unemployment","InterestRate"];
design.ResponseRows = responseRows;
design.PredictorSourceRows = [ ...
    NaN(numObservations,1), ...
    predictorRows,predictorRows,predictorRows];
design.Lag = lag;
end

function dates = observationDates(data,rows)
if istimetable(data)
    allDates = data.Properties.RowTimes;
else
    allDates = data.observation_date;
end
dates = allDates(rows);
dates = dates(:);
end
