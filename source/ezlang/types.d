module ezlang.types;

import std.array : appender;
import std.format : format;
import ezlang.errors;
import ezlang.symtab;

// Translated from Java version with help from ChatGPT

/**
 * Currently, we support Int, Struct, and Array of Int/Struct.
 * Arrays and Structs are reference types.
 */
abstract class EZType {

    // Type classes
    enum ubyte TVOID     = 0;
    enum ubyte TUNKNOWN  = 1;
    enum ubyte TNULL     = 2;
    enum ubyte TINT      = 3; // Int, Bool
    enum ubyte TNULLABLE = 4; // Null, or not null ptr
    enum ubyte TFUNC     = 5; // Function types
    enum ubyte TSTRUCT   = 6;
    enum ubyte TARRAY    = 7;

    immutable ubyte _tclass; // type class
    immutable string _name;  // type name, always unique

    protected this(ubyte tclass, string name) {
        _tclass = tclass;
        _name = name;
    }

    bool isPrimitive() const { return false; }
    string describe() const { return toString(); }

    override bool opEquals(Object o) const {
        if (this is o) return true;
        if (o is null) return false;
        // Match Java: getClass() equality (exact runtime type)
        if (typeid(o) !is typeid(this)) return false;

        auto other = cast(EZType)o;
        return other !is null && _tclass == other._tclass && _name == other._name;
    }

    override size_t toHash() const {
        // Rough equivalent of Objects.hash(tclass, name)
        size_t h = cast(size_t)_tclass;
        h = h * 31 + typeid(_name).getHash(&_name);
        return h;
    }

    override string toString() const { return _name; }
    string name() const { return _name; }

    bool isAssignable(const EZType other) const {
        if (other is null || cast(EZTypeVoid)other !is null || cast(EZTypeUnknown)other !is null)
            return false;

        if (this is other || this == other) return true;

        if (auto nullable = cast(EZTypeNullable)this) {
            if (cast(EZTypeNull)other !is null)
                return true;
            return nullable._base_type.isAssignable(other);
        } else if (auto otherNullable = cast(EZTypeNullable)other) {
            // At compile time we allow nullable value to be
            // assigned to base type, but null check must be inserted
            // Optimizer may remove null check
            return this.isAssignable(otherNullable._base_type);
        }

        return false;
    }

}

/**
    * Represents no type - useful for defining functions
    * that do not return a value
    */
class EZTypeVoid : EZType {
    this() { super(TVOID, "$Void"); }
}

class EZTypeUnknown : EZType {
    this() { super(TUNKNOWN, "$Unknown"); }
}

class EZTypeNull : EZType {
    this() { super(TNULL, "$Null"); }
}

class EZTypeInteger : EZType {
    this() { super(TINT, "Int"); }
    override bool isPrimitive() const { return true; }
}

class EZTypeStruct : EZType {
    string[] _field_names;
    EZType[] _field_types;
    bool _pending = true;

    this(string name) { super(TSTRUCT, name); }

    private int indexOfField(string fname) const {
        foreach (i, n; _field_names)
            if (n == fname) return cast(int)i;
        return -1;
    }

    void addField(string fname, EZType type) {
        if (!_pending)
            throw new CompilerException("Cannot add field to an already defined struct",-1);
        if (indexOfField(fname) >= 0)
            throw new CompilerException("Field " ~ fname ~ " already exists in struct " ~ this.name,-1);
        if (type is null)
            throw new CompilerException("Cannot a field with null type",-1); // mirrors Java text

        _field_names ~= fname;
        _field_types ~= type;
    }

    override string describe() const {
        auto sb = appender!string();
        sb.put("struct ");
        sb.put(_name);
        sb.put("{");
        for (size_t i = 0; i < _field_names.length; i++) {
            sb.put(_field_names[i]);
            sb.put(": ");
            sb.put(_field_types[i]._name);
            sb.put(";");
        }
        sb.put("}");
        return sb.data;
    }

    EZType getField(string fname) {
        int index = indexOfField(fname);
        if (index < 0) return null;
        return _field_types[index];
    }

    int getFieldIndex(string fname) const {
        return indexOfField(fname);
    }

    int numFields() const { return cast(int)_field_names.length; }
    string getFieldName(int index) const { return _field_names[index]; }
    void complete() { _pending = false; }
}

class EZTypeArray : EZType {
    const EZType _element_type;

    this(EZType base_type) {
        super(TARRAY, "[" ~ base_type.name ~ "]");
        _element_type = base_type;
        if (cast(EZTypeArray)base_type !is null)
            throw new CompilerException("Array of array type not supported",-1);
    }

    const(EZType) getElementType() const { return _element_type; }
}

// This is really a dedicated Union type for T|Null.
class EZTypeNullable : EZType {
    const EZType _base_type;

    this(EZType base_type) {
        super(TNULLABLE, base_type.name ~ "?");
        this._base_type = base_type;
    }
}

class EZTypeFunction : EZType {
    Symbol[] _args;
    EZType _return_type;
    Object _code;

    this(string name) { super(TFUNC, name); }

    void addArg(Symbol arg) { _args ~= arg; }
    void setReturnType(EZType return_type) { this._return_type = return_type; }

    override string describe() const {
        auto sb = appender!string();
        sb.put("func ");
        sb.put(_name);
        sb.put("(");

        bool first = true;
        foreach (arg; _args) {
            if (!first) sb.put(",");
            first = false;
            sb.put(arg._name);
            sb.put(": ");
            sb.put(arg._type._name);
        }
        sb.put(")");

        if (cast(EZTypeVoid)_return_type is null) {
            sb.put("->");
            sb.put(_return_type._name);
        }

        return sb.data;
    }
}
