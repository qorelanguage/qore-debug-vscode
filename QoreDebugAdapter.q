#!/usr/bin/env qore
# -*- mode: qore; indent-tabs-mode: nil -*-

/*  QoreDebugAdapter.q Copyright 2017 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

#
# QDA - Qore (VSCode) Debug Adapter
#

%require-types
%enable-all-warnings
%new-style
%strict-args

%requires qore >= 0.8.13

%requires json

%requires ./qlib/AbstractDebugConnection.qm
%requires ./qlib/DebugEventListener.qm
%requires ./qlib/Event.qm
%requires ./qlib/LocalDebugConnection.qm
%requires ./qlib/Messenger.qm
%requires ./qlib/RequestValidator.qm
%requires ./qlib/Response.qm

%include ./qlib/DebugAdapterCapabilities.q

%exec-class QoreDebugAdapter

class QoreDebugAdapter inherits DebugEventListener {
    private {
        #! Whether QDA has been initialized ("initialize" request received).
        bool initialized = False;

        #! Whether configuration has been done.
        bool configurationDone = False;

        # Whether the main loop should still run (or QDA should quit).
        bool running = True;

        # Exit code to use when quitting
        int exitCode = 0;

        #! Whether to log QDA operations.
        bool logging = PlatformOS != "Windows";

        #! Whether to append to the log file.
        bool appendToLog = True;

        #! Whether the log file can be opened.
        bool canOpenLog = False;

        #! Logging verbosity. Only messages with this level or lower will be logged.
        int logVerbosity = 2;

        #! Log file
        string logFile;

        #! Map of debug request commands -> handler methods
        hash<string, code> requestMap;

        #! "initialize" request arguments
        *hash initArgs;

        #! Connection to the debugger
        *AbstractDebugConnection debugger;
    }

    public constructor() {
        logFile = getDefaultLogFilePath();
        prepareLogFile(logFile);
        initRequestMap();
        set_return_value(main());
    }

    public destructor() {
        quitDebugger();
        log(0, "exiting gracefully");
    }

    private:internal string getDefaultLogFilePath() {
        if (PlatformOS == "Windows")
            return getenv("APPDATA") + DirSep + "QoreDebugAdapter" + DirSep + "qda.log";
        else
            return getenv("HOME") + DirSep + ".qoredebugadapter.log";
    }

    private:internal prepareLogFile(string logFilePath, bool force = False) {
        if (logging || force) {
            # prepare the log directory
            Dir d();
            if (!d.chdir(dirname(logFilePath))) {
                try {
                    d.create(0755);
                }
                catch (e) {
                    canOpenLog = False;
                    return;
                }
            }

            # check if the log file can be opened and truncate it if appending is turned off
            try {
                FileOutputStream fos(logFile, appendToLog);
                fos.close();
                canOpenLog = True;
            }
            catch (e) {
                canOpenLog = False;
            }
        }
    }

    private:internal log(int verbosity, string fmt) {
        if (logging && canOpenLog && verbosity <= logVerbosity) {
            string str = sprintf("%s: ", format_date("YYYY-MM-DD HH:mm:SS", now()));
            string msg = vsprintf(str + fmt + "\n", argv);
            FileOutputStream fos(logFile, True);
            fos.write(binary(msg));
            fos.close();
        }
    }

    private:internal log(int verbosity, string fmt, softlist l) {
        if (logging && canOpenLog && verbosity <= logVerbosity) {
            string str = sprintf("%s: ", format_date("YYYY-MM-DD HH:mm:SS", now()));
            string msg = vsprintf(str + fmt + "\n", l);
            FileOutputStream fos(logFile, True);
            fos.write(binary(msg));
            fos.close();
        }
    }

    private:internal error(string fmt) {
        log(0, "ERROR: " + fmt, argv);
        stderr.vprintf("ERROR: " + fmt + "\n", argv);
        exit(1);
    }

    private:internal initRequestMap() {
        requestMap = cast<hash<string, code>>({
            # General methods
            "initialize": \req_initialize(),
            "launch": \req_launch(),
            "attach": \req_attach(),
            "restart": \req_restart(),
            "disconnect": \req_disconnect(),

            # Configuration requests
            "configurationDone": \req_configurationDone(),
            "setBreakpoints": \req_setBreakpoints(),
            "setFunctionBreakpoints": \req_setFunctionBreakpoints(),
            "setExceptionBreakpoints": \req_setExceptionBreakpoints(),

            # Control requests
            "continue": \req_continue(),
            "next": \req_next(),
            "pause": \req_pause(),
            "stepIn": \req_stepIn(),
            "stepOut": \req_stepOut(),
            "stepBack": \req_stepBack(),
            "setVariable": \req_setVariable(),
            "reverseContinue": \req_reverseContinue(),
            "restartFrame": \req_restartFrame(),
            "goto": \req_goto(),

            # Info requests
            "stackTrace": \req_stackTrace(),
            "scopes": \req_scopes(),
            "variables": \req_variables(),
            "source": \req_source(),
            "threads": \req_threads(),
            "modules": \req_modules(),
            "evaluate": \req_evaluate(),
            "stepInTargets": \req_stepInTargets(),
            "gotoTargets": \req_gotoTargets(),
            "completions": \req_completions(),
            "exceptionInfo": \req_exceptionInfo(),
        });
    }

    private:internal *string validateRequest(hash request) {
        if (!request.hasKey("seq"))
            return ErrorResponse::missingAttr(request, "seq");
        if (!request.hasKey("type"))
            return ErrorResponse::missingAttr(request, "type");
        if (!request.hasKey("command"))
            return ErrorResponse::missingAttr(request, "command");

        int seqType = request.seq.typeCode();
        if (seqType != NT_INT && seqType != NT_FLOAT && seqType != NT_NUMBER)
            return ErrorResponse::invalidAttrType(request, "seq");
        if (request.type.typeCode() != NT_STRING)
            return ErrorResponse::invalidAttrType(request, "type");
        if (request.command.typeCode() != NT_STRING)
            return ErrorResponse::invalidAttrType(request, "command");
        return NOTHING;
    }


    #=========================
    # Internal debugger stuff
    #=========================

    private:internal *hash startDebugger(hash<DebugParams> params) {
        try {
            # TODO - depending on the parameters, start the appropriate debug connection
            debugger = new LocalDebugConnection(self, params);
        }
        catch (hash ex) {
            return ex;
        }
        return NOTHING;
    }

    private:internal *hash quitDebugger(bool terminate = True) {
        try {
            if (debugger)
                debugger.disconnect(terminate);
            delete debugger;
        }
        catch (hash ex) {
            return ex;
        }
        return NOTHING;
    }


    #=================
    # Main logic
    #=================

    public int main() {
        while (running) {
            # read JSON-RPC request
            log(2, "waiting for request");
            hash received = Messenger::receive();
            log(2, "received smtg");
            if (received.error)
                error(received.error);

            # handle the request
            log(2, "handling request");
            softlist responses = handleRequest(received.msg);
            log(2, "handling finished");

            # send back responses if any
            if (responses.size()) {
                map Messenger::send($1), responses;
                log(2, "response(s) sent");
            }
        }

        return exitCode;
    }

    private softlist handleRequest(string msg) {
        # parse the request
        any request = parse_json(msg);
        log(2, "req: %N", request);

        # validate request
        if (request.typeCode() != NT_HASH)
            return Response::error(request, NOTHING, "invalid request datatype");

        *string validation = validateRequest(request);
        if (validation)
            return validation;

        # check that QDA has been initialized
        if (!initialized && request.command != "initialize")
            return ErrorResponse::notInitialized(request);

        # check that a request handler exists
        if (!requestMap.hasKey(request.command))
            return ErrorResponse::handlerNotFound(request);

        # call appropriate request handler method
        auto response = requestMap{request.command}(request);
        log(2, "resp: %N", response);

        # check for "initialize" request and send "initialized" event
        if (request.command == "initialize")
            return (response, Event::initialized());

        return response;
    }

    public handleDebugEvent(auto event) {
        # TODO
        log(2, "dbg evt: %N", event);
    }


    #==================
    # General requests
    #==================

    #! "initialize" request handler
    private:internal *string req_initialize(hash request) {
        log(0, "initialized request received");
        # validate request
        *string validation = RequestValidator::initialize(request);
        if (validation)
            return validation;

        # save arguments etc.
        initArgs = request.arguments;
        initialized = True;
        log(0, "initialization done!");
        return Response::ok(request, DebugAdapterCapabilities);
    }

    #! "launch" request handler
    private:internal auto req_launch(hash request) {
        log(0, "launch request received");
        # validate request
        *string validation = RequestValidator::launch(request);
        if (validation)
            return validation;

        # prepare debug params
        hash<DebugParams> params(cast<hash<DebugParams>>({
            "programPath": request.arguments.program,
            "stopOnEntry": request.arguments.stopOnEntry
        }));

        # create debug connection
        *hash result = startDebugger(params);
        if (result) {
            stderr.printf("Error starting debugger:\n%N\n", result);
            return Response::error(request, result, "Error starting debugger");
        }

        # try launching
        try {
            result = debugger.launch();
        }
        catch (hash<ExceptionInfo> ex) {
            stderr.printf("Error during program launch:\n%N\n", ex);
            return Response::error(request, ex, "Error during program launch");
        }

        # return result if possible
        if (result) {
            if (result.reason == "entry")
                return (Response::ok(request), Event::make("stopped", result));
            stderr.printf("Error during program launch - unknown result value:\n%N\n", result);
            return Response::error(request, result, "Error during program launch - unknown result value");
        }

        return Response::ok(request);
    }

    #! "attach" request handler
    private:internal *string req_attach(hash request) {
        log(0, "attach request received");
        # TODO
        return NOTHING;
    }

    #! "restart" request handler
    private:internal *string req_restart(hash request) {
        log(0, "restart request received");
        # TODO
        return NOTHING;
    }

    #! "disconnect" request handler
    private:internal *string req_disconnect(hash request) {
        log(0, "disconnect request received");
        running = False;
        *hash result = quitDebugger();
        log(0, "tried disconnecting: %N", result);
        if (result)
            return Response::error(request, result, "error disconnecting debugger");

        return Response::ok(request);
    }


    #========================
    # Configuration requests
    #========================

    #! "configurationDone" request handler
    private:internal *string req_configurationDone(hash request) {
        configurationDone = True;
        log(0, "configuration done!");
        return Response::ok(request);
    }

    #! "setBreakpoints" request handler
    private:internal *string req_setBreakpoints(hash request) {
        # validate request
        *string validation = RequestValidator::setBreakpoints(request);
        if (validation)
            return validation;
        # TODO
        return Response::ok(request);
    }

    #! "setFunctionBreakpoints" request handler
    private:internal *string req_setFunctionBreakpoints(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "setExceptionBreakpoints" request handler
    private:internal *string req_setExceptionBreakpoints(hash request) {
        return ErrorResponse::notSupported(request);
    }


    #==================
    # Control requests
    #==================

    #! "continue" request handler
    private:internal *string req_continue(hash request) {
        # TODO
        if (!configurationDone)
            ErrorResponse::configurationNotDone(request);

        # validate request
        *string validation = RequestValidator::continueReq(request);
        if (validation)
            return validation;

        # call the debugger
        try {
            debugger.continue_(request.arguments.threadId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, {"allThreadsContinued": False});
    }

    #! "next" request handler
    private:internal *string req_next(hash request) {
        # validate request
        *string validation = RequestValidator::next(request);
        if (validation)
            return validation;

        # call the debugger
        try {
            debugger.next(request.arguments.threadId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request);
    }

    #! "pause" request handler
    private:internal *string req_pause(hash request) {
        # validate request
        *string validation = RequestValidator::pause(request);
        if (validation)
            return validation;

        # call the debugger
        try {
            debugger.pause(request.arguments.threadId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request);
    }

    #! "stepIn" request handler
    private:internal *string req_stepIn(hash request) {
        # validate request
        *string validation = RequestValidator::stepIn(request);
        if (validation)
            return validation;

        # call the debugger
        try {
            debugger.stepIn(request.arguments.threadId, request.arguments.targetId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request);
    }

    #! "stepOut" request handler
    private:internal *string req_stepOut(hash request) {
        # validate request
        *string validation = RequestValidator::stepOut(request);
        if (validation)
            return validation;

        # call the debugger
        try {
            debugger.stepOut(request.arguments.threadId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request);
    }

    #! "stepBack" request handler
    private:internal *string req_stepBack(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "setVariable" request handler
    private:internal *string req_setVariable(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "reverseContinue" request handler
    private:internal *string req_reverseContinue(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "restartFrame" request handler
    private:internal *string req_restartFrame(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "goto" request handler
    private:internal *string req_goto(hash request) {
        return ErrorResponse::notSupported(request);
    }


    #===============
    # Info requests
    #===============

    #! "stackTrace" request handler
    private:internal *string req_stackTrace(hash request) {
        # validate request
        *string validation = RequestValidator::stackTrace(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.stackTrace(
                request.arguments.threadId,
                request.arguments.startFrame,
                request.arguments.levels,
                request.arguments.format
            );
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "scopes" request handler
    private:internal *string req_scopes(hash request) {
        # validate request
        *string validation = RequestValidator::scopes(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.scopes(request.arguments.frameId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "variables" request handler
    private:internal *string req_variables(hash request) {
        # validate request
        *string validation = RequestValidator::variables(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.variables(
                request.arguments.variablesReference,
                request.arguments.filter,
                request.arguments.start,
                request.arguments.count,
                request.arguments.format
            );
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "source" request handler
    private:internal *string req_source(hash request) {
        # validate request
        *string validation = RequestValidator::source(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.source(
                request.arguments.sourceReference,
                request.arguments.source
            );
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "threads" request handler
    private:internal *string req_threads(hash request) {
        # call the debugger
        *list threads;
        try {
            threads = debugger.threads();
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, {"threads": threads});
    }

    #! "modules" request handler
    private:internal *string req_modules(hash request) {
        # validate request
        *string validation = RequestValidator::modules(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.modules(
                request.arguments.startModule,
                request.arguments.moduleCount
            );
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "evaluate" request handler
    private:internal *string req_evaluate(hash request) {
        # validate request
        *string validation = RequestValidator::evaluate(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.evaluate(
                request.arguments.expression,
                request.arguments.frameId,
                request.arguments.context,
                request.arguments.format
            );
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }

    #! "stepInTargets" request handler
    private:internal *string req_stepInTargets(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "gotoTargets" request handler
    private:internal *string req_gotoTargets(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "completions" request handler
    private:internal *string req_completions(hash request) {
        return ErrorResponse::notSupported(request);
    }

    #! "exceptionInfo" request handler
    private:internal *string req_exceptionInfo(hash request) {
        # validate request
        *string validation = RequestValidator::exceptionInfo(request);
        if (validation)
            return validation;

        # call the debugger
        hash body;
        try {
            body = debugger.exceptionInfo(request.arguments.threadId);
        }
        catch(ex) {
            return ErrorResponse::commandFailed(request, ex);
        }

        return Response::ok(request, body);
    }
}
