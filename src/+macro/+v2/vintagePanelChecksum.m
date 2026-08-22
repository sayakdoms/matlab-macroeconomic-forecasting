function checksum = vintagePanelChecksum(panel)
%VINTAGEPANELCHECKSUM Return a deterministic SHA-256 semantic panel hash.

arguments
    panel table
end

panel = macro.v2.validateVintagePanel(panel);
lines = strings(height(panel),1);
for rowIndex = 1:height(panel)
    lines(rowIndex) = strjoin([ ...
        panel.SeriesID(rowIndex), ...
        string(panel.ObservationDate(rowIndex),"yyyy-MM-dd"), ...
        string(panel.RealtimeStart(rowIndex),"yyyy-MM-dd"), ...
        string(panel.RealtimeEnd(rowIndex),"yyyy-MM-dd"), ...
        string(compose("%.17g",panel.Value(rowIndex)))],",");
end
canonicalText = join(lines,newline) + newline;

digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(unicode2native(char(canonicalText),"UTF-8"));
signedBytes = int8(digest.digest());
bytes = typecast(signedBytes,"uint8");
checksum = lower(string(reshape(dec2hex(bytes,2).',1,[])));
end
