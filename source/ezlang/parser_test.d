module ezlang.parser_test;

import ezlang.parser;
import ezlang.lex;

import std.stdio;

unittest
{
    Parser parser = new Parser();
    string src = `
struct Tree {
    var left: Tree?
    var right: Tree?
}
struct Test {
    var intArray: [Int]
}
struct TreeArray {
    var array: [Tree?]?
}
func print(n: Int) {}
func foo(a: Int, b: [Int]) {
    while(1) {
        if (a > b.length)
            break
        print(b[a])
        a = a + 1
        a = a + 2
    }
}
func bar() -> Test {
    var v = new Test { intArray = new [Tree] {} }
    return v
}
func main() {
    var m = 42
    var t: Tree
    var array = new [Int] {len=10,1,2,3}
    array[1] = 42
    t.left = null
    if (m < 1)
       print(1)
    else if (m == 5)
       print(2)
    else
       print(3)
}
`;
    auto program = parser.parse(new Lexer(src));
    writeln("parsing completed");
    writeln(program.toString());
}