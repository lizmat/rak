[![Actions Status](https://github.com/lizmat/rak/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/rak/actions)

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

THEORY OF OPERATION
===================

The `rak` subroutine basically goes through 4 steps to produce a result.

1. Acquire sources
------------------

The first step is determining the objects that should be searched for the specified pattern. If an object is a `Str`, it will be assume that it is a path specification of a file to be searched in some form and an `IO::Path` object will be created for it.

Related named arguments are (in alphabetical order):

  * :dir - filter for directory basename check to include

  * :file - filter for file basename check to include

  * :files-from - file containing filenames as source

  * :paths - paths to recurse into if directory

  * :paths-from - file containing paths to recurse into

  * :sources - list of objects to be considered as source

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 2. Produce items to search in

The second step is to create the logic for creating items to search in from the objects in step 1. If search is to be done per object, then `.slurp` is called on the object. Otherwise `.lines` is called on the object. Unless one provides their own logic for producing items to search in.

Related named arguments are (in alphabetical order):

  * :encoding - encoding to be used when creating items

  * :find - map sequence of step 1 to item producer

  * :per-file - logic to create one item per object

  * :per-line - logic to create one item per line in the object

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 3. Create logic for matching

Take the logic of the pattern `Callable`, and create a `Callable` to do the actual matching with the items produced in step 2.

Related named arguments are (in alphabetical order):

  * :invert-match - invert the logic of matching

  * :quietly - absorb any warnings produced by the matcher

  * :silently - absorb any output done by the matcher

### 4. Create logic for contextualizing

Take the logic of the `Callable` of step 3 and create a `Callable` that will produce the items found and their possible context. If no specific context setting is found, then it will just use the `Callable` of step 3.

Related named arguments are (in alphabetical order):

  * :after-context - number of lines to show after a match

  * :before-context - number of lines to show before a match

  * :context - number of lines to show around a match

  * :paragraph-context - lines around match until empty line

### 5. Run the sequence(s)

The final step is to take the `Callable` of step 4 and run that repeatedly on the sequence of step 1, and for each item of that sequence, run the sequence of step 2 on that. Make sure any phasers (`FIRST`, `NEXT` and `LAST`) are called at the appropriate time in a thread-safe manner. And produce a sequence in which the key is the source, and the value is a `Slip` of `Pair`s where the key is the line-number and the value is line with the match, or whatever the pattern matcher returned.

EXPORTED SUBROUTINES
====================

rak
---

The `rak` subroutine takes a `Callable` (or `Regex`) pattern as the only positional argument and quite a number of named arguments. Or it takes a `Callable` (or `Regex`) as the first positional argument for the pattern, and a hash with named arguments as the second positional argument. In the latter case, the hash will have the arguments removed that the `rak` subroutine needed for its configuration and execution.

It returns either a `Pair` (with an `Exception` as key, and the exception message as the value), or an `Iterable` of `Pair`s which contain the source object as key (by default a `IO::Path` object of the file in which the pattern was found), and a `Slip` of key / value pairs, in which the key is the line-number where the pattern was found, and the value is the product of the search (which, by default, is the line in which the pattern was found).

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

### :find

Flag. If specified, maps the sources of items into items to search.

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

### :stats

Flag. If specified with a trueish value, will keep stats on number of files and number of lines seen. And instead of just returning the results sequence, will then return a `List` of the result sequence as the first argument, and a `Map` with statistics as the second argument.

PATTERN RETURN VALUES
---------------------

The return value of the pattern `Callable` is interpreted in the following ways:

### True

If the `Bool`ean True value is returned, assume the pattern is found. Produce the line unless `:invert-match` was specified.

### False

If the `Bool`ean Fals value is returned, assume the pattern is **not** found. Do **not** produce the line unless `:invert-match` was specified.

### Empty

Always produce the line. Even if `:invert-match` was specified.

### any other value

Produce that value.

PHASERS
-------

Any `FIRST`, `NEXT` and `LAST` phaser that are specified in the pattern `Callable`, will be executed at the correct time.

MATCHING LINES vs CONTEXT LINES
-------------------------------

The `Pair`s that contain the search result within an object, have an additional method mixed in: `matched`. This returns `True` for lines that matched, and `False` for lines that have been added because of a context specification (`:context`, `:before-context`, `:after-context` or `paragraph-context`).

These `Pair`s can also be recognized by their class: `PairMatched` versus `PairContext`, which are also exported.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/rak . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

