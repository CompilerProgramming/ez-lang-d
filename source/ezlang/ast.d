module ezlang.ast;

import ezlang.astvisit;
import ezlang.scopes;
import ezlang.symtab;
import ezlang.types;
import ezlang.lex;
import std.array : Appender;

abstract class AST {
    abstract void accept(ASTVisitor visitor);
    abstract void toStr(ref Appender!string sb) const;

    override string toString() const {
        auto sb = Appender!string();
        toStr(sb);
        return sb.data;
    }
}

class Program : AST {
    Decl[] _decls;
    Scope _scope;

    override void toStr(ref Appender!string sb) const {
        foreach (decl; _decls) {
            decl.toStr(sb);
        }
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        foreach (d; _decls) {
            d.accept(visitor);
        }
        visitor.exit(this);
    }
}

abstract class Decl : AST {}

enum VarType {
    STRUCT_FIELD,
    FUNCTION_PARAMETER,
    VARIABLE
}

class VarDecl : Decl {
    string _name;
    VarType _varType;
    TypeExpr _typeExpr;
    Symbol _symbol;

    this(string name, VarType varType, TypeExpr typeExpr) {
        _name = name;
        _varType = varType;
        _typeExpr = typeExpr;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("var ");
        sb.put(_name);
        sb.put(": ");
        _typeExpr.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _typeExpr.accept(visitor);
        visitor.exit(this);
    }
}

class StructDecl : Decl {
    string _name;
    VarDecl[] _fields;
    Scope _scope;
    Symbol _symbol;
    this(string name, VarDecl[] fields) {
        _name = name;
        _fields = fields;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("struct ");
        sb.put(_name);
        sb.put("{\n");
        foreach (field; _fields) {
            sb.put("  ");
            field.toStr(sb);
            sb.put("\n");
        }
        sb.put("}\n");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        foreach (field; _fields) {
            field.accept(visitor);
        }
        visitor.exit(this);
    }
}

class FuncDecl : Decl {
    string _name;
    VarDecl[] _args;
    ReturnTypeExpr _returnType;
    BlockStmt _block;
    Scope _scope;
    Symbol _symbol;

    this(string name, VarDecl[] args, TypeExpr returnType, BlockStmt block) {
        _name = name;
        _args = args;
        _returnType = null; // FIXME new ReturnTypeExpr(returnType);
        _block = block;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("func ");
        sb.put(_name);
        sb.put("(");
        for (int i = 0; i < _args.length; i++) {
            if (i > 0) {
                sb.put(", ");
            }
            _args[i].toStr(sb);
        }
        sb.put(")");
        sb.put("->");
        _returnType.toStr(sb);
        sb.put("\n");
        _block.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        foreach (arg; _args) {
            arg.accept(visitor);
        }
        _returnType.accept(visitor);
        _block.accept(visitor);
        visitor.exit(this);
    }
}

abstract class Expr : AST {
    EZType _type;
}

abstract class TypeExpr : Expr {
    abstract string name();
}

class SimpleTypeExpr : TypeExpr {
    protected string _name;

    this(string name) {
        _name = name;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put(_name);
    }
    override string name() { 
        auto sb = Appender!string();
        toStr(sb);
        return sb.data;
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
}

class NullableSimpleTypeExpr : SimpleTypeExpr {
    this(string name) {
        super(name);
    }
    override void toStr(ref Appender!string sb) const {
        super.toStr(sb);
        sb.put("?");
    }
    string baseTypeName() {
        return super._name;
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
}

class ArrayTypeExpr : TypeExpr {
    SimpleTypeExpr _elementType;

    this(SimpleTypeExpr elementType) {
        _elementType = elementType;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("[");
        _elementType.toStr(sb);
        sb.put("]");
    }
    override string name() { 
        auto sb = Appender!string();
        toStr(sb);
        return sb.data;
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _elementType.accept(visitor);
        visitor.exit(this);
    }
}

class NullableArrayTypeExpr : ArrayTypeExpr {
    this(SimpleTypeExpr elementType) {
        super(elementType);
    }
    override void toStr(ref Appender!string sb) const {
        super.toStr(sb);
        sb.put("?");
    }
    string baseTypeName() {
        auto sb = Appender!string();
        super.toStr(sb);
        return sb.data;
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _elementType.accept(visitor);
        visitor.exit(this);
    }
}

class ReturnTypeExpr : Expr {
    TypeExpr _returnType;

    this(TypeExpr returnType) {
        _returnType = returnType;
    }

    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        if (_returnType !is null)
            _returnType.accept(visitor);
        visitor.exit(this);
    }

    override void toStr(ref Appender!string sb) const {
        if (_returnType !is null)
            _returnType.toStr(sb);
    }
}

class NameExpr : Expr {
    string _name;
    Symbol _symbol;
    this(string name) {
        _name = name;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put(_name);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
}

class BinaryExpr : Expr {
    Token _op;
    Expr _expr1;
    Expr _expr2;
    this(Token op, Expr expr1, Expr expr2) {
        _op = op;
        _expr1 = expr1;
        _expr2 = expr2;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("(");
        _expr1.toStr(sb);
        sb.put(_op.toString());
        _expr2.toStr(sb);
        sb.put(")");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _expr1.accept(visitor);
        _expr2.accept(visitor);
        visitor.exit(this);
    }
} 

class UnaryExpr : Expr {
    Token _op;
    Expr _expr;
    this(Token op, Expr expr) {
        _op = op;
        _expr = expr;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("(");
        sb.put(_op.toString());
        sb.put("(");
        _expr.toStr(sb);
        sb.put("))");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _expr.accept(visitor);
        visitor.exit(this);
    }
}

class LiteralExpr : Expr {
    Token _value;
    this(Token value) {
        _value = value;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put(_value._str);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
}

class ArrayLoadExpr : Expr {
    Expr _array;
    Expr _expr;
    this(Expr array, Expr expr) {
        _array = array;
        _expr = expr;
    }
    override void toStr(ref Appender!string sb) const {
        _array.toStr(sb);
        sb.put("[");
        _expr.toStr(sb);
        sb.put("]");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _array.accept(visitor);
        _expr.accept(visitor);
        visitor.exit(this);
    }
} 

class ArrayStoreExpr : Expr {

}

class ArrayInitExpr : ArrayStoreExpr {

}

class GetFieldExpr : Expr {

}

class SetFieldExpr : Expr {

}

class InitFieldExpr : SetFieldExpr {

}

class CallExpr : Expr {

}

class NewExpr : Expr {

}

class InitExpr : Expr {

}

abstract class Stmt : AST {

}

class IfElseStmt : Stmt {

}

class WhileStmt : Stmt {

}

class BreakStmt : Stmt {

} 

class ContinueStmt : Stmt {

}

class ReturnStmt : Stmt {

}

class AssignStmt : Stmt {

}

class VarStmt : Stmt {

}

class ExprStmt : Stmt {

}

class VarDeclStmt : Stmt {

}

class BlockStmt : Stmt {

}