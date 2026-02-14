module ezlang.scopes;

import ezlang.symtab;
import ezlang.errors;

class Scope {

    Symbol[string] _bindings;
    Symbol[] _symbols;
    Scope _parent;
    Scope[] _children;

    int _maxReg;
    bool _isFunctionParameterScope;

    this(Scope parent, bool isFunctionParameterScope) {
        _parent = parent;
        _isFunctionParameterScope = isFunctionParameterScope;
        if (parent !is null)
            parent._children ~= this;
    }

    this(Scope parent) {
        this(parent, false);
    }

    Symbol lookup(string name) {
        Symbol symbol = localLookup(name);
        if (symbol is null && _parent !is null)
            symbol = _parent.lookup(name);
        return symbol;
    }

    public Symbol localLookup(string name) {
        return _bindings.get(name, null);
    }

    public Symbol install(string name, Symbol symbol) {
        auto previous = localLookup(name);
        if (previous !is null)
            throw new CompilerException("Symbol " ~ name ~ " already defined in scope", -1);
        _bindings[name] = symbol;
        _symbols ~= symbol;
        return symbol;
    }

    public Symbol[] getLocalSymbols() {
        return _symbols;
    }

}