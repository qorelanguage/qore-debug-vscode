%new-style

string topLevelString = "TOPLEVEL";
int topLevelInt = 1;
bool topLevelBool = True;

our globalCode = <ABCD>;
our globalDate = now();
our globalList = (1,2,3);
our globalHash = ("A":1, "B": "BB");

code myClosure = int sub(string param1, string param2) {
    string closureParam = "CLOSURE PARAM";
    int iii = 23;
    printf("myClosure(%y,%y): %y, %y\n", param1, param2, closureParam, iii);
    return iii;
};

{
    string topLevelBlock1 = "TOPLEVELBLOCK1";
    if (topLevelBlock1) {
        string topLevelBlock2 = "TOPLEVELBLOCK2";
        topLevelBlock1 = "ASSIGN IN TOPLEVELBLOCK2";
        topLevelBlock2 = "";
        myClosure("BLOCK2", topLevelBlock2);
    }

    myClosure("BLOCK1", topLevelBlock1);
}
myClosure("TOPLEVEL", topLevelString);


printf("finished\n");
return 0;
