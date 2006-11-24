/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: December 2005      
        
        author:         Kris

*******************************************************************************/

module tango.text.convert.UnicodeBom;

private import  tango.core.ByteSwap;

private import  tango.text.convert.Utf,
                tango.text.convert.Type;


/*******************************************************************************

        see http://icu.sourceforge.net/docs/papers/forms_of_unicode/#t2

*******************************************************************************/

enum Encoding {
              Unknown,
              UTF_8,
              UTF_8N,
              UTF_16,
              UTF_16BE,
              UTF_16LE,
              UTF_32,
              UTF_32BE,
              UTF_32LE,
              };

/*******************************************************************************

        Convert unicode content

        Unicode is an encoding of textual material. The purpose of this module 
        is to interface external-encoding with a programmer-defined internal-
        encoding. This internal encoding is declared via the template argument 
        T, whilst the external encoding is either specified or derived.

        Three internal encodings are supported: char, wchar, and dchar. The
        methods herein operate upon arrays of this type. That is, decode()
        returns an array of the type, while encode() expect an array of said 
        type.

        Supported external encodings are as follow:

                Encoding.Unknown 
                Encoding.UTF_8
                Encoding.UTF_8N
                Encoding.UTF_16
                Encoding.UTF_16BE
                Encoding.UTF_16LE 
                Encoding.UTF_32 
                Encoding.UTF_32BE
                Encoding.UTF_32LE 

        These can be divided into non-explicit and explicit encodings:

                Encoding.Unknown 
                Encoding.UTF_8
                Encoding.UTF_16
                Encoding.UTF_32 


                Encoding.UTF_8N
                Encoding.UTF_16BE
                Encoding.UTF_16LE 
                Encoding.UTF_32BE
                Encoding.UTF_32LE 
        
        The former group of non-explicit encodings may be used to 'discover'
        an unknown encoding, by examining the first few bytes of the content
        for a signature. This signature is optional, but is often written such 
        that the content is self-describing. When an encoding is unknown, using 
        one of the non-explicit encodings will cause the decode() method to look 
        for a signature and adjust itself accordingly. It is possible that a 
        ZWNBSP character might be confused with the signature; today's unicode 
        content is supposed to use the WORD-JOINER character instead.
       
        The group of explicit encodings are for use when the content encoding 
        is known. These *must* be used when converting back to external encoding, 
        since written content must be in a known format. It should be noted that, 
        during a decode() operation, the existence of a signature is in conflict 
        with these explicit varieties.


        See 
        $(LINK http://www.utf-8.com/)
        $(LINK http://www.hackcraft.net/xmlUnicode/)
        $(LINK http://www.unicode.org/faq/utf_bom.html/)
        $(LINK http://www.azillionmonkeys.com/qed/unicode.html/)
        $(LINK http://icu.sourceforge.net/docs/papers/forms_of_unicode/)

*******************************************************************************/

class UnicodeBom(T) 
{
        private alias tango.text.convert.Utf Utf;

        static if (!is (T == char) && !is (T == wchar) && !is (T == dchar)) 
                    pragma (msg, "Template type must be char, wchar, or dchar");


        private Encoding encoding;      // the current encoding
        private Info*    settings;      // pointer to encoding configuration

        private struct  Info
                {
                int      type;          // type of element (char/wchar/dchar)
                Encoding encoding;      // Encoding.xx encoding
                char[]   bom;           // pattern to match for signature
                bool     test,          // should we test for this encoding?
                         endian,        // this encoding have endian concerns?
                         bigEndian;     // is this a big-endian encoding?
                Encoding fallback;      // can this encoding be defaulted?
                };


        private const Info[] lookup =
        [
        {Type.Utf8,  Encoding.Unknown,  null,        true,  false, false, Encoding.UTF_8N},
        {Type.Utf8,  Encoding.UTF_8,    null,        true,  false, false, Encoding.UTF_8N},
        {Type.Utf8,  Encoding.UTF_8N,   x"efbbbf",   false},
        {Type.Utf16, Encoding.UTF_16,   null,        true,  false, false, Encoding.UTF_16BE},
        {Type.Utf16, Encoding.UTF_16BE, x"feff",     false, true, true},
        {Type.Utf16, Encoding.UTF_16LE, x"fffe",     false, true},
        {Type.Utf32, Encoding.UTF_32,   null,        true,  false, false, Encoding.UTF_32BE},
        {Type.Utf32, Encoding.UTF_32BE, x"0000feff", false, true, true},
        {Type.Utf32, Encoding.UTF_32LE, x"fffe0000", false, true},
        ];


        /***********************************************************************
        
                Construct a instance using the given external encoding ~ one 
                of the Encoding.xx types 

        ***********************************************************************/
                                  
        this (Encoding encoding)
        {
                setup (encoding);
        }
        
        /***********************************************************************

                Return the current encoding. This is either the originally
                specified encoding, or a derived one obtained by inspecting
                the content for a BOM. The latter is performed as part of 
                the decode() method

        ***********************************************************************/

        final Encoding getEncoding ()
        {
                return encoding;
        }
        
        /***********************************************************************

                Return the signature (BOM) of the current encoding

        ***********************************************************************/

        final void[] getSignature ()
        {
                return settings.bom;
        }

        /***********************************************************************

                Convert the provided content. The content is inspected 
                for a BOM signature, which is stripped. An exception is
                thrown if a signature is present when, according to the
                encoding type, it should not be. Conversely, An exception
                is thrown if there is no known signature where the current
                encoding expects one to be present

        ***********************************************************************/

        final T[] decode (void[] content, T[] dst=null)
        {
                // look for a BOM
                auto info = test (content);

                // are we expecting a BOM?
                if (lookup[encoding].test)
                    if (info)
                       {
                       // yep ~ and we got one
                       setup (info.encoding);

                       // strip BOM from content
                       content = content [info.bom.length .. length];
                       }
                    else
                       // can this encoding be defaulted?
                       if (settings.fallback)
                           setup (settings.fallback);
                       else
                          onUnicodeError ("UnicodeBom.decode :: unknown or missing BOM");
                else
                   if (info)
                       // found a BOM when using an explicit encoding
                       onUnicodeError ("UnicodeBom.decode :: explicit encoding does not permit BOM");   
                
                // convert it to internal representation
                return into (swapBytes(content), settings.type, dst);
        }

        /***********************************************************************

                Perform encoding of content. Note that the encoding must be 
                of the explicit variety by the time we get here

        ***********************************************************************/

        final void[] encode (T[] content, void[] dst=null)
        {
                if (settings.test)
                    onUnicodeError ("UnicodeBom.encode :: cannot write to a non-specific encoding");

                // convert it to external representation, and write
               return swapBytes (from (content, settings.type, dst));
        }

        /***********************************************************************

                Scan the BOM signatures looking for a match. We scan in 
                reverse order to get the longest match first

        ***********************************************************************/

        private final Info* test (void[] content)
        {
                for (Info* info=lookup.ptr+lookup.length; --info >= lookup;)
                     if (info.bom)
                        {
                        int len = info.bom.length;
                        if (len <= content.length)
                            if (content[0..len] == info.bom[0..len])
                                return info;
                        }
                return null;
        }
        
        /***********************************************************************

                Swap bytes around, as required by the encoding

        ***********************************************************************/

        private final void[] swapBytes (void[] content)
        {
                bool endian = settings.endian;
                bool swap   = settings.bigEndian;

                version (BigEndian)
                         swap = !swap;

                if (endian && swap)
                   {
                   if (settings.type == Type.Utf16)
                       ByteSwap.swap16 (content, content.length);
                   else
                       ByteSwap.swap32 (content, content.length);
                   }
                return content;
        }

        /***********************************************************************

                Configure this instance with unicode converters

        ***********************************************************************/

        public final void setup (Encoding encoding)
        {
                this.settings = &lookup[encoding];
                this.encoding = encoding;
        }
        
        /***********************************************************************
      

        ***********************************************************************/

        static T[] into (void[] x, uint type, T[] dst=null)
        {
                T[] ret;

                static if (is (T == char))
                          {
                          if (type == Type.Utf8)
                              return cast(T[]) x;

                          if (type == Type.Utf16)
                              ret = Utf.toUtf8 (cast(wchar[]) x, dst);
                          else
                          if (type == Type.Utf32)
                              ret = Utf.toUtf8 (cast(dchar[]) x, dst);
                          }

                static if (is (T == wchar))
                          {
                          if (type == Type.Utf16)
                              return cast(T[]) x;

                          if (type == Type.Utf8)
                              ret = Utf.toUtf16 (cast(char[]) x, dst);
                          else
                          if (type == Type.Utf32)
                              ret = Utf.toUtf16 (cast(dchar[]) x, dst);
                          }

                static if (is (T == dchar))
                          {
                          if (type == Type.Utf32)
                              return cast(T[]) x;

                          if (type == Type.Utf8)
                              ret = Utf.toUtf32 (cast(char[]) x, dst);
                          else
                          if (type == Type.Utf16)
                              ret = Utf.toUtf32 (cast(wchar[]) x, dst);
                          }

                return ret;
        }


        /***********************************************************************

        ***********************************************************************/

        static void[] from (T[] x, uint type, void[] dst=null)
        {
                void[] ret;

                static if (is (T == char))
                          {
                          if (type == Type.Utf8)
                              return x;

                          if (type == Type.Utf16)
                              ret = Utf.toUtf16 (x, cast(wchar[]) dst);
                          else
                          if (type == Type.Utf32)
                              ret = Utf.toUtf32 (x, cast(dchar[]) dst);
                          }

                static if (is (T == wchar))
                          {
                          if (type == Type.Utf16)
                              return x;

                          if (type == Type.Utf8)
                              ret = Utf.toUtf8 (x, cast(char[]) dst);
                          else
                          if (type == Type.Utf32)
                              ret = Utf.toUtf32 (x, cast(dchar[]) dst);
                          }

                static if (is (T == dchar))
                          {
                          if (type == Type.Utf32)
                              return x;

                          if (type == Type.Utf8)
                              ret = Utf.toUtf8 (x, cast(char[]) dst);
                          else
                          if (type == Type.Utf16)
                              ret = Utf.toUtf16 (x, cast(wchar[]) dst);
                          }

                return ret;
        }
}

