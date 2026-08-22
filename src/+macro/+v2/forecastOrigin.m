function origin = forecastOrigin(targetQuarterStart,ruleName,protocol)
%FORECASTORIGIN Resolve a centralized V2 forecast-origin convention.

arguments
    targetQuarterStart (1,1) datetime
    ruleName (1,1) string
    protocol (1,1) struct = macro.v2.forecastProtocol()
end

if isnat(targetQuarterStart) || ...
        targetQuarterStart ~= dateshift(targetQuarterStart,"start","quarter")
    error("macro:v2:forecastOrigin:InvalidTargetQuarter", ...
        "TargetQuarterStart must be a valid first day of a calendar quarter.");
end

rules = protocol.OriginRules;
ruleIndex = find(rules.Name == ruleName,1);
if isempty(ruleIndex)
    error("macro:v2:forecastOrigin:UnknownRule", ...
        "Unknown forecast-origin rule: %s",ruleName);
end

origin = targetQuarterStart + caldays(rules.OffsetDays(ruleIndex));
end
