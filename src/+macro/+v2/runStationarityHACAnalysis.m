function output = runStationarityHACAnalysis(cfg)
%RUNSTATIONARITYHACANALYSIS Run V2.2 diagnostics without changing V1.

if nargin < 1 || isempty(cfg)
    cfg = macro.v2.projectConfig();
end
if ~isfield(cfg,"InferenceProtocol")
    error("macro:v2:runStationarityHACAnalysis:InvalidConfiguration", ...
        "V2 configuration must contain InferenceProtocol.");
end
macro.v2.ensureOutputDirectories(cfg);
protocol = cfg.InferenceProtocol;

v1DataPath = fullfile(cfg.V1DataDir,"Macroeconomic_Data_Quarterly.csv");
if ~isfile(v1DataPath)
    error("macro:v2:runStationarityHACAnalysis:MissingV1Data", ...
        "The read-only V1 quarterly dataset is unavailable.");
end
data = readtable(v1DataPath,TextType="string");
data = macro.validateQuarterlyData(data);

specifications = protocol.Specifications;
numSeries = height(specifications);
Series = specifications.Variable;
SourceVariable = specifications.SourceVariable;
Transformation = specifications.Transformation;
Role = specifications.Role;
Observations = zeros(numSeries,1);
ADFModel = specifications.ADFModel;
ADFSelectedLag = zeros(numSeries,1);
ADFMaximumLag = zeros(numSeries,1);
ADFStatistic = zeros(numSeries,1);
ADFCriticalValue = zeros(numSeries,1);
ADFPValue = zeros(numSeries,1);
ADFRejectUnitRoot = false(numSeries,1);
ADFValid = false(numSeries,1);
ADFDiagnostic = strings(numSeries,1);
KPSSTrend = specifications.KPSSTrend;
KPSSBandwidth = zeros(numSeries,1);
KPSSStatistic = zeros(numSeries,1);
KPSSCriticalValue = zeros(numSeries,1);
KPSSPValue = zeros(numSeries,1);
KPSSRejectStationarity = false(numSeries,1);
Conclusion = strings(numSeries,1);

for seriesIndex = 1:numSeries
    values = data.(SourceVariable(seriesIndex));
    if startsWith(Transformation(seriesIndex),"First difference")
        values = diff(values);
    end
    diagnostic = macro.v2.stationarityDiagnostics( ...
        values,Series(seriesIndex), ...
        ADFModel=ADFModel(seriesIndex), ...
        KPSSTrend=KPSSTrend(seriesIndex), ...
        Alpha=protocol.Alpha, ...
        MaximumLagCap=protocol.ADFMaximumLagCap);
    Observations(seriesIndex) = diagnostic.Observations;
    ADFSelectedLag(seriesIndex) = diagnostic.ADFSelectedLag;
    ADFMaximumLag(seriesIndex) = diagnostic.ADFMaximumLag;
    ADFStatistic(seriesIndex) = diagnostic.ADFStatistic;
    ADFCriticalValue(seriesIndex) = diagnostic.ADFCriticalValue;
    ADFPValue(seriesIndex) = diagnostic.ADFPValue;
    ADFRejectUnitRoot(seriesIndex) = diagnostic.ADFRejectUnitRoot;
    ADFValid(seriesIndex) = diagnostic.ADFValid;
    ADFDiagnostic(seriesIndex) = diagnostic.ADFDiagnostic;
    KPSSBandwidth(seriesIndex) = diagnostic.KPSSBandwidth;
    KPSSStatistic(seriesIndex) = diagnostic.KPSSStatistic;
    KPSSCriticalValue(seriesIndex) = diagnostic.KPSSCriticalValue;
    KPSSPValue(seriesIndex) = diagnostic.KPSSPValue;
    KPSSRejectStationarity(seriesIndex) = ...
        diagnostic.KPSSRejectStationarity;
    Conclusion(seriesIndex) = diagnostic.Conclusion;
end

stationarity = table(Series,SourceVariable,Transformation,Role, ...
    Observations,ADFModel,ADFSelectedLag,ADFMaximumLag,ADFStatistic, ...
    ADFCriticalValue,ADFPValue,ADFRejectUnitRoot,ADFValid,ADFDiagnostic, ...
    KPSSTrend, ...
    KPSSBandwidth,KPSSStatistic,KPSSCriticalValue,KPSSPValue, ...
    KPSSRejectStationarity,Conclusion);
decisions = transformationDecisions(stationarity);

Y = data.GDPGrowth;
X = [ones(height(data),1),data.Inflation, ...
    data.Unemployment,data.InterestRate];
classical = macro.estimateOLS(X,Y,CovarianceSolver="inverse");
hac = macro.v2.neweyWestCovariance(X,Y);
Variable = ["Intercept";"Inflation";"Unemployment";"Interest Rate"];
Coefficient = classical.Coefficients;
ClassicalStandardError = classical.StandardErrors;
HACStandardError = hac.StandardErrors;
ClassicalTStatistic = classical.TStatistics;
HACTStatistic = hac.TStatistics;
ClassicalApproxPValue = classical.ApproxPValues;
HACApproxPValue = hac.ApproxPValues;
StandardErrorChangePercent = 100*(HACStandardError./ ...
    ClassicalStandardError-1);
HACBandwidth = repmat(hac.Bandwidth,numel(Variable),1);
inference = table(Variable,Coefficient,ClassicalStandardError, ...
    HACStandardError,ClassicalTStatistic,HACTStatistic, ...
    ClassicalApproxPValue,HACApproxPValue, ...
    StandardErrorChangePercent,HACBandwidth);

stationarityPath = fullfile(cfg.ResultsDir, ...
    "Stationarity_Test_Results.csv");
decisionsPath = fullfile(cfg.ResultsDir, ...
    "Transformation_Decisions.csv");
inferencePath = fullfile(cfg.ResultsDir, ...
    "Classical_vs_HAC_Inference.csv");
writetable(stationarity,stationarityPath);
writetable(decisions,decisionsPath);
writetable(inference,inferencePath);

figureFiles = strings(0,1);
if cfg.GenerateFigures
    figureFiles = createFigures(cfg,stationarity,inference);
end

output = struct( ...
    "StationarityResults",stationarity, ...
    "TransformationDecisions",decisions, ...
    "InferenceComparison",inference, ...
    "ClassicalModel",classical, ...
    "HACModel",hac, ...
    "ResultFiles",[stationarityPath;decisionsPath;inferencePath], ...
    "FigureFiles",figureFiles);
end

function decisions = transformationDecisions(stationarity)
Variable = ["RealGDP";"CPI";"Unemployment";"InterestRate"];
V1BaselineRepresentation = ["GDPGrowth";"Inflation"; ...
    "Level";"Level"];
V2DiagnosticRepresentation = ["GDPGrowth";"Inflation"; ...
    "Level and first difference";"Level and first difference"];
Decision = [ ...
    "Retain V1 annualized log-growth transformation"; ...
    "Retain V1 annualized log-growth transformation"; ...
    "Do not change baseline automatically; report ambiguity and difference candidate"; ...
    "Do not change baseline automatically; report ambiguity and difference candidate"];
LevelConclusion = strings(4,1);
CandidateConclusion = strings(4,1);

levelNames = ["RealGDP";"CPI";"Unemployment";"InterestRate"];
candidateNames = ["GDPGrowth";"Inflation"; ...
    "DeltaUnemployment";"DeltaInterestRate"];
for index = 1:4
    LevelConclusion(index) = stationarity.Conclusion( ...
        stationarity.Series == levelNames(index));
    CandidateConclusion(index) = stationarity.Conclusion( ...
        stationarity.Series == candidateNames(index));
end
decisions = table(Variable,V1BaselineRepresentation, ...
    V2DiagnosticRepresentation,LevelConclusion,CandidateConclusion,Decision);
end

function files = createFigures(cfg,stationarity,inference)
fig1 = figure("Visible","off","Position",[100 100 1200 650]);
tiledlayout(2,1);
nexttile;
bar(categorical(stationarity.Series),stationarity.ADFPValue);
yline(0.05,"--");
ylabel("ADF p-value");
title("V2 Stationarity Diagnostics: ADF");
grid on;
nexttile;
bar(categorical(stationarity.Series),stationarity.KPSSPValue);
yline(0.05,"--");
ylabel("KPSS p-value");
title("V2 Stationarity Diagnostics: KPSS");
grid on;
stationarityFigure = fullfile(cfg.FiguresDir, ...
    "V2_Stationarity_Diagnostics.png");
exportgraphics(fig1,stationarityFigure,"Resolution",200);
close(fig1);

fig2 = figure("Visible","off","Position",[100 100 1000 600]);
bar(categorical(inference.Variable),[inference.ClassicalStandardError, ...
    inference.HACStandardError]);
ylabel("Standard error");
title("V2 Classical versus HAC Inference");
legend("Classical","HAC/Newey-West","Location","best");
grid on;
inferenceFigure = fullfile(cfg.FiguresDir, ...
    "V2_Classical_vs_HAC_Standard_Errors.png");
exportgraphics(fig2,inferenceFigure,"Resolution",200);
close(fig2);
files = [stationarityFigure;inferenceFigure];
end
