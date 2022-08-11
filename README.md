[![Actions Status](https://github.com/lizmat/raku/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/raku/actions)

NAME
====

rak - look for clues in stuff

SYNOPSIS
========

```raku
use rak;

for rak *.contains("foo") -> (:key($path), :value(@found)) {
    if @found {
        say "$path:";
        say .key ~ ':' ~ .value for @found;
    }
}
```

DESCRIPTION
===========

The `rak` subroutine provides a mostly abstract core search functionality to be used by modules such as `App::Rak`.

EXPORTED SUBROUTINES
====================

rak
---

The `rak` subroutine takes a `Callable` pattern as the only positional argument and quite a number of named arguments. Or it takes a `Callable` as the first positional argument for the pattern, and a hash with named arguments as the second positional argument. In the latter case, the hash will have the arguments removed that the `rak` subroutine needed for its configuration and execution.

It returns either a `Pair` (with an `Exception` as key, and the exception message as the value), or a `Seq` or `HyperSeq` that contains the source object as key (by default a `IO::Path` object of the file in which the pattern was found), and a `Slip` of key / value pairs, in which the key is the line-number where the pattern was found, and the value is the product of the search (which, by default, is the line in which the pattern was found).

The following named arguments can be specified (in alphabetical order):

### :after-context(N)

Indicate the number of lines that should also be returned **after** a line with a pattern match. Defaults to **0**.

### :batch(N)

When hypering over multiple cores, indicate how many items should be processed per thread at a time. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

### :before-context(N)

Indicate the number of lines that should also be returned **before** a line with a pattern match. Defaults to **0**.

### :context(N)

Indicate the number of lines that should also be returned around a line with a pattern match. Defaults to **0**.

### :degree(N)

When hypering over multiple cores, indicate the maximum number of threads that should be used. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

### :dir(&dir-matcher)

If specified, indicates the matcher that should be used to select acceptable directories with the `paths` utility. Defaults to `True` indicating **all** directories should be recursed into. Applicable for any situation where `paths` is used to create the list of files to check.

### :encoding("utf8-c8")

When specified with a string, indicates the name of the encoding to be used to produce items to check (typically by calling `lines` or `slurp`). Defaults to `utf8-c8`, the UTF-8 encoding that is permissive of encoding issues.

### :file(&file-matcher)

If specified, indicates the matcher that should be used to select acceptable files with the `paths` utility. Defaults to `True` indicating **all** files should be checked. Applicable for any situation where `paths` is used to create the list of files to check.

### :files-from($filename)

If specified, indicates the name of the file from which a list of files to be used as sources will be read.

### :invert-match

Flag. If specified with a trueish value, will negate the return value of the pattern if a `Bool` was returned. Defaults to `False`.

### :paragraph-context

Flag. If specified with a trueish value, produce lines **around** the line with a pattern match until an empty line is encountered.

### :paths-from($filename)

If specified, indicates the name of the file from which a list of paths to be used as the base of the production of filename with a `paths` search.

### :paths(@paths)

If specified, indicates a list of paths that should be used as the base of the production of filename with a `paths` search. If there is no other sources specification (from either the `:files-from`, `paths-from` or `sources`) then the current directory (aka ".") will be assumed.

If a single hyphen is specified as the path, then STDIN will be assumed as the source.

### :per-file(&producer)

If specified, indicates that searches should be done on a per-file basis. Defaults to doing searches on a per-line basis.

If specified with a `True` value, indicates that the `slurp` method will be called on each source before being checked with pattern. If the source is a `Str`, then it will be assumed to be a path name to read from.

If specified with a `Callable`, it indicates the code to be executed from a given source to produce the single item to be checked for the pattern.

### :per-line(&producer)

If specified, indicates that searches should be done on a per-line basis.

If specified with a `True` value (which is also the default), indicates that the `lines` method will be called on each source before being checked with pattern. If the source is a `Str`, then it will be assumed to be a path name to read lines from.

If specified with a `Callable`, it indicates the code to be executed from a given source to produce the itemi to be checked for the pattern.

### :quietly

Flag. If specified with a trueish value, will absorb any warnings that may occur when looking for the pattern.

### :silently("out,err")

When specified with `True`, will absorb any output on STDOUT and STDERR. Optionally can only absorb STDOUT ("out"), STDERR ("err") and both STDOUT and STDERR ("out,err").

### :sources(@objects)

If specified, indicates a list of objects that should be used as a source for the production of lines.

PHASERS
-------

Any `FIRST`, `NEXT` and `LAST` phaser that are specified in the pattern `Callable`, will be executed at the correct time.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

