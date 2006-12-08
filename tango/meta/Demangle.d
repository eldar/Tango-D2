/**
 *  Demangle a ".mangleof" name at compile time.
 *
 * Used by tango.meta.Nameof.
 *
 * License:   BSD style: $(LICENSE)
 * Authors:   Don Clugston
 * Copyright: Copyright (C) 2005-2006 Don Clugston
 */
module tango.meta.Demangle;
private import tango.meta.Convert;
/*
 Implementation is via pairs of metafunctions:
 a 'demangle' metafunction, which returns a const char [],
 and a 'Consumed' metafunction, which returns an integer, the number of characters which
 are used.
*/

/*****************************************
 * How should the name be displayed?
 */
enum MangledNameType
{
    PrettyName,    // With full type information
    QualifiedName, // No type information, just identifiers seperated by dots
    SymbolName     // Only the ultimate identifier
}

/*****************************************
 * Pretty-prints a mangled type string.
 */
template demangleType(char[] str, MangledNameType wantQualifiedNames = MangledNameType.PrettyName)
{
    static if (wantQualifiedNames != MangledNameType.PrettyName) {
        // There are only a few types where symbolnameof!(), qualifiednameof!()
        // make sense.
        static if (str[0]=='C' || str[0]=='S' || str[0]=='E' || str[0]=='T')
            const char [] demangleType = prettyLname!(str[1..$], wantQualifiedNames);
        else {
            static assert(0, "Demangle error: type '" ~ str ~ "' does not contain a qualified name");
        }
    } else static if (str[0] == 'A') // dynamic array
        const char [] demangleType = demangleType!(str[1..$], wantQualifiedNames) ~ "[]";
    else static if (str[0] == 'H')   // associative array
        const char [] demangleType
            = demangleType!(str[1+demangleTypeConsumed!(str[1..$])..$], wantQualifiedNames)
            ~ "[" ~ demangleType!(str[1..1+(demangleTypeConsumed!(str[1..$]))], wantQualifiedNames) ~ "]";
    else static if (str[0] == 'G') // static array
        const char [] demangleType
            = demangleType!(str[1+countLeadingDigits!(str[1..$])..$], wantQualifiedNames)
            ~ "[" ~ str[1..1+countLeadingDigits!(str[1..$]) ] ~ "]";
    else static if (str[0]=='C')
        const char [] demangleType = "class " ~ prettyLname!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='S')
        const char [] demangleType = "struct " ~ prettyLname!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='E')
        const char [] demangleType = "enum " ~ prettyLname!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='T')
        const char [] demangleType = "typedef " ~ prettyLname!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='D' && str.length>2 && isMangledFunction!(( str[1] )) ) // delegate
        const char [] demangleType = demangleFunctionOrDelegate!(str[1..$], "delegate ", wantQualifiedNames);
    else static if (str[0]=='P' && str.length>2 && isMangledFunction!(( str[1] )) ) // function pointer
        const char [] demangleType = demangleFunctionOrDelegate!(str[1..$], "function ", wantQualifiedNames);
    else static if (str[0]=='P') // only after we've dealt with function pointers
        const char [] demangleType = demangleType!(str[1..$], wantQualifiedNames) ~ "*";
    else static if (isMangledFunction!((str[0])))
        const char [] demangleType = demangleFunctionOrDelegate!(str, "", wantQualifiedNames);
    else const char [] demangleType = demangleBasicType!(str);
}

// split these off because they're numerous and simple
// Note: For portability, could replace "v" with void.mangleof, etc.
template demangleBasicType(char [] str)
{
         static if (str == "v") const char [] demangleBasicType = "void";
    else static if (str == "b") const char [] demangleBasicType = "bool";
    // integral types
    else static if (str == "g") const char [] demangleBasicType = "byte";
    else static if (str == "h") const char [] demangleBasicType = "ubyte";
    else static if (str == "s") const char [] demangleBasicType = "short";
    else static if (str == "t") const char [] demangleBasicType = "ushort";
    else static if (str == "i") const char [] demangleBasicType = "int";
    else static if (str == "k") const char [] demangleBasicType = "uint";
    else static if (str == "l") const char [] demangleBasicType = "long";
    else static if (str == "m") const char [] demangleBasicType = "ulong";
    // floating point
    else static if (str == "e") const char [] demangleBasicType = "real";
    else static if (str == "d") const char [] demangleBasicType = "double";
    else static if (str == "f") const char [] demangleBasicType = "float";

    else static if (str == "j") const char [] demangleBasicType = "ireal";
    else static if (str == "p") const char [] demangleBasicType = "idouble";
    else static if (str == "o") const char [] demangleBasicType = "ifloat";

    else static if (str == "c") const char [] demangleBasicType = "creal";
    else static if (str == "r") const char [] demangleBasicType = "cdouble";
    else static if (str == "q") const char [] demangleBasicType = "cfloat";
    // Char types
    else static if (str == "a") const char [] demangleBasicType = "char";
    else static if (str == "u") const char [] demangleBasicType = "wchar";
    else static if (str == "w") const char [] demangleBasicType = "dchar";

    else static assert(0, "Demangle Error: '" ~ str ~ "' is not a recognised basic type");
}

template isMangledBasicType(char [] str)
{
    const bool isMangledBasicType =    ((str == "v") || (str == "b")
     || (str == "g") || (str == "h") || (str == "s") || (str == "t")
     || (str == "i") || (str == "k") || (str == "l") || (str == "m")
     || (str == "e") || (str == "d") || (str == "f")
     || (str == "j") || (str == "p") || (str == "o")
     || (str == "c") || (str == "r") || (str == "q")
     || (str == "a") || (str == "u") || (str == "w")
    );
}

template demangleTypeConsumed(char [] str)
{
    static if (str[0]=='A')
        const int demangleTypeConsumed = 1 + demangleTypeConsumed!(str[1..$]);
    else static if (str[0]=='H')
        const int demangleTypeConsumed = 1 + demangleTypeConsumed!(str[1..$])
            + demangleTypeConsumed!(str[1+demangleTypeConsumed!(str[1..$])..$]);
    else static if (str[0]=='G')
        const int demangleTypeConsumed = 1 + countLeadingDigits!(str[1..$])
            + demangleTypeConsumed!( str[1+countLeadingDigits!(str[1..$])..$] );
    else static if (str.length>2 && (str[0]=='P' || str[0]=='D') && isMangledFunction!(( str[1] )) )
        const int demangleTypeConsumed = 2 + demangleParamListAndRetValConsumed!(str[2..$]);
    else static if (str[0]=='P') // only after we've dealt with function pointers
        const int demangleTypeConsumed = 1 + demangleTypeConsumed!(str[1..$]);
    else static if (str[0]=='C' || str[0]=='S' || str[0]=='E' || str[0]=='T')
        const int demangleTypeConsumed = 1 + getDotNameConsumed!(str[1..$]);
    else static if (isMangledFunction!((str[0])) && str.length>1)
        const int demangleTypeConsumed = 1 + demangleParamListAndRetValConsumed!(str[1..$]);
    else static if (isMangledBasicType!(str[0..1])) // it's a Basic Type
        const int demangleTypeConsumed = 1;
    else static assert(0, "Demangle Error: '" ~ str ~ "' is not a recognised basic type");
}

// --------------------------------------------
//              LNAMES

// str must start with an Lname: first chars give the length
// reads the digits from the front of str, gets the Lname
// Sometimes the characters following the length are also digits!
// (this happens with templates, when the name being 'lengthed' is itself an Lname).
// We guard against this by ensuring that the L is less than the length of the string.
template extractLname(char [] str)
{
    static if (str.length <= 9+1 || !beginsWithDigit!(str[1..$]) )
        const char [] extractLname = str[1..(str[0]-'0' + 1)];
    else static if (str.length <= 99+2 || !beginsWithDigit!(str[2..$]) )
        const char [] extractLname = str[2..((str[0]-'0')*10 + str[1]-'0'+ 2)];
    else static if (str.length <= 999+3 || !beginsWithDigit!(str[3..$]) )
        const char [] extractLname =
            str[3..((str[0]-'0')*100 + (str[1]-'0')*10 + str[2]-'0' + 3)];
    else
        const char [] extractLname =
            str[4..((str[0]-'0')*1000 + (str[1]-'0')*100 + (str[2]-'0')*10 + (str[3]-'0') + 4)];
}

// str must start with an lname: first chars give the length
// Returns the number of characters used by length digits + the name itself
template getLnameConsumed(char [] str)
{
    static if (str.length==0)
        const int getLnameConsumed=0;
    else static if (str.length <= (9+1) || !beginsWithDigit!(str[1..$]) )
        const int getLnameConsumed = 1 + str[0]-'0';
    else static if (str.length <= (99+2) || !beginsWithDigit!( str[2..$]) )
        const int getLnameConsumed = (str[0]-'0')*10 + str[1]-'0' + 2;
    else static if (str.length <= (999+3) || !beginsWithDigit!( str[3..$]) )
        const int getLnameConsumed = (str[0]-'0')*100 + (str[1]-'0')*10 + str[2]-'0' + 3;
    else
        const int getLnameConsumed = (str[0]-'0')*1000 + (str[1]-'0')*100 + (str[2]-'0')*10 + (str[3]-'0') + 4;
}

// True if str is a continuation of a _D name.
template continues_Dname(char [] str)
{
    static if (str.length>0) {
        const bool continues_Dname = (isMangledFunction!( (str[0])) || beginsWithDigit!(str));
    } else static assert(0);
}

// for an Lname that begins with "_D"
// Special case: if the following type is a function, the D name continues, because
// it's allowed to contain inner functions
template get_DQualifiedNameConsumed (char [] str)
{
    static if ( str.length<1) const int get_DQualifiedNameConsumed = 0;
    else static if ( beginsWithDigit!(str) ) {
        const int get_DQualifiedNameConsumed = getLnameConsumed!(str) + get_DQualifiedNameConsumed!(str[getLnameConsumed!(str)..$]);
    } else static if (isMangledFunction!((str[0]))) {
        static if (demangleTypeConsumed!(str)!=str.length && continues_Dname!(str[demangleTypeConsumed!(str)..$])) {
            const int get_DQualifiedNameConsumed = demangleTypeConsumed!(str) + get_DQualifiedNameConsumed!(str[demangleTypeConsumed!(str)..$]);
        } else const int get_DQualifiedNameConsumed = 0;
    } else static if (str.length>=4 && str[0..4]=="main") {
        const int get_DQualifiedNameConsumed = 4 +  + get_DQualifiedNameConsumed!(str[4..$]);
    }
    else const int get_DQualifiedNameConsumed = 0;
}

// don't display return value.
template prettyInner_DFunc(char [] funcname, char [] functype, MangledNameType wantQualifiedNames)
{
    static if (wantQualifiedNames == MangledNameType.PrettyName) {
        const char [] prettyInner_DFunc = demangleExtern!((functype[0])) ~ prettyDotName!(funcname, wantQualifiedNames) ~ "(" ~ demangleParamList!(functype[1..$], MangledNameType.PrettyName)~ ")";
    } else const char [] prettyInner_DFunc = prettyDotName!(funcname, wantQualifiedNames);
}

template qualifiedAndFuncConsumed(char [] str)
{
    const int qualifiedAndFuncConsumed =
            getDotNameConsumed!(str) + 1 + demangleParamListAndRetValConsumed!(str[1+getDotNameConsumed!(str)..$]);
}

// Deal with the case where an Lname contains an embedded "__D".
// This can happen when classes, typedefs, etc are declared inside a function.
// It always starts with a qualified name, but it may be an inner function.
template pretty_Dname(char [] str, MangledNameType wantQualifiedNames)
{
    static if (getDotNameConsumed!(str)==str.length) {
        const char [] pretty_Dname = prettyDotName!(str, wantQualifiedNames);
    } else static if ( !isMangledFunction!( (str[getDotNameConsumed!(str)]))) {
        static assert(0, "Demangle error, not a qualified name or inner function: " ~ str);
    } else {
        // Inner function
        static if(continues_Dname!(str[qualifiedAndFuncConsumed!(str)..$])) {
            static if (wantQualifiedNames == MangledNameType.SymbolName) {
                const char [] pretty_Dname =
                    pretty_Dname!(str[qualifiedAndFuncConsumed!(str)..$], wantQualifiedNames);
            } else {
                const char [] pretty_Dname =
                    prettyInner_DFunc!(
                        str[0..getDotNameConsumed!(str)],
                        str[getDotNameConsumed!(str)..qualifiedAndFuncConsumed!(str)], wantQualifiedNames
                    )
                    ~ "." ~ pretty_Dname!(str[qualifiedAndFuncConsumed!(str)..$], wantQualifiedNames);
            }
        } else {
            static assert(0);
        }
    }
}

template showTypeWithName(char [] namestr, char [] typestr, MangledNameType wantQualifiedNames)
{
    static if (wantQualifiedNames == MangledNameType.PrettyName) {
        static if ( isMangledFunction!( (typestr[0])) ) {
            const char [] showTypeWithName = demangleReturnValue!(typestr[1..$], wantQualifiedNames)
                ~ " " ~ pretty_Dname!(namestr, wantQualifiedNames)
                ~ "(" ~ demangleParamList!(typestr[1..$], MangledNameType.PrettyName)~ ")";
        } else {
            const char [] showTypeWithName = demangleType!(typestr) ~ " " ~ pretty_Dname!(namestr, wantQualifiedNames);
        }
    } else const char [] showTypeWithName = pretty_Dname!(namestr, wantQualifiedNames);
}

/* Pretty-print a single component of an Lname.
 * A name fragment is one of:
 *  a DotName
 *  a _D extern name
 *  a __T template
 *  an extern(Windows/Pascal/C/C++) symbol
 */
// Templates and _D qualified names are treated specially.
template prettyLname(char [] str, MangledNameType wantQualifiedNames)
{
    static if (str.length>3 && str[0..3] == "__T") // Template instance name
        static if (wantQualifiedNames == MangledNameType.PrettyName) {
            const char [] prettyLname =
                prettyLname!(str[3..3+getDotNameConsumed!(str[3..$])], wantQualifiedNames) ~ "!("
                ~ prettyTemplateArgList!(str[3+getDotNameConsumed!(str[3..$])..$], wantQualifiedNames)
                ~ ")";
        } else {
            const char [] prettyLname =
                prettyLname!(str[3..3+getDotNameConsumed!(str[3..$])], wantQualifiedNames);
        }
    else static if (str.length>2 && str[0..2] == "_D") {
        static if (2+get_DQualifiedNameConsumed!(str[2..$])== str.length) {
            // it's just a name
            const char [] prettyLname = pretty_Dname!(str[2..2+get_DQualifiedNameConsumed!(str[2..$])], wantQualifiedNames);
        } else { // it has type information following
            const char [] prettyLname = showTypeWithName!(str[2..2+get_DQualifiedNameConsumed!(str[2..$])], str[2+get_DQualifiedNameConsumed!(str[2..$])..$], wantQualifiedNames);
        }
    } else static if ( beginsWithDigit!( str ) ) {
        static if (getDotNameConsumed!(str)==str.length) {
            const char [] prettyLname = prettyDotName!(str, wantQualifiedNames);
        } else static assert(0, "Demangle Error: Unexpected " ~ str);
    } else {
         // For extern(Pascal/Windows/C) functions.
         // BUG: This case is ambiguous, since type information is lost.
        const char [] prettyLname = str;
    }
}

// a DotName is a sequence of Lnames, seperated by dots.
template prettyDotName(char [] str, MangledNameType wantQualifiedNames, char [] dotstr = "")
{
    static if (str.length==0) const char [] prettyDotName="";
    else static if (str.length>=4 && str[0..4]=="main") {
            static if (wantQualifiedNames == MangledNameType.SymbolName) {
                // For symbol names, only display the last symbol
                const char [] prettyDotName =
                    prettyDotName!(str[4 .. $], wantQualifiedNames, "");
            } else {
                // Qualified and pretty names display everything
                const char [] prettyDotName = dotstr
                    ~ "main"
                    ~ prettyDotName!(str[4 .. $], wantQualifiedNames, ".");
            }
    } else {
        static assert (beginsWithDigit!(str));
        static if ( getLnameConsumed!(str) < str.length && beginsWithDigit!(str[getLnameConsumed!(str)..$]) ) {
            static if (wantQualifiedNames == MangledNameType.SymbolName) {
                // For symbol names, only display the last symbol
                const char [] prettyDotName =
                    prettyDotName!(str[getLnameConsumed!(str) .. $], wantQualifiedNames, "");
            } else {
                // Qualified and pretty names display everything
                const char [] prettyDotName = dotstr
                    ~ prettyLname!(extractLname!(str), wantQualifiedNames)
                    ~ prettyDotName!(str[getLnameConsumed!(str) .. $], wantQualifiedNames, ".");
            }
        } else {
            static assert(getLnameConsumed!(str)==str.length, "Demangle error: Unexpected "~ str[getLnameConsumed!(str) .. $]);
            const char [] prettyDotName = dotstr ~ prettyLname!(extractLname!(str), wantQualifiedNames);
        }
    }
}

template getDotNameConsumed (char [] str)
{
    static if ( str.length>1 &&  beginsWithDigit!(str) ) {
        static if (getLnameConsumed!(str) < str.length && beginsWithDigit!( str[getLnameConsumed!(str)..$])) {
            const int getDotNameConsumed = getLnameConsumed!(str)
                + getDotNameConsumed!(str[getLnameConsumed!(str) .. $]);
        } else {
            const int getDotNameConsumed = getLnameConsumed!(str);
        }
    } else static if (str.length>1 && str[0..2] == "_D" ) {
        const int getDotNameConsumed = 2+get_DQualifiedNameConsumed!(str[2..$]);
    } else static if (str.length>=4 && str[0..4] == "main") {
        const int getDotNameConsumed = 4+get_DQualifiedNameConsumed!(str[4..$]);
    } else static assert(0, "Error in Dot name:" ~ str);
}

// ----------------------------------------
//              FUNCTIONS

/* str[0] must indicate the extern linkage of the function. funcOrDelegStr is the name of the function,
* or "function " or "delegate "
*/
template demangleFunctionOrDelegate(char [] str, char [] funcOrDelegStr, MangledNameType wantQualifiedNames)
{
    const char [] demangleFunctionOrDelegate = demangleExtern!(( str[0] ))
        ~ demangleReturnValue!(str[1..$], wantQualifiedNames)
        ~ " " ~ funcOrDelegStr ~ "("
        ~ demangleParamList!(str[1..1+demangleParamListAndRetValConsumed!(str[1..$])], wantQualifiedNames)
        ~ ")";
}

// Special case: types that are in function parameters
// For function parameters, the type can also contain 'lazy', 'out' or 'inout'.
template demangleFunctionParamType(char[] str, MangledNameType wantQualifiedNames)
{
    static if (str[0]=='L')
        const char [] demangleFunctionParamType = "lazy " ~ demangleType!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='K')
        const char [] demangleFunctionParamType = "inout " ~ demangleType!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='J')
        const char [] demangleFunctionParamType = "out " ~ demangleType!(str[1..$], wantQualifiedNames);
    else const char [] demangleFunctionParamType = demangleType!(str, wantQualifiedNames);
}

// Deal with 'out','inout', and 'lazy' parameters
template demangleFunctionParamTypeConsumed(char[] str)
{
    static if (str[0]=='K' || str[0]=='J' || str[0]=='L')
        const int demangleFunctionParamTypeConsumed = 1 + demangleTypeConsumed!(str[1..$]);
    else const int demangleFunctionParamTypeConsumed = demangleTypeConsumed!(str);
}

// Return true if c indicates a function. As well as 'F', it can be extern(Pascal), (C), (C++) or (Windows).
template isMangledFunction(char c)
{
    const bool isMangledFunction = (c=='F' || c=='U' || c=='W' || c=='V' || c=='R');
}

template demangleExtern(char c)
{
    static if (c=='F') const char [] demangleExtern = "";
    else static if (c=='U') const char [] demangleExtern = "extern (C) ";
    else static if (c=='W') const char [] demangleExtern = "extern (Windows) ";
    else static if (c=='V') const char [] demangleExtern = "extern (Pascal) ";
    else static if (c=='R') const char [] demangleExtern = "extern (C++) ";
    else static assert(0, "Unrecognized extern function.");
}

// Skip through the string until we find the return value. It can either be Z for normal
// functions, or Y for vararg functions, or X for lazy vararg functions.
template demangleReturnValue(char [] str, MangledNameType wantQualifiedNames)
{
    static assert(str.length>=1, "Demangle error(Function): No return value found");
    static if (str[0]=='Z' || str[0]=='Y' || str[0]=='X')
        const char[] demangleReturnValue = demangleType!(str[1..$], wantQualifiedNames);
    else const char [] demangleReturnValue = demangleReturnValue!(str[demangleFunctionParamTypeConsumed!(str)..$], wantQualifiedNames);
}

// Stop when we get to the return value
template demangleParamList(char [] str, MangledNameType wantQualifiedNames, char[] commastr = "")
{
    static if (str[0] == 'Z')
        const char [] demangleParamList = "";
    else static if (str[0] == 'Y')
        const char [] demangleParamList = commastr ~ "...";
    else static if (str[0]=='X') // lazy ...
        const char[] demangleParamList = commastr ~ "...";
    else
        const char [] demangleParamList =  commastr ~
            demangleFunctionParamType!(str[0..demangleFunctionParamTypeConsumed!(str)], wantQualifiedNames)
            ~ demangleParamList!(str[demangleFunctionParamTypeConsumed!(str)..$], wantQualifiedNames, ", ");
}

// How many characters are used in the parameter list and return value?
template demangleParamListAndRetValConsumed(char [] str)
{
    static assert (str.length>0, "Demangle error(ParamList): No return value found");
    static if (str[0]=='Z' || str[0]=='Y' || str[0]=='X')
        const int demangleParamListAndRetValConsumed = 1 + demangleTypeConsumed!(str[1..$]);
    else {
        const int demangleParamListAndRetValConsumed = demangleFunctionParamTypeConsumed!(str)
            + demangleParamListAndRetValConsumed!(str[demangleFunctionParamTypeConsumed!(str)..$]);
    }
}

// --------------------------------------------
//              TEMPLATES

// Pretty-print a template argument
template prettyTemplateArg(char [] str, MangledNameType wantQualifiedNames)
{
    static if (str[0]=='S') // symbol name
        const char [] prettyTemplateArg = prettyLname!(str[1..$], wantQualifiedNames);
    else static if (str[0]=='V') // value
        const char [] prettyTemplateArg =
            demangleType!(str[1..1+demangleTypeConsumed!(str[1..$])], wantQualifiedNames)
            ~ " = " ~ prettyValueArg!(str[1+demangleTypeConsumed!(str[1..$])..$]);
    else static if (str[0]=='T') // type
        const char [] prettyTemplateArg = demangleType!(str[1..$], wantQualifiedNames);

    else static assert(0, "Unrecognised template argument type: {" ~ str ~ "}");
}

template templateArgConsumed(char [] str)
{
    static if (str[0]=='S') // symbol name
        const int templateArgConsumed = 1 + getLnameConsumed!(str[1..$]);
    else static if (str[0]=='V') // value
        const int templateArgConsumed = 1 + demangleTypeConsumed!(str[1..$]) +
            templateValueArgConsumed!(str[1+demangleTypeConsumed!(str[1..$])..$]);
    else static if (str[0]=='T') // type
        const int templateArgConsumed = 1 + demangleTypeConsumed!(str[1..$]);
    else static assert(0, "Unrecognised template argument type: {" ~ str ~ "}");
}

// Like function parameter lists, template parameter lists also end in a Z,
// but they don't have a return value at the end.
template prettyTemplateArgList(char [] str, MangledNameType wantQualifiedNames, char [] commastr="")
{
    static if (str[0]=='Z')
        const char[] prettyTemplateArgList = "";
    else
       const char [] prettyTemplateArgList = commastr
            ~ prettyTemplateArg!(str[0..templateArgConsumed!(str)], wantQualifiedNames)
            ~ prettyTemplateArgList!(str[templateArgConsumed!(str)..$], wantQualifiedNames, ", ");
}

template templateArgListConsumed(char [] str)
{
    static assert(str.length>0, "No Z found at end of template argument list");
    static if (str[0]=='Z')
        const int templateArgListConsumed = 1;
    else
        const int templateArgListConsumed = templateArgConsumed!(str)
            + templateArgListConsumed!(str[templateArgConsumed!(str)..$]);
}


template templateValueArgConsumed(char [] str)
{
    static if (str[0]=='n') const int templateValueArgConsumed = 1;
    else static if (beginsWithDigit!(str)) const int templateValueArgConsumed = countLeadingDigits!(str);
    else static if (str[0]=='N') const int templateValueArgConsumed = 1 + countLeadingDigits!(str[1..$]);
    else static if (str[0]=='e') const int templateValueArgConsumed = 1 + 20;
    else static if (str[0]=='c') const int templateValueArgConsumed = 1 + 40;
    else static assert(0, "Unknown character in template value argument:" ~ str);
}

// pretty-print a template value argument.
template prettyValueArg(char [] str)
{
    static if (str[0]=='n') const char [] prettyValueArg = "null";
    else static if (beginsWithDigit!(str)) const char [] prettyValueArg = str;
    else static if ( str[0]=='N') const char [] prettyValueArg = "-" ~ str[1..$];
    else static if ( str[0]=='e') const char [] prettyValueArg = prettyFloatValueArg!(str[1..$]);
    else static if ( str[0]=='c') const char [] prettyValueArg = prettyFloatValueArg!(str[1..22]) ~ " + " ~ prettyFloatValueArg!(str[21..41]) ~ "i";
    else const char [] prettyValueArg = "Value arg {" ~ str[0..$] ~ "}";
}

// --------------------------------------------
// Template float value arguments

private {
// Float value arguments are are mangled big-endian within a byte, but the bytes
// are mangled in little-endian order (!)
template bigEndianHexToShort(char [] str)
{
    const int bigEndianHexToShort = hexCharToInteger!((str[0]))*16 + hexCharToInteger!((str[1]))
    + 256 *(hexCharToInteger!((str[2]))*16 + hexCharToInteger!((str[3])));
}

template getMangleFloatDigits(char [] str)
{
    // Multiply by 2 to ignore the implicit bit.
    const ulong getMangleFloatDigits =
     (bigEndianHexToShort!(str[12..16])&0x7FFF)* 0x2_0000_0000_0000L
    + bigEndianHexToShort!(str[8..12]) * 0x2_0000_0000L
    + bigEndianHexToShort!(str[4..8])  * 0x2_0000L
    + bigEndianHexToShort!(str[0..4])  * 2;
}

// Display the floating point number in %a format (eg 0x1.ABCp-35);
template prettyFloatValueArg(char [] str)
{
    const char [] prettyFloatValueArg = rawFloatToHexString!(bigEndianHexToShort!(str[16..$]), getMangleFloatDigits!(str[0..16]));
}

}

// --------------------------------------------
//              UNIT TESTS

debug(UnitTest){

private {

const char [] THISFILE = "tango.meta.Demangle";

ireal SomeFunc(ushort u) { return -3i; }
idouble SomeFunc2(inout ushort u, ubyte w) { return -3i; }
byte[] SomeFunc3(out dchar d, ...) { return null; }
ifloat SomeFunc4(lazy void[] x...) { return 2i; }
char[dchar] SomeFunc5(lazy int delegate()[] z...);

extern (Windows) {
    typedef void function (double, long) WinFunc;
}
extern (Pascal) {
    typedef short[wchar] delegate (bool, ...) PascFunc;
}
extern (C) {
    typedef dchar delegate () CFunc;
}
extern (C++) {
    typedef cfloat function (wchar) CPPFunc;
}

interface SomeInterface {}

static assert( demangleType!((&SomeFunc).mangleof) == "ireal function (ushort)" );
static assert( demangleType!((&SomeFunc2).mangleof) == "idouble function (inout ushort, ubyte)");
static assert( demangleType!((&SomeFunc3).mangleof) == "byte[] function (out dchar, ...)");
static assert( demangleType!((&SomeFunc4).mangleof) == "ifloat function (lazy void[], ...)");
static assert( demangleType!((&SomeFunc5).mangleof) == "char[dchar] function (lazy int delegate ()[], ...)");
static assert( demangleType!((WinFunc).mangleof)== "extern (Windows) void function (double, long)");
static assert( demangleType!((PascFunc).mangleof) == "extern (Pascal) short[wchar] delegate (bool, ...)");
static assert( demangleType!((CFunc).mangleof) == "extern (C) dchar delegate ()");
static assert( demangleType!((CPPFunc).mangleof) == "extern (C++) cfloat function (wchar)");
// Interfaces are mangled as classes
static assert( demangleType!(SomeInterface.mangleof) == "class " ~ THISFILE ~ ".SomeInterface");


template ComplexTemplate(real a, creal b)
{
    class ComplexTemplate {}
}

static assert( demangleType!((ComplexTemplate!(-0x1.23456789ABCDFFFEp-456, 0x1p-16390L-3.2i)).mangleof) == "class " ~ THISFILE ~ ".ComplexTemplate!(double = -0x1.23456789ABCDFFFEp-456, creal = 0x0.0100000000000000p-16383 + -0x1.999999999999999Ap+1i).ComplexTemplate");

}
}

