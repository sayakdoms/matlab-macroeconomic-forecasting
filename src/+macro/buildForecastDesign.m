function design = buildForecastDesign(data)
%BUILDFORECASTDESIGN Reproduce the Phase 8/10/11 forecast design matrix.
%   The matrix contains an intercept, GDP growth lag 1, and lags 1 through 4
%   of inflation, unemployment, and interest rates. No contemporaneous
%   predictor is included.

arguments
    data
end

data = macro.validateQuarterlyData(data);
maxLag = 4;
numRows = height(data);
if numRows <= maxLag
    error("macro:buildForecastDesign:InsufficientObservations", ...
        "Forecast design requires at least %d observations.",maxLag+1);
end

responseRows = ((maxLag+1):numRows)';
numObservations = numel(responseRows);
gdpLagRows = responseRows - 1;
lagRows = responseRows - (1:maxLag);

design = struct;
design.X = [ ...
    ones(numObservations,1), ...
    data.GDPGrowth(gdpLagRows), ...
    data.Inflation(lagRows), ...
    data.Unemployment(lagRows), ...
    data.InterestRate(lagRows)];
design.Y = data.GDPGrowth(responseRows);
design.Dates = observationDates(data,responseRows);
design.VariableNames = [ ...
    "Intercept","GDPGrowth_L1", ...
    "Inflation_L1","Inflation_L2","Inflation_L3","Inflation_L4", ...
    "Unemployment_L1","Unemployment_L2", ...
    "Unemployment_L3","Unemployment_L4", ...
    "InterestRate_L1","InterestRate_L2", ...
    "InterestRate_L3","InterestRate_L4"];
design.ResponseRows = responseRows;
design.PredictorSourceRows = [ ...
    NaN(numObservations,1),gdpLagRows,lagRows,lagRows,lagRows];
design.MaxLag = maxLag;
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
