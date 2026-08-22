function panel = loadCachedVintagePanel(cfg,options)
%LOADCACHEDVINTAGEPANEL Load all four validated series from exact caches.

arguments
    cfg (1,1) struct
    options.RealtimeStart (1,1) datetime = datetime(1776,7,4)
    options.RealtimeEnd (1,1) datetime = dateshift(datetime("today"), ...
        "start","day")
end

retrievals = macro.v2.fetchCurrentAlfredSeries(cfg, ...
    RealtimeStart=options.RealtimeStart,RealtimeEnd=options.RealtimeEnd, ...
    Refresh=false);
panel = retrievals{1}.Panel;
for seriesIndex = 2:numel(retrievals)
    panel = [panel;retrievals{seriesIndex}.Panel]; %#ok<AGROW>
end
panel = macro.v2.validateVintagePanel(panel);
end
