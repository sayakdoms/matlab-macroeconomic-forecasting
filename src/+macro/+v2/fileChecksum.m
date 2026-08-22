function checksum = fileChecksum(filePath)
%FILECHECKSUM Return a deterministic SHA-256 checksum of file bytes.

arguments
    filePath (1,1) string
end

if ~isfile(filePath)
    error("macro:v2:fileChecksum:MissingFile", ...
        "Cannot checksum missing file: %s",filePath);
end
fileID = fopen(filePath,"rb");
if fileID < 0
    error("macro:v2:fileChecksum:ReadFailed", ...
        "Cannot open file for checksum: %s",filePath);
end
cleanup = onCleanup(@() fclose(fileID));
bytes = fread(fileID,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
signedBytes = int8(digest.digest());
hashBytes = typecast(signedBytes,"uint8");
checksum = lower(string(reshape(dec2hex(hashBytes,2).',1,[])));
end
