%new-style

string topLevelString = "TOPLEVEL";
int topLevelInt = 1;
bool topLevelBool = True;

our globalCode = <ABCD>;
our globalDate = now();
our globalList = (1,2,3);
our globalHash = ("A":1, "B": "BB");

{
    string topLevelBlock1 = "TOPLEVELBLOCK1";
    if (topLevelBlock1) {
        string topLevelBlock2 = "TOPLEVELBLOCK2";
        topLevelBlock1 = "ASSIGN IN TOPLEVELBLOCK2";
        topLevelBlock2 = "";
    }

}

sub function2(*string param) {
    for (int for_i=0; for_i<2; for_i++) {
        int while_j = 0;
        while (while_j < for_i) {
            while_j++;
        }
    }
}

int sub function1(int param1) {
    string function1Local = "FUNCTIONLOCAL1";
    {
        string functionBlock = "FUNCTIONBLOCK";
        function2(functionBlock);
    }
    function2(function1Local);
    if (param1 < 0) {
        throw "TEST-EXCEPTION", "Test exception";
    }
    return param1;
}

*int res;
try {
    function2(topLevelString);
    res = function1(1);

    function1(-1);
} catch(hash<ExceptionInfo> ex) {
    printf("Ex:%y\n", ex);
}

printf("finished\n");
return res;
