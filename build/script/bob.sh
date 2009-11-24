#!/bin/bash

# A simple script to build libtango
# Copyright (C) 2007-2009  Lars Ivar Igesund
# Permission is granted to do anything you please with this software.
# This software is provided with no warranty, express or implied, within the
# bounds of applicable law.

die() {
    echo "$1"
    exit $2
}

DC=
LIB=

usage() {
    echo 'Usage: build-tango.sh <options> identifier
Options:
  --help: Will print this help text
  --noinline: Will turn off inlining
  --norelease: Drops optimzations
  --debug: Will enable debug info
  --warn: Will enable warnings
  --verbose: Increase verbosity 
  --user: Just user portion of library
  --runtime: Just runtime portion of library
  <identifier> is one of {dmd, gdc, ldc, mac} and will build libtango.a,
                libgtango.a or universal Mac binaries respectively

  Without --user or --runtime, both will be built into the library.
    '
    exit 0
}

UNAME=`uname`
ARCH=""
INLINE="-inline"
POSIXFLAG=""
DEBUG=""
RELEASE="-release -O"
WARN=""
VERBOSE=0
USER=0
RUNTIME=0
USERLIB=""
RTLIB=""
GCC32="-m32"
GCCRELEASE="-O3"

pushd `dirname $0`
# Compiler specific includes
. dmdinclude

# Checks for known compiler bugs
compilerbugs() {
    if [ "$DC" = "dmd" ]
    then
        dmdbugs
    fi
}

# Sets up settings for specific compiler versions
compilersettings() {
    if [ "$DC" = "dmd" ]
    then
        dmdsettings
    fi
}

# This filter can probably be improved quite a bit, but should work
# on the supported platforms as of April 2008
filter() {

    FILE=$1

    if [ "`echo $FILE | grep core.rt`" ]
    then
        if [ $RUNTIME == 0 ]
        then
            return 1
        fi
    else
        if [ $USER == 0 ]
        then
            return 1
        fi
    fi

    if [ "`echo $FILE | grep dmd`" -a ! "$DC" == "dmd" ]
    then
        return 1
    fi

    if [ "`echo $FILE | grep ldc`" -a ! "$DC" == "ldc" ]
    then
        return 1
    fi

    if [ "`echo $FILE | grep gdc`" -a ! "$DC" == "gdc" ]
    then
        return 1
    fi

    if [ "`echo $FILE | grep win32`" -o "`echo $FILE | grep Win32`" -o "`echo $FILE | grep windows`" ]
    then
        return 1
    fi

    if [ "`echo $FILE | grep darwin`" ]
    then
        if [ ! "$UNAME" == "Darwin" ]
        then
            return 1
        else
            return 0
        fi
    fi

    if [ "`echo $FILE | grep freebsd`" ]
    then
        if [ ! "$UNAME" == "FreeBSD" ]
        then
            return 1
        else
            return 0
        fi
    fi

    if [ "`echo $FILE | grep linux`" ]
    then
        if [ ! "$UNAME" == "Linux" ]
        then
            return 1
        fi
    fi

    return 0
}

# Compile the object files
compile() {
    FILENAME=$1
    OBJNAME=`echo $1 | sed -e 's/\.d//' | sed -e 's/\//\./g'`
    OBJNAME=${OBJNAME}.o

    if filter $OBJNAME 
    then
        if [ $VERBOSE == 1 ]; then echo "[$DC] $FILENAME"; fi
        $DC $ARCH $WARN -c $INLINE $DEBUG $RELEASE $POSIXFLAG -I. -Itango/core -version=Tango -of$OBJNAME $FILENAME
        if [ "$?" != 0 ]
        then
            return 1;
        fi
        ar -r $LIB $OBJNAME 2>&1 | grep -v "ranlib: .* has no symbols"
        rm $OBJNAME
    fi
}

compileGcc() {
    FILENAME=$1
    OBJNAME=`echo $1 | sed -e 's/\.c|\.S//' | sed -e 's/\//\./g'`
    OBJNAME=${OBJNAME}.o

    if filter $OBJNAME 
    then
        if [ $VERBOSE == 1 ]; then echo "[GCC] $FILENAME"; fi
        gcc -c $GCC32 $GCCRELEASE -o$OBJNAME $FILENAME
        if [ "$?" != 0 ]
        then
            return 1;
        fi
        ar -r $LIB $OBJNAME 2>&1 | grep -v "ranlib: .* has no symbols"
        rm $OBJNAME
    fi

}

# Build the libraries
build() {

    DC=$1
    LIB=$2
    
    echo Building $LIB

    if [ $RUNTIME == 0 -a $USER == 0 ]
    then
        RUNTIME=1
        USER=1
    fi

    if ! which $DC >& /dev/null
    then
        echo "$DC not found on your \$PATH!"
        return
    fi

    if [ $DC == "gdc" ]
    then
        echo Runtime build for gdc not currently supported, disabling.
        RUNTIME=0
    fi

    # Check if the compiler used has known bugs
    compilerbugs
    # Setup compiler specific settings
    compilersettings

    cd ../..
    echo compiler call: $DC $ARCH $WARN -c $INLINE $DEBUG $RELEASE $POSIXFLAG -version=Tango

    for file in `find tango -name '*.d'`
    do
        compile $file
        if [ "$?" = 1 ]
        then
            die "Compilation of $file failed" 1 
        fi
    done
    for file in `find tango -name '*.c' -o -name '*.S'`
    do
        compileGcc $file
        if [ "$?" = 1 ]
        then
            die "Compilation of $file failed" 1 
        fi
    done

    ranlib $LIB 2>&1 | grep -v "ranlib: .* has no symbols"

    popd

    echo Built $LIB
}

if [ "$#" == "0" ]
then
    usage
fi

while [ "$#" != "0" ]
do
    case "$1" in
        --help)
            usage
            ;;
        --warn)
            WARN="-w"
            ;;
        --debug)
            DEBUG="-g -debug"
            ;;
        --norelease)
            RELEASE=""
            ;;
        --test)
            RELEASE="-unittest -d -debug=UnitTest"
#            RELEASE="-release -O -d-debug=UnitTest"
	    ;;
        --noinline)
            INLINE=""
            ;;
        --verbose) 
            VERBOSE=1
            ;;
        --user)
            USER=1
            USERLIB="-user"
            ;;
        --runtime)
            RUNTIME=1
            RTLIB="-base"
            ;;
        dmd)
            build dmd libtango$USERLIB$RTLIB-dmd.a
            ;;
        gdc)
            POSIXFLAG="-version=Posix"
            build gdmd libgtango.a
            ;;
        ldc)
            build ldmd libtango$USERLIB$RTLIB-ldc.a
            ;;
        mac)
            POSIXFLAG="-version=Posix"
            # build Universal Binary version of the Tango library
            ARCH="-arch ppc"
            build gdmd libgtango.a.ppc libgphobos.a.ppc
            ARCH="-arch i386"
            build gdmd libgtango.a.i386 libgphobos.a.i386   
            ARCH="-arch ppc64"
            build gdmd libgtango.a.ppc64 libgphobos.a.ppc64 
            ARCH="-arch x86_64"
            build gdmd libgtango.a.x86_64 libgphobos.a.x86_64
            lipo -create -output libgtango.a libgtango.a.ppc libgtango.a.i386 \
                                             libgtango.a.ppc64 libgtango.a.x86_64 
            ;;
        *)
            usage
            ;;
    esac
    shift
done