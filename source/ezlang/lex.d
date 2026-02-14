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
    int _line_number;

    this(TokenKind kind, string str, long num, int line_number) {
        _kind = kind;
        _str = str;
        _num = num;
        _line_number = line_number;
    }
    static Token new_ident(string str, int line_number) {
        return new Token(TokenKind.IDENT, str, 0, line_number);
    }
    static Token new_num(long num, string str, int line_number) {
        return new Token(TokenKind.NUM, str, num, line_number);
    }
    static Token new_punct(string str, int line_number) {
        return new Token(TokenKind.PUNCT, str, 0, line_number);
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
    int _line_number;

    this(string input) {
        _input = input;
        _position = 0;
        _line_number = 0;
    }

    Token parse_number() {
        long value = (_input[_position] - '0');
        int start_position = _position++;
        while (_position < _input.length && _input[_position] >= '0' && _input[_position] <= '9') {
            value = value * 10 + (_input[_position] - '0');
            _position++;
        }
        auto number_text = _input[start_position .. _position];
        return Token.new_num(value, number_text, _line_number);
    }

    bool is_identifier_start(char c) {
        return isAlpha(c) || c == '_';
    }

    bool is_identifier_letter(char c) {
        return isAlpha(c) || isDigit(c) || c == '_';
    }

    Token parse_identifier() {
        int start_position = _position++;
        while (_position < _input.length && is_identifier_letter(_input[_position]))
            _position++;
        return Token.new_ident(_input[start_position .. _position], _line_number);
    }

    char peek_char() {
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
                        _line_number++;
                        _position++;
                    }
                    continue;
                case '\n':
                    _line_number++;
                    _position++;
                    continue;
                case '&':
                    _position++;
                    if (_position < _input.length && _input[_position] == '&') {
                        _position++;
                        return Token.new_punct("&&", _line_number);
                    }
                    return Token.new_punct("&", _line_number);
                case '|':
                    _position++;
                    if (_position < _input.length && _input[_position] == '|') {
                        _position++;
                        return Token.new_punct("||", _line_number);
                    }
                    return Token.new_punct("|", _line_number);
                case '=':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.new_punct("==", _line_number);
                    }
                    return Token.new_punct("=", _line_number);
                case '<':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.new_punct("<=", _line_number);
                    }
                    return Token.new_punct("<", _line_number);
                case '>':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.new_punct(">=", _line_number);
                    }
                    return Token.new_punct(">", _line_number);
                case '!':
                    _position++;
                    if (_position < _input.length && _input[_position] == '=') {
                        _position++;
                        return Token.new_punct("!=", _line_number);
                    }
                    return Token.new_punct("!", _line_number);
                case '-':
                    _position++;
                    if (_position < _input.length && _input[_position] == '>') {
                        _position++;
                        return Token.new_punct("->", _line_number);
                    }
                    return Token.new_punct("-", _line_number);
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
                    return Token.new_punct([_input[_position++]], _line_number);
                }
                case '/':
                    _position++;
                    if (_position < _input.length && _input[_position] == '/') {
                        _position++;
                        while (_position < _input.length && _input[_position] != '\n') 
                            _position++;
                        continue;
                    }
                    return Token.new_punct("/", _line_number);
                default: {
                    return scan_others();
                }
            }
        }
    }

    Token scan_others() {
        if (isDigit(_input[_position])) return parse_number();
        else if (is_identifier_start(_input[_position])) return parse_identifier();
        throw new CompilerException("Unexpected character " ~ _input[_position], _line_number);
    }

    int line_Number() {return _line_number;}
}