module ezlang.lex;

import ezlang.errors;

enum TokenKind {
    IDENT,
    NUM,
    PUNCT,
    EOZ
}

class Token {
    TokenKind _kind;
    string _str;
    long _num;
    int _lineNumber;

    this(TokenKind kind, string str, long num, int lineNumber) {
        _kind = kind;
        _str = str;
        _num = num;
        _lineNumber = lineNumber;
    }
    static Token newIdent(string str, int lineNumber) {
        return new Token(TokenKind.IDENT, str, 0, lineNumber);
    }
    static Token newNum(long num, string str, int lineNumber) {
        return new Token(TokenKind.NUM, str, num, lineNumber);
    }
    static Token newPunct(string str, int lineNumber) {
        return new Token(TokenKind.PUNCT, str, 0, lineNumber);
    }

    static Token EOF;
    static this() {
        EOF = new Token(TokenKind.EOZ, "", 0, 0);
    }
    override string toString() const {
        return _str;
    }
}

class Lexer {

    import std.ascii : isAlpha, isDigit, isWhite;

    string _input;
    int _position;
    int _lineNumber;

    this(string input) {
        _input = input;
        _position = 0;
        _lineNumber = 0;
    }

    Token parseNumber() {
        long value = (_input[_position] - '0');
        int start_position = _position++;
        while (_position < _input.length && _input[_position] >= '0' && _input[_position] <= '9') {
            value = value * 10 + (_input[_position] - '0');
            _position++;
        }
        auto number_text = _input[start_position .. _position];
        return Token.newNum(value, number_text, _lineNumber);
    }

    bool isIdentifierStart(char c) {
        return isAlpha(c) || c == '_';
    }

    bool isIdentifierLetter(char c) {
        return isAlpha(c) || isDigit(c) || c == '_';
    }

    Token parseIdentifier() {
        int start_position = _position++;
        while (_position < _input.length && isIdentifierLetter(_input[_position]))
            _position++;
        return Token.newIdent(_input[start_position .. _position], _lineNumber);
    }

    char peekChar() {
        int pos = _position;
        char ch = 0;
        while (pos < _input.length && isWhite(_input[pos]))
            pos++;
        if (pos < _input.length)
            ch = _input[pos];
        return ch;
    }

    Token scan() {
        while (true) {
            if (_position >= _input.length) return Token.EOF;
            switch (_input[_position]) {
                case 0:
                    return Token.EOF;
                case ' ':
                case '\t':
                    _position++;
                    continue;
                case '\r':
                    _position++;
                    if (_position < _input.length && _input[_position] == '\n') {
                        _lineNumber++;
                        _position++;
                    }
                    continue;
                case '\n':
                    _lineNumber++;
                    _position++;
                    continue;
                case '&':
                    _position++;
                    if (_position < _input.length && _input[_position] == '&') {
                        _position++;
                        return Token.newPunct("&&", _lineNumber);
                    }
                    return Token.newPunct("&", _lineNumber);
                case '|':
                    _position++;
                    if (_position < _input.length && _input[_position] == '|') {
                        _position++;
                        return Token.newPunct("||", _lineNumber);
                    }
                    return Token.newPunct("|", _lineNumber);
                case '=':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.newPunct("==", _lineNumber);
                    }
                    return Token.newPunct("=", _lineNumber);
                case '<':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.newPunct("<=", _lineNumber);
                    }
                    return Token.newPunct("<", _lineNumber);
                case '>':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.newPunct(">=", _lineNumber);
                    }
                    return Token.newPunct(">", _lineNumber);
                case '!':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.newPunct("!=", _lineNumber);
                    }
                    return Token.newPunct("!", _lineNumber);
                case '-':
                    _position++;
                    if (_position < _input.length && _input[_position] == '>') {
                        _position++;
                        return Token.newPunct("->", _lineNumber);
                    }
                    return Token.newPunct("-", _lineNumber);
                case '{':
                case '}':
                case '[':
                case ']':
                case '(':
                case ')':
                case ',':
                case '.':
                case '%':
                case '+':
                case '*':
                case ';':
                case ':':
                case '?': {
                    return Token.newPunct([_input[_position++]], _lineNumber);
                }
                case '/':
                    _position++;
                    if (_position < _input.length && _input[_position] == '/') {
                        _position++;
                        while (_position < _input.length && _input[_position] != '\n') 
                            _position++;
                        continue;
                    }
                    return Token.newPunct("/", _lineNumber);
                default: {
                    return scanOthers();
                }
            }
        }
    }

    Token scanOthers() {
        if (isDigit(_input[_position])) return parseNumber();
        else if (isIdentifierStart(_input[_position])) return parseIdentifier();
        throw new CompilerException("Unexpected character " ~ _input[_position], _lineNumber);
    }

    int lineNumber() {return _lineNumber;}
}