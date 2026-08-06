Golden-file tests for fbc's ERROR messages
==========================================

Sibling to tests/warnings, which captures only lines matching " warning " and
therefore gave error text no regression net at all.

Run it:

    make error-tests                 (from the fbc top directory)
  or
    cd tests/errors && FBC=../../fbc ./test.sh

It compiles every .bas here for five targets and writes the diagnostics to
r/<target>/<name>.txt.  Those files are checked into Git, so the test is:

    git diff tests/errors/r

Empty diff means nothing changed.  A non-empty diff is the result -- read it and
decide whether the change was intended.  On Windows the files are converted to
CRLF, so compare content, not `git status`.

This does NOT return a non-zero exit code on failure.  It is a diff test, the
same as tests/warnings.


Adding a case
-------------

Drop a .bas file in this directory and re-run.  Use #print to mark what each
section is meant to produce -- the markers land in the golden file and make it
readable as expectation-then-result:

    #print === duplicate type parameter ===
    type Dup( of T, T )
        as T v
    end type

produces

    === duplicate type parameter ===
        error 334: Duplicated type parameter, T

Note the compiler stops at the first error in many situations, so a file with
several independent cases may only report the first few.  Prefer several small
files over one large one when the cases interfere.


Normalisation
-------------

test.sh rewrites two things so the goldens do not churn when unrelated lines
move:

  - the leading "file.bas(123) " before "error" becomes a tab
  - any remaining "file.bas(123)" -- i.e. inside an instantiation chain -- keeps
    the file name but has its line replaced by (N)

The trade-off is deliberate: line numbers are not asserted, so a diagnostic
pointing at the wrong line will not be caught here.  What is asserted is the
error number, the wording, the ordering, and the structure of any
"in instantiation of / required from" chain.

fbc is run with -noerrline, which drops the source-context line and caret.
Those depend on column positions and would make the goldens fragile.
-maxerr inf lets one file report more than a single diagnostic.
