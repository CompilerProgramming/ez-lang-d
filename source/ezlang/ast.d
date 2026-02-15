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
        _returnType = new ReturnTypeExpr(returnType);
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
    Expr _array;
    Expr _expr;
    Expr _value;
    this(Expr array, Expr expr, Expr value) {
        _array = array;
        _expr = expr;
        _value = value;
    }
    override void toStr(ref Appender!string sb) const {
        _array.toStr(sb);
        sb.put("[");
        _expr.toStr(sb);
        sb.put("]=");
        _value.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _array.accept(visitor);
        _expr.accept(visitor);
        _value.accept(visitor);
        visitor.exit(this);
    }
}

class ArrayInitExpr : ArrayStoreExpr {
    this(Expr array, Expr expr, Expr value) {
        super(array, expr, value);
    }
    override void toStr(ref Appender!string sb) const {
        _value.toStr(sb);
    }
}

class GetFieldExpr : Expr {
    Expr _object;
    string _fieldName;
    this(Expr object, string fieldName) {
        _object = object;
        _fieldName = fieldName;
    }
    override void toStr(ref Appender!string sb) const {
        _object.toStr(sb);
        sb.put(".");
        sb.put(_fieldName);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _object.accept(visitor);
        visitor.exit(this);
    }
}

class SetFieldExpr : Expr {
    Expr _object;
    string _fieldName;
    Expr _value;
    this(Expr object, string fieldName, Expr value) {
        _object = object;
        _fieldName = fieldName;
        _value = value;
    }
    override void toStr(ref Appender!string sb) const {
        _object.toStr(sb);
        sb.put(".");
        sb.put(_fieldName);
        sb.put("=");
        _value.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _object.accept(visitor);
        _value.accept(visitor);
        visitor.exit(this);
    }
}

class InitFieldExpr : SetFieldExpr {
    this(Expr object, string fieldName, Expr value) {
        super(object, fieldName, value);
    }
    override void toStr(ref Appender!string sb) const {
        sb.put(_fieldName);
        sb.put("=");
        _value.toStr(sb);
    }
}

class CallExpr : Expr {
    Expr _callee;
    Expr[] _args;
    this(Expr callee, Expr[] args) {
        _callee = callee;
        _args = args;
    }
    override void toStr(ref Appender!string sb) const {
        _callee.toStr(sb);
        sb.put("(");
        bool first = true;
        foreach(expr; _args) {
            if (!first)
                sb.put(",");
            expr.toStr(sb);
            first = false;
        }
        sb.put(")");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _callee.accept(visitor);
        foreach(expr; _args) {
            expr.accept(visitor);
        }
        visitor.exit(this);
    }
}

class NewExpr : Expr {
    TypeExpr _typeExpr;
    Expr _len;
    Expr _initValue;
    this(TypeExpr typeExpr) {
        _typeExpr = typeExpr;
        _len = null;
        _initValue = null;
    }
    this(TypeExpr typeExpr, Expr len, Expr initValue) {
        _typeExpr = typeExpr;
        _len = len;
        _initValue = initValue;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("new ");
        _typeExpr.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _typeExpr.accept(visitor);
        if (_len !is null) {
            _len.accept(visitor);
            if (_initValue !is null)
                _initValue.accept(visitor);
        }
        visitor.exit(this);
    }
}

class InitExpr : Expr {
    NewExpr _newExpr;
    Expr[] _initExprList;
    this(NewExpr newExpr, Expr[] initExprList) {
        _initExprList = initExprList;
        _newExpr = newExpr;
    }
    override void toStr(ref Appender!string sb) const {
        _newExpr.toStr(sb);
        sb.put("{");
        bool first = true;
        foreach (expr; _initExprList) {
            if (!first)
                sb.put(", ");
            first = false;
            expr.toStr(sb);
        }
        sb.put("}");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _newExpr.accept(visitor);
        foreach (expr; _initExprList) {
            expr.accept(visitor);
        }
        visitor.exit(this);
    }
}

abstract class Stmt : AST {}

class IfElseStmt : Stmt {
    Expr _condition;
    Stmt _ifStmt;
    Stmt _elseStmt;
    this(Expr expr, Stmt ifStmt, Stmt elseStmt) {
        _condition = expr;
        _ifStmt = ifStmt;
        _elseStmt = elseStmt;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("if(");
        _condition.toStr(sb);
        sb.put(")\n");
        _ifStmt.toStr(sb);
        if (_elseStmt !is null) {
            sb.put("\nelse\n");
            _elseStmt.toStr(sb);
        }
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _condition.accept(visitor);
        _ifStmt.accept(visitor);
        if (_elseStmt !is null)
            _elseStmt.accept(visitor);
        visitor.exit(this);
    }
}

class WhileStmt : Stmt {
    Expr _condition;
    Stmt _stmt;
    this(Expr expr) {
        _condition = expr;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("while(");
        _condition.toStr(sb);
        sb.put(")\n");
        _stmt.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _condition.accept(visitor);
        _stmt.accept(visitor);
        visitor.exit(this);
    }
}

class BreakStmt : Stmt {
    WhileStmt _whileStmt;
    this(WhileStmt whileStmt) {
        _whileStmt = whileStmt;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("break");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
} 

class ContinueStmt : Stmt {
    WhileStmt _whileStmt;
    this(WhileStmt whileStmt) {
        _whileStmt = whileStmt;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("continue");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        visitor.exit(this);
    }
}

class ReturnStmt : Stmt {
    Expr _expr;
    this(Expr expr) {
        _expr = expr;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("return");
        if (_expr !is null) {
            sb.put(" ");
            _expr.toStr(sb);
        }
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        if (_expr !is null)
            _expr.accept(visitor);
        visitor.exit(this);
    }
}

class AssignStmt : Stmt {
    NameExpr _nameExpr;
    Expr _rhs;
    this(NameExpr nameExpr, Expr rhs) {
        _nameExpr = nameExpr;
        _rhs = rhs;
    }
    override void toStr(ref Appender!string sb) const {
        _nameExpr.toStr(sb);
        sb.put(" = ");
        _rhs.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _nameExpr.accept(visitor);
        _rhs.accept(visitor);
        visitor.exit(this);
    }
}

class VarStmt : Stmt {
    string _varName;
    VarSymbol _symbol;
    Expr _expr;

    this(string symbol, Expr expr) {
        _varName = symbol;
        _expr = expr;
    }
    override void toStr(ref Appender!string sb) const {
        sb.put("var ");
        sb.put(_varName);
        sb.put(" = ");
        _expr.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _expr.accept(visitor);
        visitor.exit(this);
    }
}

class ExprStmt : Stmt {
    Expr _expr;
    this(Expr expr) {
        _expr = expr;
    }
    override void toStr(ref Appender!string sb) const {
        _expr.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _expr.accept(visitor);
        visitor.exit(this);
    }
}

class VarDeclStmt : Stmt {
    VarDecl _varDecl;
    this(VarDecl varDec) {
        _varDecl = varDec;
    }
    override void toStr(ref Appender!string sb) const {
        _varDecl.toStr(sb);
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        _varDecl.accept(visitor);
        visitor.exit(this);
    }
}

class BlockStmt : Stmt {
    Stmt[] _stmtList;
    Scope _scope;
    override void toStr(ref Appender!string sb) const {
        sb.put("{\n");
        foreach (stmt; _stmtList) {
            stmt.toStr(sb);
            sb.put("\n");
        }
        sb.put("}\n");
    }
    override void accept(ASTVisitor visitor) {
        visitor = visitor.enter(this);
        if (visitor is null)
            return;
        foreach (stmt; _stmtList) {
            stmt.accept(visitor);
        }
        visitor.exit(this);
    }
}