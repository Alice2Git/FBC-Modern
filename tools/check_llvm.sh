#!/bin/sh
# Assemble and RUN the ustring -gen llvm output, and diff it against -gen gcc.
#
# WHY A SCRIPT AND NOT JUST `fbc -gen llvm`
#
# fbc 1.20's llvm backend drives llc, which is not shipped with a clang-only
# install, and it emits IR in a dialect several LLVM releases old. Three
# separate things a modern LLVM rejects, NONE of them ustring's:
#
#   1. @llvm.global_ctors in the obsolete 2-field form
#   2. typed pointers (i8*), removed in LLVM 17
#   3. a CONSTANT-EXPRESSION bitcast of a function-local alloca, emitted for
#      every fixed-length local -- WSTRING * N and ZSTRING * N emit the
#      identical construct, so ustring_llvm_test.bas leaves the USTRING * N
#      case to the gcc/gas64 suites
#
# modernize_ll.py handles 1 and 2, which is enough to get the DYNAMIC ustring
# path -- %FBUSTRING, the literal byte arrays, the runtime call signatures --
# assembled and executed rather than merely read.
#
# Usage:  tools/check_llvm.sh [path-to-clang]

set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FBC="$ROOT/src/bin/fbc.exe"
INC="$ROOT/src/inc"
CLANG=${1:-"/c/Program Files/LLVM/bin/clang.exe"}
T="$ROOT/tests/ustring_llvm_test"

cd "$ROOT/tests"
rm -f ustring_llvm_test.ll ll_t.ll ll_t.o ll_t.exe ref_gcc.exe ref_gcc.txt ll_out.txt

echo "== reference: -gen gcc =="
"$FBC" -gen gcc -i "$INC" "$T.bas" -x ref_gcc.exe > /dev/null
./ref_gcc.exe > ref_gcc.txt
cat ref_gcc.txt

echo "== emit IR: -gen llvm (llc step is expected to fail; -R keeps the .ll) =="
"$FBC" -gen llvm -R -i "$INC" "$T.bas" > /dev/null 2>&1 || true
test -s ustring_llvm_test.ll || { echo "FAIL: no IR emitted"; exit 1; }

echo "== modernize + assemble =="
python "$ROOT/tools/modernize_ll.py" ustring_llvm_test.ll ll_t.ll
"$CLANG" -target x86_64-w64-mingw32 -c ll_t.ll -o ll_t.o 2>&1 \
	| grep -v "overriding the module target triple\|warning generated" || true
test -s ll_t.o || { echo "FAIL: clang produced no object"; exit 1; }

echo "== link + run =="
"$FBC" ll_t.o -x ll_t.exe > /dev/null
./ll_t.exe > ll_out.txt

if diff -q ref_gcc.txt ll_out.txt > /dev/null; then
	echo "PASS: llvm output is byte-identical to gcc"
else
	echo "FAIL: llvm and gcc differ"
	diff ref_gcc.txt ll_out.txt
	exit 1
fi
