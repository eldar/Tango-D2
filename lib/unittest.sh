#!/usr/bin/env bash

# A simple script to build unittests for on posix for dmd/gdc
# Copyright (C) 2007  Lars Ivar Igesund
# Permission is granted to do anything you please with this software.
# This software is provided with no warranty, express or implied, within the
# bounds of applicable law.


die() {
    echo "$1"
    exit $2
}

usage() {
    echo 'Usage: ./unittest.sh [otions ...]
Options:
  --help: This message
  --run-all: Reports result instead of breaking. Do not use this if you want to
         run unittest runner through a debugger.
  dmd: Builds unittests for dmd
  gdc: Builds unittests for gdc

  <none>: Builds unittests for all known compilers.'
  exit 0
}

DC=
LIB=
RUNALL=

compile() {

    DC=$1
    EXE=$2

    rebuild --help >& /dev/null || die "rebuild required, aborting" 1

    if ! $DC --help >& /dev/null
    then
        echo "$DC not found on your \$PATH!"
    else
        cd ..

        cat > $EXE.d <<EOF
module ${EXE};

import tango.io.Stdout;
import tango.core.Runtime;

bool tangoUnitTester()
{
    uint count = 0;
    Stdout ("NOTE: This is still fairly rudimentary, and will only report the").newline;
    Stdout ("    first error per module.").newline;
    foreach ( m; ModuleInfo )  // _moduleinfo_array )
    {
        if ( m.unitTest) {
            Stdout.format ("{}. Executing unittests in '{}' ", count, m.name);
            try {
               m.unitTest();
            }
            catch (Exception e) {
                Stdout(" - Unittest failed.").newline;
                Stdout.format("   File '{}', line '{}'.", e.file, e.line).newline;
                Stdout.format("     Message is : '{}'", e.msg).newline;
                if (e.info)
                    Stdout.format("     TraceInfo: {}", e.info.toString).newline;
                continue;
            }
            Stdout(" - Success.").newline;
            count++;
        }
    }
    return true;
}

static this() {
    $RUNALL    
}

void main() {}
EOF

        rebuild -w -d -g -L-ldl -L-lz -debug=UnitTest -debug -full -clean -unittest -version=UnitTest $EXE.d tango/core/*.d tango/io/digest/*.d tango/io/model/*.d tango/io/protocol/*.d tango/io/selector/*.d tango/io/*.d tango/io/vfs/*.d tango/io/vfs/model/* tango/math/*.d tango/net/ftp/*.d tango/net/http/*.d tango/net/model/*.d tango/stdc/stringz.d tango/sys/*.d tango/text/convert/*.d tango/text/locale/Collation.d tango/text/locale/Convert.d tango/text/locale/Core.d tango/text/locale/Data.d tango/text/locale/Locale.d tango/text/locale/Parse.d tango/text/locale/Posix.d tango/text/stream/*.d tango/text/*.d tango/util/*.d tango/util/collection/model/*.d tango/util/collection/*.d tango/util/collection/iterator/*.d tango/util/collection/impl/*.d tango/util/log/model/*.d tango/util/log/*.d tango/time/chrono/*.d tango/time/*.d -dc=$DC-posix-tango

        mv $EXE lib/$EXE
        rm $EXE.d

        cd lib/
    fi

}

while [ "$#" != "0" ]
do
    case "$1" in
        --help)
            usage
            ;;
        --run-all)
            RUNALL="Runtime.moduleUnitTester( &tangoUnitTester );"
            ;;
        dmd)
            DMD=1
            ;;
        gdc)
            GDC=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done

if [ ! "$DMD" -a ! "$GDC" ]
then
    DMD=1
    GDC=1
fi

if [ "$DMD" = "1" ]
then
    compile dmd runUnitTest_dmd
fi
if [ "$GDC" = "1" ]
then
    compile gdc runUnitTest_gdc
fi

