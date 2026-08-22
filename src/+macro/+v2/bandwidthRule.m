function bandwidth = bandwidthRule(numObservations)
%BANDWIDTHRULE Deterministic KPSS/HAC Newey-West bandwidth rule.

arguments
    numObservations (1,1) double {mustBeInteger,mustBePositive}
end

bandwidth = min(numObservations-1, ...
    floor(4*(numObservations/100)^(2/9)));
end
