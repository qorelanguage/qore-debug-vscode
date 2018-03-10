%new-style

%exec-class MyTestClass

class B {
    private {
        string m_privateB = "PRIVATE B";
    }
    public {
        string m_publicB = "PUBLIC B";
    }
    constructor() {
        string METHOD = "B::constructor()";
        printf("%s\n", METHOD);
    }
    destructor() {
        string METHOD = "B::destructor()";
        printf("%s\n", METHOD);
    }
    M() {
        string METHOD = "B::M()";
        printf("%s\n", METHOD);
    }
}
class D inherits B {
    private {
        string m_privateD = "PRIVATE D";
    }
    public {
        string testNotif;
        string m_publicD = "PUBLIC D";
    }
    constructor(): B() {
        string METHOD = "D::constructor()";
        printf("%s\n", METHOD);
    }
    destructor() {
        string METHOD = "D::destructor()";
        printf("%s\n", METHOD);
    }
    M() {
        string METHOD = "D::M()";
        printf("%s\n", METHOD);
        B::M();
    }
    any memberGate(string param) {
        printf("memberGate(%s)\n", param);
        return param;
    }
    any methodGate(string method, string p1) {
        printf("methodGate(%s, %y)\n", method, p1);
    }
    any memberNotification(string param) {
        printf("memeberNotification(%s)\n", param);
    }
    static stat(string param) {
        printf("stat(%y)\n", param);
    }
}

class MyTestClass {
    constructor() {
        D d();
        d.M();
        d.myMethod("myParam");
        d.testNotif = "TESTNOTIF";
        string n = d.myMember;

        D::stat("TEST_STATIC");

        printf("finished\n");
    }

}
