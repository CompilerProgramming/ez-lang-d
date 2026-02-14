module ezlang.errors;

class CompilerException : Exception {
    int _line;

    this(string msg, int line) {
        super(msg);
        _line = line;
    }
    override string toString() const {
        import std.format : format;
        return format("Compilation error at %s: %s", _line, msg);
    }
}
