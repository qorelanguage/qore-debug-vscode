%new-style

sub raise() {
    throw "TEST-EXCEPTION", "Test exception";
}
try {
    raise();
} catch(hash<ExceptionInfo> ex) {
    printf("Ex:%y\n", ex);
}

printf("finished\n");

