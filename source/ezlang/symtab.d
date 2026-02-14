module ezlang.symtab;

import ezlang.types;

class Symbol {
    string _name;
    EZType _type;
    this(string name, EZType type) { _name = name; _type = type; }
}

class TypeSymbol : Symbol {
    this(string name, EZType type) {
        super(name, type);
    }
}

class FunctionTypeSymbol : Symbol {
    Object _functionDecl;
    this(string name, EZTypeFunction type, Object functionDecl) {
        super(name, type);
        _functionDecl = functionDecl;
    }
    public Object code() {
        EZTypeFunction fn = cast(EZTypeFunction) _type;
        return fn._code;
    }
}

class VarSymbol : Symbol {
    // Values assigned by bytecode compiler
    int _regNumber;
    this(string name, EZType type) {
        super(name, type);
    }
}

class ParameterSymbol : VarSymbol {
    this(string name, EZType type) {
        super(name, type);
    }
}