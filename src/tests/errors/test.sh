#!/bin/bash
#
# Golden-file test for fbc's ERROR messages, sibling to tests/warnings.
#
# Same idea: run fbc over every .bas here, capture its diagnostics, and check
# the result into Git so that `git diff` shows any change in wording, error
# number, ordering, or -- the reason this exists -- the "in instantiation of /
# required from" chain that generic instantiation errors carry.
#
# tests/warnings only captures lines matching ' warning ', so error text had no
# regression net at all before this.
#
# Normalisation, so goldens do not churn when unrelated lines move:
#   - the leading "file.bas(123) " before "error" becomes a tab
#   - any remaining "file.bas(123)" (i.e. inside the chain) keeps the file but
#     has its line replaced by (N)
#
# -noerrline drops the source-context line and caret, which depend on column
# positions and would otherwise make the goldens fragile.
# -maxerr inf so a file can exercise more than one diagnostic.
#
# The test cases use #print to mark where errors are expected, which is what
# makes the golden file readable: each marker is followed by the diagnostics it
# introduced.
#
# Files named *-lines.bas are the exception, for diagnostics whose POSITION is
# what is being tested: they keep the line numbers (with the file's base name)
# and are run without -noerrline, so the quoted source line is pinned too --
# as it is printed with the default single-line error format, no caret.
#

FBC=`printenv FBC`
FBC=${FBC:-fbc}

function run_tests() {
	fbtarget="$1"
	txtdir=r/$fbtarget

	mkdir -p $txtdir
	rm -f $txtdir/*

	for i in *.bas; do
		echo "TEST $fbtarget $i"
		withoutext=${i%.bas}

		case $i in
		*-lines.bas)
			$FBC -maxerr inf -target $fbtarget $i -r -m $withoutext 2>&1 | \
				sed -e 's,^.*/\([^/]*\.\(bas\|bi\)([0-9]*)\),\1,' \
				    -e 's,from .*/\([^/]*\.\(bas\|bi\)([0-9]*)\),from \1,' > \
				$txtdir/$withoutext.txt
			;;
		*)
			$FBC -maxerr inf -noerrline -target $fbtarget $i -r -m $withoutext 2>&1 | \
				sed -e 's,^.*\.\(bas\|bi\)([0-9]*) error ,\terror ,g' \
				    -e 's,\.\(bas\|bi\)([0-9]*),.\1(N),g' > \
				$txtdir/$withoutext.txt
			;;
		esac
	done

	rm -f *.asm *.c *.o

	# Change *.txt files over to CRLF on Windows (MSYS sed produces LF...)
	case `uname` in
	*MINGW*)
		unix2dos -q $txtdir/*
	esac
}

run_tests dos
run_tests linux-x86
run_tests linux-x86_64
run_tests win32
run_tests win64
