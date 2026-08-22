function panel = readVintagePanel(filePath)
%READVINTAGEPANEL Read and validate the canonical V2 vintage-panel schema.

arguments
    filePath (1,1) string
end

if ~isfile(filePath)
    error("macro:v2:readVintagePanel:MissingFile", ...
        "Vintage-panel file does not exist: %s",filePath);
end

panel = readtable(filePath,"TextType","string");
dateVariables = ["ObservationDate","RealtimeStart","RealtimeEnd"];
for variableName = dateVariables
    if ismember(variableName,string(panel.Properties.VariableNames)) && ...
            ~isdatetime(panel.(variableName))
        panel.(variableName) = datetime(panel.(variableName), ...
            "InputFormat","yyyy-MM-dd");
    end
end
panel = macro.v2.validateVintagePanel(panel);
end
