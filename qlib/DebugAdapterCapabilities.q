# -*- mode: qore; indent-tabs-mode: nil -*-

/*  DebugAdapterCapabilities.q Copyright 2017 Qore Technologies, s.r.o.

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


#! Qore (VSCode) Debug Adapter capabilities
const DebugAdapterCapabilities = {
    /** The debug adapter supports the configurationDoneRequest. */
	"supportsConfigurationDoneRequest": "true",

	/** The debug adapter supports function breakpoints. */
	#"supportsFunctionBreakpoints": "false",

	/** The debug adapter supports conditional breakpoints. */
	#"supportsConditionalBreakpoints": "false",

	/** The debug adapter supports breakpoints that break execution
        after a specified number of hits. */
	#"supportsHitConditionalBreakpoints": "false",

	/** The debug adapter supports a (side effect free) evaluate
        request for data hovers. */
	#"supportsEvaluateForHovers": "false",

	/** Available filters or options for the setExceptionBreakpoints request. */
	#"exceptionBreakpointFilters": ExceptionBreakpointsFilter[],

	/** The debug adapter supports stepping back via the stepBack and
        reverseContinue requests. */
	#"supportsStepBack": "false",

	/** The debug adapter supports setting a variable to a value. */
	#"supportsSetVariable": "false",

	/** The debug adapter supports restarting a frame. */
	#"supportsRestartFrame": "false",

	/** The debug adapter supports the gotoTargetsRequest. */
	#"supportsGotoTargetsRequest": "false",

	/** The debug adapter supports the stepInTargetsRequest. */
	#"supportsStepInTargetsRequest": "false",

	/** The debug adapter supports the completionsRequest. */
	#"supportsCompletionsRequest": "false",

	/** The debug adapter supports the modules request. */
	#"supportsModulesRequest": "false",

	/** The set of additional module information exposed by the debug adapter. */
	#"additionalModuleColumns": ColumnDescriptor[],

	/** Checksum algorithms supported by the debug adapter. */
	#"supportedChecksumAlgorithms": ChecksumAlgorithm[],

	/** The debug adapter supports the RestartRequest. In this case
        a client should not implement 'restart' by terminating and
        relaunching the adapter but by calling the RestartRequest. */
	#"supportsRestartRequest": "false",

	/** The debug adapter supports 'exceptionOptions' on the
        setExceptionBreakpoints request. */
	#"supportsExceptionOptions": "false",

	/** The debug adapter supports a 'format' attribute on the
        stackTraceRequest, variablesRequest, and evaluateRequest. */
	"supportsValueFormattingOptions": "false",

	/** The debug adapter supports the exceptionInfo request. */
	#"supportsExceptionInfoRequest": "false",

	/** The debug adapter supports the 'terminateDebuggee' attribute
        on the 'disconnect' request. */
	#"supportTerminateDebuggee": "false",

	/** The debug adapter supports the delayed loading of parts of the stack,
        which requires that both the 'startFrame' and 'levels' arguments and
        the 'totalFrames' result of the 'StackTrace' request are supported. */
	#"supportsDelayedStackTraceLoading": "false",
};
