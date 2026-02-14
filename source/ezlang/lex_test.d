module ezlang.lex_test;

import ezlang.lex;

unittest {
    auto lexer = new Lexer("124");
    auto token = lexer.parseNumber();
    assert(token._kind == TokenKind.NUM);
    assert(token._num == 124);
}

unittest {
    auto lexer = new Lexer("abc");
    auto token = lexer.parseIdentifier();
    assert(token._kind == TokenKind.IDENT);
    assert(token._str == "abc");
}

unittest {
    auto src = `
        // A comment
        Ident=,>=<>>=!=!155{0}11()[]+-*/ //Another comment
        `;
    auto lexer = new Lexer(src);
    Token[] expected = [
        Token.newIdent("Ident", 0),
        Token.newPunct("=", 0),
        Token.newPunct(",", 0),
        Token.newPunct(">=", 0),
        Token.newPunct("<", 0),
        Token.newPunct(">", 0),
        Token.newPunct(">=", 0),
        Token.newPunct("!=", 0),
        Token.newPunct("!", 0),
        Token.newNum(155, "155", 0),
        Token.newPunct("{", 0),
        Token.newNum(0, "0", 0),
        Token.newPunct("}", 0),
        Token.newNum(11, "11", 0),
        Token.newPunct("(", 0),
        Token.newPunct(")", 0),
        Token.newPunct("[", 0),
        Token.newPunct("]", 0),
        Token.newPunct("+", 0),
        Token.newPunct("-", 0),
        Token.newPunct("*", 0),
        Token.newPunct("/", 0)
    ];
    Token[] tokens = [];
    Token token = lexer.scan();
    while (token != Token.EOF) {
        tokens ~= token;
        token = lexer.scan();
    }
    assert(tokens.length == expected.length);
    for (int i = 0; i < expected.length; i++) {
        assert(expected[i]._str == tokens[i]._str);
        assert(expected[i]._num == tokens[i]._num);
        assert(expected[i]._kind == tokens[i]._kind);
    }
}