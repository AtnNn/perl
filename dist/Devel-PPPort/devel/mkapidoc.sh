#!/bin/bash
################################################################################
#
#  mkapidoc.sh -- generate apidoc.fnc from scanning the Perl source
#
################################################################################
#
#  Version 3.x, Copyright (C) 2004-2013, Marcus Holland-Moritz.
#  Version 2.x, Copyright (C) 2001, Paul Marquess.
#  Version 1.x, Copyright (C) 1999, Kenneth Albanowski.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the same terms as Perl itself.
#
################################################################################

function isperlroot
{
  [ -f "$1/embed.fnc" ] && [ -f "$1/perl.h" ]
}

function usage
{
  echo "USAGE: $0 [perlroot] [output-file] [embed.fnc]"
  exit 0
}

if [ -z "$1" ]; then
  if isperlroot "../../.."; then
    PERLROOT=../../..
  else
    PERLROOT=.
  fi
else
  PERLROOT=$1
fi

if [ -z "$2" ]; then
  if [ -f "parts/apidoc.fnc" ]; then
    OUTPUT="parts/apidoc.fnc"
  else
    usage
  fi
else
  OUTPUT=$2
fi

if [ -z "$3" ]; then
  if [ -f "parts/embed.fnc" ]; then
    EMBED="parts/embed.fnc"
  else
    usage
  fi
else
  EMBED=$3
fi

if isperlroot $PERLROOT; then
  cat >$OUTPUT <<EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:
:  !!!! Do NOT edit this file directly! -- Edit devel/mkapidoc.sh instead. !!!!
:
:  This file was automatically generated from the API documentation scattered
:  all over the Perl source code. To learn more about how all this works,
:  please read the F<HACKERS> file that came with this distribution.
:
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:
: This file lists all API functions/macros that are documented in the Perl
: source code, but are not contained in F<embed.fnc>.
:

: This line needs to be in this file for things to work, even though it's been
: removed from later embed.fnc versions
ApTod   |int    |my_sprintf     |NN char *buffer|NN const char *pat|...

EOF
  grep -hr '^=for apidoc' $PERLROOT | sed -e 's/=for apidoc //' | grep '|' | sort | uniq \
     | perl -e'$f=pop;open(F,$f)||die"$f:$!";while(<F>){(split/\s*\|\s*/)[2]=~/(\w+)/;$h{$1}++}
               while(<>){s/[ \t]+$//;(split/\s*\|\s*/)[2]=~/(\w+)/;$h{$1}||print}' $EMBED >>$OUTPUT
else
  usage
fi
