[![Actions Status](https://github.com/lizmat/rak/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/rak/actions)

NAME
====

rak - plumbing to be able to look for stuff

SYNOPSIS
========

```raku
use rak;

# look for "foo" in all .txt files from current directory
for rak / foo /, :file(/ \.txt $/) -> (:key($path), :value(@found)) {
    if @found {
        say "$path:";
        say .key ~ ':' ~ .value for @found;
    }
}
```

DESCRIPTION
===========

The `rak` subroutine provides a mostly abstract core search (plumbing) functionality to be used by modules such as (porcelain) `App::Rak`.

THEORY OF OPERATION
===================

The `rak` subroutine basically goes through 6 steps to produce a result.

### 1. Acquire sources

The first step is determining the objects that should be searched for the specified pattern. If an object is a `Str`, it will be assume that it is a path specification of a file to be searched in some form and an `IO::Path` object will be created for it.

Related named arguments are (in alphabetical order):

  * :dir - filter for directory basename check to include

  * :file - filter for file basename check to include

  * :files-from - file containing filenames as source

  * :paths - paths to recurse into if directory

  * :paths-from - file containing paths to recurse into

  * :recurse-symlink - recurse into symlinked directories

  * :sources - list of objects to be considered as source

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 2. Filter applicable objects

Filter down the list of sources from step 1 on any additional filesystem related properties. This assumes that the list of objects created are strings of absolute paths to be checked.

  * :accessed - when was path last accessed

  * :blocks- number of filesystem blocks

  * :created - when was path created

  * :device-number - device number on which path is located

  * :empty - is path empty (filesize == 0)

  * :executable - is path executable

  * :filesize - size of the path in bytes

  * :gid - numeric gid of the path

  * :git-repo - is path top directory of a Git repository

  * :github-repo - is path top directory of a GitHub repository

  * :group-executable - is path executable by group

  * :group-readable - is path readable by group

  * :group-writable - is path writable 

  * :hard-links - number of hard-links to path on filesystem

  * :inode - inode of path on filesystem

  * :meta-modified - when meta information of path was modified

  * :mode - the mode of the path

  * :modified - when path was last modified

  * :owned-by-group - is path owned by group of current user

  * :owned-by-user - is path owned by current user

  * :readable - is path readable by current user

  * :uid - numeric uid of path

  * :symbolic-link - is path a symbolic link

  * :world-executable - is path executable by any user

  * :world-readable - is path readable by any user

  * :world-writable - is path writable by any user

  * :writable - is path writable by current user

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 3. Produce items to search in (apply transformers)

The second step is to create the logic for creating items to search in from the objects in step 2. If search is to be done per object, then `.slurp` is called on the object. Otherwise `.lines` is called on the object. Unless one provides their own logic for producing items to search in.

Related named arguments are (in alphabetical order):

  * :encoding - encoding to be used when creating items

  * :find - map sequence of step 1 to item producer

  * :per-file - logic to create one item per object

  * :per-line - logic to create one item per line in the object

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 4. Create logic for matching

Take the logic of the pattern `Callable`, and create a `Callable` to do the actual matching with the items produced in step 3.

Related named arguments are (in alphabetical order):

  * :count-only - don't produce results, just count

  * :invert-match - invert the logic of matching

  * :quietly - absorb any warnings produced by the matcher

  * :silently - absorb any output done by the matcher

### 5. Create logic for running

Take the matcher logic of the `Callable` of step 4 and create a runner `Callable` that will produce the items found and their possible context (such as extra lines before or after). Assuming no context, the runner changes a return value of `False` from the matcher into `Empty`, a return value of `True` in the original line, and passes through any other value.

Related named arguments are (in alphabetical order):

  * :after-context - number of lines to show after a match

  * :before-context - number of lines to show before a match

  * :context - number of lines to show around a match

  * :paragraph-context - lines around match until empty line

  * :passthru-context - pass on *all* lines

Matching lines are represented by `PairMatched` objects, and lines that have been added because of the above context arguments, are represented by `PairContext` objects.

### 6. Run the sequence(s)

The final step is to take the `Callable` of step 5 and run that repeatedly on the sequence of step 2, and for each item of that sequence, run the sequence of step 5 on that. Make sure any phasers (`FIRST`, `NEXT` and `LAST`) are called at the appropriate time in a thread-safe manner.

Either produces a sequence in which the key is the source, and the value is a `Slip` of `Pair`s where the key is the line-number and the value is line with the match, or whatever the pattern matcher returned.

Or, produces sequence of whatever a specified mapper returned and/or with uniqueifying enabled.

Related named arguments are (in alphabetical order):

  * :mapper - code to map results of a single source

  * :map-all - also call mapper if a source has no matches

  * :unique - only return unique matches

EXPORTED SUBROUTINES
====================

rak
---

The `rak` subroutine takes a `Callable` (or `Regex`) pattern as the only positional argument and quite a number of named arguments. Or it takes a `Callable` (or `Regex`) as the first positional argument for the pattern, and a hash with named arguments as the second positional argument. In the latter case, the hash will have the arguments removed that the `rak` subroutine needed for its configuration and execution.

It returns either a `Pair` (with an `Exception` as key, and the exception message as the value), or an `Iterable` of `Pair`s which contain the source object as key (by default a `IO::Path` object of the file in which the pattern was found), and a `Slip` of key / value pairs, in which the key is the line-number where the pattern was found, and the value is the product of the search (which, by default, is the line in which the pattern was found).

The following named arguments can be specified (in alphabetical order):

### :accessed(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **access** time of the path. The `Callable` is passed a `Num` value of the access time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

### :after-context(N)

Indicate the number of lines that should also be returned **after** a line with a pattern match. Defaults to **0**.

### :batch(N)

When hypering over multiple cores, indicate how many items should be processed per thread at a time. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

### :before-context(N)

Indicate the number of lines that should also be returned **before** a line with a pattern match. Defaults to **0**.

### :blocks(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of blocks** used by the path on the filesystem on which the path is located. The `Callable` is passed the number of blocks of a path and is expected to return a trueish value to have the path be considered for further selection.

### :context(N)

Indicate the number of lines that should also be returned around a line with a pattern match. Defaults to **0**.

### :count-only

Flag. If specified with a trueish value, will perform all searching, but only update counters and not produce any results other than a `Map` with the following keys:

  * nr-sources - number of sources seen

  * nr-items - number of items inspected

  * nr-matches - number of items that matched

  * nr-passthrus - number of items that have passed through

  * nr-changes - number of items that would have been changed

### :created(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **creation** time of the path. The `Callable` is passed a `Num` value of the creation time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

### :degree(N)

When hypering over multiple cores, indicate the maximum number of threads that should be used. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

### :device-number(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **device number** of the path. The `Callable` is passed the device number of the device on which the path is located and is expected to return a trueish value to have the path be considered for further selection.

### :dir(&dir-matcher)

If specified, indicates the matcher that should be used to select acceptable directories with the `paths` utility. Defaults to `True` indicating **all** directories should be recursed into. Applicable for any situation where `paths` is used to create the list of files to check.

### dont-catch

Flag. If specified with a trueish value, will **not** catch any error during processing, but will throw any error again. Defaults to `False`, making sure that errors **will** be caught.

### :encoding("utf8-c8")

When specified with a string, indicates the name of the encoding to be used to produce items to check (typically by calling `lines` or `slurp`). Defaults to `utf8-c8`, the UTF-8 encoding that is permissive of encoding issues.

### :empty

Flag. If specified, indicates paths, that are empty (aka: have a filesize of 0 bytes), are (not) acceptable for further selection. Usually only makes sense when uses together with `:find`.

### :executable

Flag. If specified, indicates paths, that are **executable** by the current **user**, are (not) acceptable for further selection.

### :file(&file-matcher)

If specified, indicates the matcher that should be used to select acceptable files with the `paths` utility. Defaults to `True` indicating **all** files should be checked. Applicable for any situation where `paths` is used to create the list of files to check.

### :filesize(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of bytes** of the path. The `Callable` is passed the number of bytes of a path and is expected to return a trueish value to have the path be considered for further selection.

### :files-from($filename)

If specified, indicates the name of the file from which a list of files to be used as sources will be read.

### :find

Flag. If specified, maps the sources of items into items to search.

### :gid(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **gid** of the path. The `Callable` is passed the numeric gid of a path and is expected to return a trueish value to have the path be considered for further selection. See also `owner` and `group` filters.

### :git-repo

Flag. If specified, indicates paths, look like they're the top directory in a Git repository (because they have a `.git` directory in it), are (not) acceptable for further selection.

### :github-repo

Flag. If specified, indicates paths, look like they're the top directory in a GitHub repository (because they have a `.github` directory in it), are (not) acceptable for further selection.

### :group-executable

Flag. If specified, indicates paths, that are **executable** by the current **group**, are (not) acceptable for further selection.

### :group-readable

Flag. If specified, indicates paths, that are **readable** by the current **group**, are (not) acceptable for further selection.

### :group-writable

Flag. If specified, indicates paths, that are **writable** by the current **group**, are (not) acceptable for further selection.

### :hard-links(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of hard-links** of the path. The `Callable` is passed the number of hard-links of a path and is expected to return a trueish value to have the path be considered for further selection.

### :inode(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **inode** of the path. The `Callable` is passed the inode of a path and is expected to return a trueish value to have the path be considered for further selection.

### :invert-match

Flag. If specified with a trueish value, will negate the return value of the pattern if a `Bool` was returned. Defaults to `False`.

### :mapper(&mapper)

If specified, indicates the `Callable` that will be called (in a thread-safe manner) for each source, with the matches of that source. The `Callable` is passed the source object, and a list of matches, if there were any matches. If you want the `Callable` to be called for every source, then you must also specify `:map-all`.

Whatever the mapper `Callable` returns, will become the result of the call to the `rak` subroutine. If you don't want any result to be returned, you can return `Empty` from the mapper `Callable`.

### :map-all

Flag. If specified with a trueish value, will call the mapper logic, as specified with `:mapper`, even if a source has no matches. Defaults to `False`: 

### :meta-modified(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **modification** time of the path. The `Callable` is passed a `Num` value of the modification time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

### :mode(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **mode** of the path. The `Callable` is passed the mode of a path and is expected to return a trueish value to have the path be considered for further selection. This is really for advanced types of tests: it's probably easier to use any of the `readable`, `writeable` and `executable` filters.

### :modified(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **modification** time of the path. The `Callable` is passed a `Num` value of the modification time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

### :paragraph-context

Flag. If specified with a trueish value, produce lines **around** the line with a pattern match until an empty line is encountered.

### :passthru-context

Flag. If specified with a trueish value, produces **all** lines.

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

### :recurse-symlink

Flag. If specified with a trueish value, will recurse into directories that are actually symbolic links. The default is `False`: do **not** recurse into symlinked directories.

### :quietly

Flag. If specified with a trueish value, will absorb any warnings that may occur when looking for the pattern.

### :readable

Flag. If specified, indicates paths, that are **readable** by the current **user**, are (not) acceptable for further selection.

### :owned-by-group

Flag. If specified, indicates only paths that are **owned** by the **group** of the current user, are (not) acceptable for further selection.

### :owned-by-user

Flag. If specified, indicates only paths that are **owned** by the current **user**, are (not) acceptable for further selection.

### :silently("out,err")

When specified with `True`, will absorb any output on STDOUT and STDERR. Optionally can only absorb STDOUT ("out"), STDERR ("err") and both STDOUT and STDERR ("out,err").

### :sources(@objects)

If specified, indicates a list of objects that should be used as a source for the production of lines.

### :stats

Flag. If specified with a trueish value, will keep stats on number of files and number of lines seen. And instead of just returning the results sequence, will then return a `List` of the result sequence as the first argument, and a `Map` with statistics as the second argument.

### :symbolic-link

Flag. If specified, indicates only paths that are symbolic links, are (not) acceptable for further selection.

### :uid(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **uid** of the path. The `Callable` is passed the numeric uid of a path and is expected to return a trueish value to have the path be considered for further selection. See also `owner` and `group` filters.

### :unique

Flag. If specified, indicates that only unique matches will be returned, instead of the normal sequence of source => result pairs.

### :world-executable

Flag. If specified, indicates paths, that are **executable** by any user or group, are (not) acceptable for further selection.

### :world-readable

Flag. If specified, indicates paths, that are **readable** by any user or group, are (not) acceptable for further selection.

### :world-writeable

Flag. If specified, indicates paths, that are **writable** by any user or group, are (not) acceptable for further selection.

### :writable

Flag. If specified, indicates paths, that are **writable** by the current **user**, are (not) acceptable for further selection.

PATTERN RETURN VALUES
---------------------

The return value of the pattern `Callable` is interpreted in the following ways:

### True

If the `Bool`ean True value is returned, assume the pattern is found. Produce the line unless `:invert-match` was specified.

### False

If the `Bool`ean False value is returned, assume the pattern is **not** found. Do **not** produce the line unless `:invert-match` was specified.

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

