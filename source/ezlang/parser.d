module ezlang.parser;

import ezlang.lex;
import ezlang.ast;
import ezlang.errors;

import std.format : format;
import std.stdio;

class Parser {

    Token _currentToken;
    WhileStmt _currentWhile;

    Program parse(Lexer lexer) {
        nextToken(lexer);
        return parseProgram(lexer);
    }

    void nextToken(Lexer lexer) {
        _currentToken = lexer.scan();
    }
    void error(Token t, string errorMessage) {
        throw new CompilerException(errorMessage ~ " got " ~ t._str, t._lineNumber);
    }
    void matchPunctuation(Lexer lexer, string value) {
        if (_currentToken._kind == TokenKind.PUNCT && isToken(_currentToken, value)) {
            nextToken(lexer);
        } else {
            error(_currentToken, "Syntax error: expected " ~ value);
        }
    }
    bool testPunctuation(Lexer lexer, string value) {
        if (_currentToken._kind == TokenKind.PUNCT && isToken(_currentToken, value)) {
            nextToken(lexer);
            return true;
        }
        return false;
    }
    void matchIdentifier(Lexer lexer, string identifier) {
        if (_currentToken._kind == TokenKind.IDENT && isToken(_currentToken, identifier)) {
            nextToken(lexer);
        } else {
            error(_currentToken, "syntax error, expected " ~ identifier);
        }
    }
    bool isToken(Token token, string value) {
        return token._str == value;
    }
    Program parseProgram(Lexer lexer) {
        Program program = new Program();
        parseDefinitions(lexer, program);
        return program;
    }
    void parseDefinitions(Lexer lexer, Program program) {
        while (_currentToken._kind == TokenKind.IDENT) {
            if ("func" == _currentToken._str)
                program._decls ~= parseFunction(lexer);
            else if ("struct" == _currentToken._str)
                program._decls ~= parseStructDeclaration(lexer);
            else
                error(_currentToken, "Syntax error: Expected the keyword 'func' or 'struct' at start of a declaration");
        }
    }
    FuncDecl parseFunction(Lexer lexer) {
        matchIdentifier(lexer, "func");
        if (_currentToken._kind != TokenKind.IDENT)
            error(_currentToken, "Syntax error: Function name expected");
        string functionName = _currentToken._str;
        nextToken(lexer);
        matchPunctuation(lexer, "(");
        VarDecl[] params;
        while (_currentToken._kind == TokenKind.IDENT) {
            VarDecl param = parseVarDeclaration(lexer, false, VarType.FUNCTION_PARAMETER);
            params ~= param;
            if (!testPunctuation(lexer, ",")) break;
        }
        matchPunctuation(lexer, ")");
        TypeExpr returnType = null;
        if (testPunctuation(lexer, "->"))
            returnType = parseTypeExpr(lexer);
        BlockStmt block = parseBlock(lexer);
        return new FuncDecl(functionName, params, returnType, block);
    }
    VarDecl parseVarDeclaration(Lexer lexer, bool expectVar, VarType varType) {
        if (expectVar)
            matchIdentifier(lexer, "var");
        if (_currentToken._kind != TokenKind.IDENT)
            error(_currentToken, "Syntax error: name expected");
        string identifier = _currentToken._str;
        nextToken(lexer);
        matchPunctuation(lexer, ":");
        TypeExpr fieldType = parseTypeExpr(lexer);
        return new VarDecl(identifier, varType, fieldType);
    }
    ArrayTypeExpr parseArrayTypeExpr(Lexer lexer) {
        matchPunctuation(lexer, "[");
        SimpleTypeExpr elementType = parseSimpleTypeExpr(lexer);
        matchPunctuation(lexer, "]");
        bool isNullable = false;
        if (testPunctuation(lexer, "?"))
            isNullable = true;

        return isNullable ? new NullableArrayTypeExpr(elementType) : new ArrayTypeExpr(elementType);
    }
    SimpleTypeExpr parseSimpleTypeExpr(Lexer lexer) {
        string typeName = null;
        if (_currentToken._kind == TokenKind.IDENT)
            typeName = _currentToken._str;
        else
            error(_currentToken, "Expected a type name");
        nextToken(lexer);
        bool isNullable = false;
        if (testPunctuation(lexer, "?"))
            isNullable = true;
        return isNullable ? new NullableSimpleTypeExpr(typeName) : new SimpleTypeExpr(typeName);
    }
    TypeExpr parseTypeExpr(Lexer lexer) {
        if (isToken(_currentToken, "["))
            return parseArrayTypeExpr(lexer);
        else
            return parseSimpleTypeExpr(lexer);
    }
    StructDecl parseStructDeclaration(Lexer lexer) {
        matchIdentifier(lexer, "struct");
        string structName = null;
        if (_currentToken._kind == TokenKind.IDENT)
            structName = _currentToken._str;
        else
            error(_currentToken, "Expected an identifier after struct keyword");
        nextToken(lexer);
        matchPunctuation(lexer, "{");
        VarDecl[] fields;
        while (_currentToken._kind == TokenKind.IDENT) {
            VarDecl field = parseVarDeclaration(lexer, true, VarType.STRUCT_FIELD);
            fields ~= field;
            testPunctuation(lexer, ";");
        }
        matchPunctuation(lexer, "}");
        return new StructDecl(structName, fields);
    }
    Stmt parseVarDeclOrStmt(Lexer lexer) {
        matchIdentifier(lexer, "var");
        Stmt stmt = null;
        if (_currentToken._kind == TokenKind.IDENT && lexer.peekChar() == '=') {
            string name = _currentToken._str;
            nextToken(lexer);
            matchPunctuation(lexer, "=");
            stmt = new VarStmt(name, parseBool(lexer));
        }
        else {
            stmt = new VarDeclStmt(parseVarDeclaration(lexer, false, VarType.VARIABLE));
        }
        testPunctuation(lexer, ";");
        return stmt;
    }
    Stmt parseStatement(Lexer lexer) {
        Expr x = null;
        Stmt s1;
        Stmt s2;
        string tk = _currentToken._str;
        
        if ("var" == tk) {
            return parseVarDeclOrStmt(lexer);
        }
        else if ("if" == tk) {
            matchIdentifier(lexer, "if");
            matchPunctuation(lexer, "(");
            x = parseBool(lexer);
            matchPunctuation(lexer, ")");
            s1 = parseStatement(lexer);
            if (!isToken(_currentToken, "else")) {
                return new IfElseStmt(x, s1, null);
            }
            matchIdentifier(lexer, "else");
            s2 = parseStatement(lexer);
            return new IfElseStmt(x, s1, s2);
        }
        else if ("while" == tk) {
            matchIdentifier(lexer, "while");
            matchPunctuation(lexer, "(");
            x = parseBool(lexer);
            matchPunctuation(lexer, ")");
            auto savedWhile = _currentWhile;
            auto whileStmt = _currentWhile = new WhileStmt(x);
            _currentWhile._stmt = parseStatement(lexer);
            _currentWhile = savedWhile;
            return whileStmt;
        }
        else if ("break" == tk) {
            matchIdentifier(lexer, "break");
            testPunctuation(lexer, ";");
            return new BreakStmt(_currentWhile);
        }
        else if ("continue" == tk) {
            matchIdentifier(lexer, "continue");
            testPunctuation(lexer, ";");
            return new ContinueStmt(_currentWhile);
        }
        else if ("return" == tk) {
            matchIdentifier(lexer, "return");
            if (!isToken(_currentToken, ";")
                && !isToken(_currentToken, "}"))
                x = parseBool(lexer);
            testPunctuation(lexer, ";");
            return new ReturnStmt(x);
        }
        else if ("{" == tk) {
            return parseBlock(lexer);
        }
        else {
            return parseAssign(lexer);
        }
    }
    BlockStmt parseBlock(Lexer lexer) {
        matchPunctuation(lexer, "{");
        auto block = new BlockStmt();
        while (_currentToken._kind != TokenKind.EOZ && !testPunctuation(lexer, "}")) {
            block._stmtList ~= parseStatement(lexer);
        }
        return block;
    }
    // Parse assignment or expression statement
    Stmt parseAssign(Lexer lexer) {
        Expr lhs = parseBool(lexer);
        Expr rhs = null;
        if (testPunctuation(lexer, "="))
            rhs = parseBool(lexer);
        testPunctuation(lexer, ";");
        if (rhs is null)
            return new ExprStmt(lhs);
        else {
            if (auto arrayLoadExpr = cast(ArrayLoadExpr) lhs) {
                return new ExprStmt(new ArrayStoreExpr(arrayLoadExpr._array, arrayLoadExpr._expr, rhs));
            }
            else if (auto getFieldExpr = cast(GetFieldExpr) lhs) {
                return new ExprStmt(new SetFieldExpr(getFieldExpr._object, getFieldExpr._fieldName, rhs));
            }
            else if (auto nameExpr = cast(NameExpr) lhs) {
                return new AssignStmt(nameExpr, rhs);
            }
            else throw new CompilerException("Expected a name, expr[] or expr.field", _currentToken._lineNumber);
        }
    }
    Expr parseBool(Lexer lexer) {
        auto x = parseAnd(lexer);
        while (isToken(_currentToken, "||")) {
            auto tok = _currentToken;
            nextToken(lexer);
            x = new BinaryExpr(tok, x, parseAnd(lexer));
        }
        return x;
    }
    Expr parseAnd(Lexer lexer) {
        auto x = parseRelational(lexer);
        while (isToken(_currentToken, "&&")) {
            auto tok = _currentToken;
            nextToken(lexer);
            x = new BinaryExpr(tok, x, parseRelational(lexer));
        }
        return x;
    }
    Expr parseRelational(Lexer lexer) {
        auto x = parseAddition(lexer);
        while (isToken(_currentToken, "==")
                || isToken(_currentToken, "!=")
                || isToken(_currentToken, "<=")
                || isToken(_currentToken, "<")
                || isToken(_currentToken, ">")
                || isToken(_currentToken, ">=")) {
            auto tok = _currentToken;
            nextToken(lexer);
            x = new BinaryExpr(tok, x, parseAddition(lexer));
        }
        return x;
    }
    Expr parseAddition(Lexer lexer) {
        auto x = parseMultiplication(lexer);
        while (isToken(_currentToken, "-")
                || isToken(_currentToken, "+")) {
            auto tok = _currentToken;
            nextToken(lexer);
            x = new BinaryExpr(tok, x, parseMultiplication(lexer));
        }
        return x;
    }
    Expr parseMultiplication(Lexer lexer) {
        auto x = parseUnary(lexer);
        while (isToken(_currentToken, "*")
                || isToken(_currentToken, "%")
                || isToken(_currentToken, "/")) {
            auto tok = _currentToken;
            nextToken(lexer);
            x = new BinaryExpr(tok, x, parseUnary(lexer));
        }
        return x;
    }
    Expr parseUnary(Lexer lexer) {
        if (isToken(_currentToken, "-")
                || isToken(_currentToken, "!")) {
            auto tok = _currentToken;
            nextToken(lexer);
            return new UnaryExpr(tok, parseUnary(lexer));
        } else {
            return parsePostfix(lexer, parsePrimary(lexer));
        }
    }
    Expr parseNew(Lexer lexer) {
        matchIdentifier(lexer, "new");
        TypeExpr resultType = parseTypeExpr(lexer);
        auto newExpr = new NewExpr(resultType);
        Expr lenExpr = null;
        Expr initValueExpr = null;
        Expr[] initExpr;
        int index = 0;
        if (testPunctuation(lexer, "{")) {
            while (!isToken(_currentToken, "}")) {
                if (_currentToken._kind == TokenKind.IDENT && lexer.peekChar() == '=') {
                    string fieldname = _currentToken._str;
                    nextToken(lexer);
                    matchPunctuation(lexer, "=");
                    Expr value = parseBool(lexer);
                    initExpr ~= new InitFieldExpr(newExpr, fieldname, value);
                    if (fieldname == "len")
                        lenExpr = value;
                    else if (fieldname == "value")
                        initValueExpr = value;
                }
                else {
                    auto indexLit = index++;
                    auto indexExpr = new LiteralExpr(Token.newNum(indexLit,format("%s",indexLit),_currentToken._lineNumber));
                    initExpr ~= new ArrayInitExpr(newExpr, indexExpr, parseBool(lexer));
                }
                if (isToken(_currentToken, ","))
                    nextToken(lexer);
                else break;
            }
        }
        matchPunctuation(lexer, "}");
        if (initExpr.length > 0 && lenExpr is null) {
            auto sizeLit = initExpr.length;
            lenExpr = new LiteralExpr(Token.newNum(sizeLit,format("%s",sizeLit),_currentToken._lineNumber));
        }
        if (lenExpr !is null)
            return new InitExpr(new NewExpr(newExpr._typeExpr, lenExpr, initValueExpr), initExpr);
        return new InitExpr(newExpr, initExpr);
    }
    Expr parsePrimary(Lexer lexer) {
        auto tk = _currentToken._kind;
        if (tk == TokenKind.PUNCT) {
            /* Nested expression */
            matchPunctuation(lexer, "(");
            auto x = parseBool(lexer);
            matchPunctuation(lexer, ")");
            return x;
        }
        else if (tk == TokenKind.NUM) {
            auto x = new LiteralExpr(_currentToken);
            nextToken(lexer);
            return x;
        }
        else if (tk == TokenKind.IDENT) {
            if (isToken(_currentToken, "null")) {
                auto x = new LiteralExpr(_currentToken);
                nextToken(lexer);
                return x;
            }
            else if (isToken(_currentToken, "new")) {
                return parseNew(lexer);
            }
            else {
                auto x = new NameExpr(_currentToken._str);
                nextToken(lexer);
                return x;
            }
        }
        else {
            error(_currentToken, "syntax error, expected nested expr, integer value or variable");
            return null;
        }
    }
    Expr parsePostfix(Lexer lexer, Expr primaryExpr) {
        Expr prevExpr = primaryExpr;
        while (isToken(_currentToken, "[")
                || isToken(_currentToken, "(")
                || isToken(_currentToken, ".")) {
            Token tok = _currentToken;
            nextToken(lexer);
            if (tok._str == "[") {
                Expr expr = parseBool(lexer);
                prevExpr = new ArrayLoadExpr(prevExpr, expr);
                matchPunctuation(lexer, "]");
            }
            else if (tok._str == ".") {
                if (_currentToken._kind == TokenKind.IDENT) {
                    prevExpr = new GetFieldExpr(prevExpr, _currentToken._str);
                    nextToken(lexer);
                }
                else
                    error(_currentToken, "Syntax error: Expected name after .");
            }
            else if (tok._str == "(") {
                Expr[] args;
                while (!isToken(_currentToken, ")")) {
                    args ~= parseBool(lexer);
                    if (isToken(_currentToken, ","))
                        nextToken(lexer);
                    else break;
                }
                matchPunctuation(lexer, ")");
                prevExpr = new CallExpr(prevExpr, args);
            }
            else 
               error(_currentToken, "Syntax error: expected a postfix operator [ . or C");
        }
        return prevExpr;
    }
}