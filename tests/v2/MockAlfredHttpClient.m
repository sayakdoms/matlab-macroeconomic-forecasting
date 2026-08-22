classdef MockAlfredHttpClient < handle
    %MOCKALFREDHTTPCLIENT Deterministic in-memory ALFRED HTTP test double.

    properties
        Responses cell = {}
        CallCount (1,1) double = 0
        Requests cell = {}
        Endpoints string = strings(0,1)
        ErrorMessage (1,1) string = ""
    end

    methods
        function obj = MockAlfredHttpClient(responses,errorMessage)
            if nargin >= 1
                obj.Responses = responses;
            end
            if nargin >= 2
                obj.ErrorMessage = string(errorMessage);
            end
        end

        function response = request(obj,endpoint,request)
            obj.CallCount = obj.CallCount + 1;
            obj.Endpoints(end+1,1) = string(endpoint);
            obj.Requests{end+1,1} = request;
            if strlength(obj.ErrorMessage) > 0
                error("tests:v2:MockAlfredHttpClient:InjectedError","%s", ...
                    obj.ErrorMessage);
            end
            if obj.CallCount > numel(obj.Responses)
                error("tests:v2:MockAlfredHttpClient:NoResponse", ...
                    "No mock response was configured for call %d.", ...
                    obj.CallCount);
            end
            response = obj.Responses{obj.CallCount};
        end
    end
end
