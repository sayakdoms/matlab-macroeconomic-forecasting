function validatedData = validateQuarterlyData(data,options)
%VALIDATEQUARTERLYDATA Validate the processed macroeconomic dataset.
%   VALIDATED = macro.validateQuarterlyData(DATA) accepts a timetable or a
%   table with observation_date. It checks schema, dates, quarterly
%   continuity, finite numeric observations, and positive GDP/CPI levels.

arguments
    data
    options.DateVariable (1,1) string = "observation_date"
    options.DataName (1,1) string = "quarterly macroeconomic data"
    options.RequiredVariables (1,:) string = [ ...
        "RealGDP","Unemployment","CPI","InterestRate", ...
        "GDPGrowth","Inflation"]
end

if ~(istable(data) || istimetable(data))
    error("macro:validateQuarterlyData:InvalidInputType", ...
        "%s must be a table or timetable.",options.DataName);
end
if height(data) == 0
    error("macro:validateQuarterlyData:EmptyData", ...
        "%s must contain at least one observation.",options.DataName);
end

macro.requireTableVariables(data,options.RequiredVariables, ...
    DataName=options.DataName);

if istimetable(data)
    dates = data.Properties.RowTimes;
else
    macro.requireTableVariables(data,options.DateVariable, ...
        DataName=options.DataName);
    dates = data.(options.DateVariable);
end
dates = normalizeDates(dates,options.DataName);

if numel(dates) ~= height(data) || any(isnat(dates))
    error("macro:validateQuarterlyData:InvalidDates", ...
        "%s contains invalid or missing observation dates.",options.DataName);
end
if numel(unique(dates)) ~= numel(dates)
    error("macro:validateQuarterlyData:DuplicateDates", ...
        "%s contains duplicate observation dates.",options.DataName);
end
if any(diff(dates) < seconds(0))
    error("macro:validateQuarterlyData:UnsortedDates", ...
        "%s observation dates must be strictly increasing.",options.DataName);
end

if any(dates ~= dateshift(dates,"start","quarter"))
    error("macro:validateQuarterlyData:QuarterlyGap", ...
        "%s dates must be aligned to the start of each quarter.", ...
        options.DataName);
end
if numel(dates) > 1
    expectedDates = dateshift(dates(1:end-1),"start","quarter","next");
    if any(dates(2:end) ~= expectedDates)
        error("macro:validateQuarterlyData:QuarterlyGap", ...
            ["%s dates must be consecutive quarter starts without gaps " + ...
             "or off-cycle observations."],options.DataName);
    end
end

for variableName = options.RequiredVariables
    values = data.(variableName);
    if ~isnumeric(values) || ~isreal(values) || ...
            ~isvector(values) || numel(values) ~= height(data)
        error("macro:validateQuarterlyData:NonnumericVariable", ...
            "%s variable %s must be a real numeric vector.", ...
            options.DataName,variableName);
    end
    if any(~isfinite(values))
        error("macro:validateQuarterlyData:NonfiniteValues", ...
            "%s variable %s contains NaN or Inf values.", ...
            options.DataName,variableName);
    end
end

for levelVariable = ["RealGDP","CPI"]
    if ismember(levelVariable,options.RequiredVariables) && ...
            any(data.(levelVariable) <= 0)
        error("macro:validateQuarterlyData:NonpositiveLevels", ...
            "%s variable %s must contain strictly positive levels.", ...
            options.DataName,levelVariable);
    end
end

validatedData = data;
if ~istimetable(validatedData)
    validatedData.(options.DateVariable) = dates;
end
end

function dates = normalizeDates(dateValues,dataName)
if isdatetime(dateValues)
    dates = dateValues;
elseif isstring(dateValues) || iscellstr(dateValues) || ...
        ischar(dateValues) || iscategorical(dateValues)
    try
        dates = datetime(string(dateValues));
    catch dateError
        error("macro:validateQuarterlyData:InvalidDates", ...
            "%s contains dates that cannot be parsed: %s", ...
            dataName,dateError.message);
    end
else
    error("macro:validateQuarterlyData:InvalidDateType", ...
        "%s observation dates must be datetime or text.",dataName);
end
dates = dates(:);
end
