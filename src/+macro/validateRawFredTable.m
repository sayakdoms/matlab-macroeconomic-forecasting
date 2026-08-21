function validatedTable = validateRawFredTable(rawTable,valueVariable,options)
%VALIDATERAWFREDTABLE Validate one raw FRED download table.
%   VALIDATED = macro.validateRawFredTable(T,VALUEVARIABLE) verifies the
%   observation-date column and the named numeric observation column. Date
%   text is normalized to datetime in the returned table.

arguments
    rawTable
    valueVariable (1,1) string
    options.DateVariable (1,1) string = "observation_date"
    options.DataName (1,1) string = "raw FRED table"
    options.AllowMissingObservations (1,1) logical = false
end

if ~istable(rawTable) || istimetable(rawTable)
    error("macro:validateRawFredTable:InvalidInputType", ...
        "%s must be a table.",options.DataName);
end

if height(rawTable) == 0
    error("macro:validateRawFredTable:EmptyTable", ...
        "%s must contain at least one observation.",options.DataName);
end

macro.requireTableVariables(rawTable, ...
    [options.DateVariable valueVariable],DataName=options.DataName);

dates = normalizeDates(rawTable.(options.DateVariable),options.DataName);

if numel(dates) ~= height(rawTable)
    error("macro:validateRawFredTable:InvalidDates", ...
        "%s must contain one date per table row.",options.DataName);
end
if any(isnat(dates))
    error("macro:validateRawFredTable:InvalidDates", ...
        "%s contains invalid or missing observation dates.",options.DataName);
end
if numel(unique(dates)) ~= numel(dates)
    error("macro:validateRawFredTable:DuplicateDates", ...
        "%s contains duplicate observation dates.",options.DataName);
end
if any(diff(dates) < seconds(0))
    error("macro:validateRawFredTable:UnsortedDates", ...
        "%s observation dates must be strictly increasing.",options.DataName);
end

observations = rawTable.(valueVariable);
if ~isnumeric(observations) || ~isreal(observations) || ...
        ~isvector(observations) || numel(observations) ~= height(rawTable)
    error("macro:validateRawFredTable:NonnumericObservations", ...
        "%s variable %s must be a real numeric vector.", ...
        options.DataName,valueVariable);
end
if any(isinf(observations)) || ...
        (~options.AllowMissingObservations && any(isnan(observations)))
    error("macro:validateRawFredTable:NonfiniteObservations", ...
        "%s variable %s contains NaN or Inf values.", ...
        options.DataName,valueVariable);
end

validatedTable = rawTable;
validatedTable.(options.DateVariable) = dates;
end

function dates = normalizeDates(dateValues,dataName)
if isdatetime(dateValues)
    dates = dateValues;
elseif isstring(dateValues) || iscellstr(dateValues) || ...
        ischar(dateValues) || iscategorical(dateValues)
    try
        dates = datetime(string(dateValues));
    catch dateError
        error("macro:validateRawFredTable:InvalidDates", ...
            "%s contains dates that cannot be parsed: %s", ...
            dataName,dateError.message);
    end
else
    error("macro:validateRawFredTable:InvalidDateType", ...
        "%s observation dates must be datetime or text.",dataName);
end
dates = dates(:);
end
