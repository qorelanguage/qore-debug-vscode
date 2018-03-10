%new-style
%allow-debugger

%requires ../../qore/qlib/DebugProgramControl.qm

#our bool printFlag = False;

class MyDebugProgramControl inherits DebugProgramControl {

    constructor(): DebugProgramControl("test") {
        logger = new DebugLogger();
    }

    onAttach(ProgramControl pgm, reference rs) {
        printf("EVENT: onAttach(%y)\n", rs);
        rs = DebugStep;
    }

    onDetach(ProgramControl pgm, reference rs) {
        printf("EVENT: onDetach(%y)\n", rs);
        rs = DebugDetach;
    }

    onStep(ProgramControl pgm, int blockStatementId, *int statementId, reference flow, reference rs) {
        printf("EVENT: onStep(%y/%y/%y)\n", rs, blockStatementId, statementId);
        rs = DebugStep;
    }

    onFunctionEnter(ProgramControl pgm, int statementId, reference rs) {
        printf("EVENT: onFunctionEnter(%y)\n", rs);
        rs = DebugStep;
    }

    onFunctionExit(ProgramControl pgm, int statementId, reference result, reference rs) {
        printf("EVENT: onFunctionExit(%y)\n", rs);
    }

    onException(ProgramControl pgm, int statementId, hash ex, reference dismiss, reference rs) {
        printf("EVENT: onException(%y)\n", rs);
        rs = DebugStep;   rs = DebugRun;
    }

    onExit(ProgramControl pgm, int statementId, reference result, reference rs) {
        printf("EVENT: onExit(%y)\n", rs);
        rs = DebugStep;
    }

    nothing broadcastDataImpl(auto data) {
    }
    nothing sendDataImpl(hash cx, auto data) {
    }

    testRun(Program pgm) {
        background runAndDetach(pgm);
    }


}

printf("create dpc\n");
MyDebugProgramControl dpc();

const FILENAME = "./test-exception.q";
printf("createProgram: %s\n", FILENAME);
Program pgm = dpc.createProgram(FILENAME, NOTHING, ());

printf("run\n");
dpc.testRun(pgm);

printf("after run\n");

