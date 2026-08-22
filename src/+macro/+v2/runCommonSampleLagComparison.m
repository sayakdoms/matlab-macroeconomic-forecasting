function output = runCommonSampleLagComparison(cfg)
%RUNCOMMONSAMPLELAGCOMPARISON Compare lags 0-4 on one response sample.
%   V1's committed varying-sample comparison remains a read-only baseline.
%   The V2 criteria are descriptive/in-sample and are not a forecasting
%   model-selection rule.

if nargin < 1 || isempty(cfg)
    cfg = macro.v2.projectConfig();
end
if ~isfield(cfg,"LagComparisonProtocol")
    error("macro:v2:runCommonSampleLagComparison:InvalidConfiguration", ...
        "V2 configuration must contain LagComparisonProtocol.");
end
macro.v2.ensureOutputDirectories(cfg);
protocol = cfg.LagComparisonProtocol;

dataPath = fullfile(cfg.V1DataDir,"Macroeconomic_Data_Quarterly.csv");
baselinePath = fullfile(cfg.V1ResultsDir,"Lag_Model_Comparison.csv");
if ~isfile(dataPath) || ~isfile(baselinePath)
    error("macro:v2:runCommonSampleLagComparison:MissingV1Baseline", ...
        "The read-only V1 quarterly data and lag baseline are required.");
end
data = macro.validateQuarterlyData(readtable(dataPath,TextType="string"));
v1 = readtable(baselinePath,TextType="string");

candidateLags = protocol.CandidateLags(:);
numModels = numel(candidateLags);
Model = "Lag " + string(candidateLags);
Lag = candidateLags;
Observations = zeros(numModels,1);
RSquared = zeros(numModels,1);
AdjustedRSquared = zeros(numModels,1);
RMSE = zeros(numModels,1);
AIC = zeros(numModels,1);
BIC = zeros(numModels,1);
FStatistic = zeros(numModels,1);
coefficients = zeros(numModels,4);
designs = cell(numModels,1);
models = cell(numModels,1);

for modelIndex = 1:numModels
    design = macro.v2.buildCommonSampleLagDesign(data, ...
        candidateLags(modelIndex),MaximumLag=protocol.MaximumLag);
    model = macro.estimateOLS(design.X,design.Y, ...
        CovarianceSolver="inverse");
    designs{modelIndex} = design;
    models{modelIndex} = model;
    Observations(modelIndex) = model.Observations;
    RSquared(modelIndex) = model.RSquared;
    AdjustedRSquared(modelIndex) = model.AdjustedRSquared;
    RMSE(modelIndex) = model.RMSE;
    AIC(modelIndex) = model.AIC;
    BIC(modelIndex) = model.BIC;
    FStatistic(modelIndex) = model.FStatistic;
    coefficients(modelIndex,:) = model.Coefficients';
end

Interpretation = repmat(protocol.Interpretation,numModels,1);
commonComparison = table(Model,Lag,Observations,RSquared, ...
    AdjustedRSquared,RMSE,AIC,BIC,FStatistic,Interpretation);

Variable = repmat(["Intercept";"Inflation";"Unemployment"; ...
    "InterestRate"],numModels,1);
coefficientModel = repelem(Model,4);
coefficientLag = repelem(Lag,4);
Coefficient = reshape(coefficients',[],1);
coefficientInterpretation = repmat(protocol.Interpretation, ...
    numel(Coefficient),1);
coefficientTable = table(coefficientModel,coefficientLag,Variable, ...
    Coefficient,coefficientInterpretation,VariableNames={ ...
    'Model','Lag','Variable','Coefficient','Interpretation'});

if height(v1) ~= numModels || any(string(v1.Model) ~= Model)
    error("macro:v2:runCommonSampleLagComparison:V1SchemaMismatch", ...
        "The committed V1 lag-comparison rows do not match Lag 0 through Lag 4.");
end
V1SampleDefinition = repmat( ...
    "V1 varying sample (descriptive/in-sample)",numModels,1);
V2SampleDefinition = repmat( ...
    "V2 common max-lag sample (descriptive/in-sample)",numModels,1);
combined = table(Model,Lag,V1SampleDefinition,v1.Observations, ...
    v1.AdjustedRSquared,v1.AIC,v1.BIC,v1.RMSE,V2SampleDefinition, ...
    Observations,AdjustedRSquared,AIC,BIC,RMSE,Interpretation, ...
    VariableNames={'Model','Lag','V1SampleDefinition','V1Observations', ...
    'V1AdjustedRSquared','V1AIC','V1BIC','V1RMSE', ...
    'V2SampleDefinition','V2Observations','V2AdjustedRSquared', ...
    'V2AIC','V2BIC','V2RMSE','Interpretation'});

[~,adjIndex] = max(AdjustedRSquared);
[~,aicIndex] = min(AIC);
[~,bicIndex] = min(BIC);
[~,rmseIndex] = min(RMSE);
rankingIndices = [adjIndex;aicIndex;bicIndex;rmseIndex];
Criterion = ["Adjusted R-squared";"AIC";"BIC";"RMSE"];
PreferredDirection = ["Maximum";"Minimum";"Minimum";"Minimum"];
PreferredModel = Model(rankingIndices);
PreferredLag = Lag(rankingIndices);
Value = [AdjustedRSquared(adjIndex);AIC(aicIndex); ...
    BIC(bicIndex);RMSE(rmseIndex)];
rankingInterpretation = repmat(protocol.Interpretation,4,1);
ranking = table(Criterion,PreferredDirection,PreferredModel, ...
    PreferredLag,Value,rankingInterpretation,VariableNames={ ...
    'Criterion','PreferredDirection','PreferredModel','PreferredLag', ...
    'Value','Interpretation'});

combinedPath = fullfile(cfg.ResultsDir, ...
    "V1_Varying_vs_V2_Common_Sample_Lags.csv");
coefficientPath = fullfile(cfg.ResultsDir, ...
    "Common_Sample_Lag_Coefficients.csv");
rankingPath = fullfile(cfg.ResultsDir, ...
    "Common_Sample_Lag_Ranking.csv");
writetable(combined,combinedPath);
writetable(coefficientTable,coefficientPath);
writetable(ranking,rankingPath);

figureFiles = strings(0,1);
if cfg.GenerateFigures
    figureFiles = createFigures(cfg,commonComparison);
end

output = struct( ...
    "CommonComparison",commonComparison, ...
    "BaselineComparison",v1, ...
    "CombinedComparison",combined, ...
    "Coefficients",coefficientTable, ...
    "Ranking",ranking, ...
    "Designs",{designs}, ...
    "Models",{models}, ...
    "V1SelectedLag",protocol.V1SelectedLag, ...
    "ResultFiles",[combinedPath;coefficientPath;rankingPath], ...
    "FigureFiles",figureFiles);
end

function files = createFigures(cfg,comparison)
fig1 = figure("Visible","off","Position",[100 100 1100 550]);
yyaxis left;
plot(comparison.Lag,comparison.AdjustedRSquared,"-o", ...
    "LineWidth",1.5);
ylabel("Adjusted R-squared");
yyaxis right;
plot(comparison.Lag,comparison.RMSE,"-s","LineWidth",1.5);
ylabel("In-sample RMSE");
xlabel("Candidate lag (quarters)");
title("V2 Common-Sample Descriptive Fit");
grid on;
fitPath = fullfile(cfg.FiguresDir,"V2_Common_Sample_Lag_Fit.png");
exportgraphics(fig1,fitPath,"Resolution",200);
close(fig1);

fig2 = figure("Visible","off","Position",[100 100 1000 550]);
plot(comparison.Lag,comparison.AIC,"-o","LineWidth",1.5);
hold on;
plot(comparison.Lag,comparison.BIC,"-s","LineWidth",1.5);
xlabel("Candidate lag (quarters)");
ylabel("Information criterion");
title("V2 Common-Sample Information Criteria");
legend("AIC","BIC","Location","best");
grid on;
criteriaPath = fullfile(cfg.FiguresDir, ...
    "V2_Common_Sample_Information_Criteria.png");
exportgraphics(fig2,criteriaPath,"Resolution",200);
close(fig2);
files = [fitPath;criteriaPath];
end
