module ezlang.types_test;

import ezlang.types;

EZType buildStruct1(TypeDictionary typeDictionary) {
    auto s = new EZTypeStruct("S1");
    s.addField("a", typeDictionary.INT);
    s.addField("b", typeDictionary.INT);
    s.complete();
    return typeDictionary.intern(s);
}

EZType buildStruct2(TypeDictionary typeDictionary) {
    auto s = new EZTypeStruct("S2");
    s.addField("a", typeDictionary.INT);
    s.addField("b", typeDictionary.INT);
    s.complete();
    return typeDictionary.intern(s);
}

unittest
{
    auto typeDict = new TypeDictionary();

    auto tint = typeDict.INT;
    assert(tint.isPrimitive);

    auto s1 = buildStruct1(typeDict);
    auto s2 = buildStruct2(typeDict);

    auto s1Type = typeDict.localLookup("S1")._type;
    auto s2Type = typeDict.localLookup("S2")._type;

    assert(s1.isAssignable(s1Type));
    assert(!tint.isAssignable(s1Type));
    assert(!s1.isAssignable(s2Type));

    assert(s2.isAssignable(s2Type));
    assert(!s2.isAssignable(s1Type));

    auto s1TypeDup = buildStruct1(typeDict);
    assert(s1Type is s1TypeDup);

    auto nullType = typeDict.NULL;
    auto nullableS1Type = typeDict.merge(s1Type,nullType);
    assert(nullableS1Type.isAssignable(nullType));
    assert(nullableS1Type.isAssignable(s1Type));
}