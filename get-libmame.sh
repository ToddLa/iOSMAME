#!/bin/sh

##
## get-libmame.sh [target] [source]
##
## get version of libmame from MAME project, or the web
##
## target is one of the following
##      ios     get libmame-ios.a for iOS
##      tvos    get libmame-tvos.a for tvOS
##      mac     get libmame.a for Catalyst
##      all     get all
##
## source is path to MAME project or blank for default (../MAME)
##

if [ "$1" == "" ]; then
    $0 ios $2
    exit
fi

if [ "$1" == "all" ]; then
    $0 ios $2
    $0 tvos $2
    $0 mac $2
    exit
fi

LIBMAME="libmame-$1.a"

if [ "$2" != "" ] && [ -f "$2/$LIBMAME" ]; then
    echo COPY "$2/$LIBMAME"
    cp "$2/$LIBMAME" .
    exit
fi

if [ -f "../MAME/$LIBMAME" ]; then
    echo COPY "../MAME/$LIBMAME"
    cp "../MAME/$LIBMAME" .
    exit
fi

if [ -f "../MAME4iOS/$LIBMAME" ]; then
    echo COPY "../MAME4iOS/$LIBMAME"
    cp "../MAME4iOS/$LIBMAME" .
    exit
fi

echo "USAGE: $0 [ios | tvos | mac | all] [source]"

