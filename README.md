[![Actions Status](https://github.com/lizmat/rak/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/rak/actions)

NAME
====

rak - plumbing to be able to look for stuff

SYNOPSIS
========

```raku
use rak;

# look for "foo" in all .txt files from current directory
my $rak = rak / foo /, :file(/ \.txt $/);

# show results
for $rak.result -> (:key($path), :value(@found)) {
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

The `rak` subroutine basically goes through 6 steps to produce a `Rak` object.

### 1. Acquire sources

The first step is determining the objects that should be searched for the specified pattern. If an object is a `Str`, it will be assumed that it is a path specification of a file to be searched in some form and an `IO::Path` object will be created for it.

Related named arguments are (in alphabetical order):

  * :dir - filter for directory basename check to include

  * :file - filter for file basename check to include

  * :files-from - file containing filenames as source

  * :ioify - code to create IO::Path-like objects with

  * :paths - paths to recurse into if directory

  * :paths-from - file containing paths to recurse into

  * :recurse-symlinked-dir - recurse into symlinked directories

  * :recurse-unmatched-dir - recurse into directories not matching :dir

  * :sources - list of objects to be considered as source

  * :under-version-control - only include paths under version control

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 2. Filter applicable objects

Filter down the list of sources from step 1 on any additional filesystem related properties. This assumes that the list of objects created are strings of absolute paths to be checked (except where otherwise indicated).

  * :accept - given an IO::Path, is path acceptable

  * :accessed - when was path last accessed

  * :blocks- number of filesystem blocks

  * :created - when was path created

  * :deny - given an IO::Path, is path NOT acceptable

  * :device-number - device number on which path is located

  * :exec - run program, include if successful

  * :filesize - size of the path in bytes

  * :gid - numeric gid of the path

  * :hard-links - number of hard-links to path on filesystem

  * :has-setgid - has SETGID bit set in attributes

  * :has-setuid - has SETUID bit set in attributes

  * :inode - inode of path on filesystem

  * :is-empty - is path empty (filesize == 0)

  * :is-executable - is path executable by current user

  * :is-group-executable - is path executable by group

  * :is-group-readable - is path readable by group

  * :is-group-writable - is path writable by group

  * :is-owned-by-group - is path owned by group of current user

  * :is-owned-by-user - is path owned by current user

  * :is-owner-executable - is path executable by owner

  * :is-owner-readable - is path readable by owner

  * :is-owner-writable - is path writable by owner

  * :is-readable - is path readable by current user

  * :is-sticky - has STICKY bit set in attributes

  * :is-symbolic-link - is path a symbolic link

  * :is-text - does path contains text?

  * :is-world-executable - is path executable by any user

  * :is-world-readable - is path readable by any user

  * :is-world-writable - is path writable by any user

  * :is-writable - is path writable by current user

  * :meta-modified - when meta information of path was modified

  * :mode - the mode of the path

  * :modified - when path was last modified

  * :shell - run shell command, include if successful

  * :uid - numeric uid of path

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 3. Produce items to search in (apply transformers)

The third step is to create the logic for creating items to search in from the objects in step 2. If search is to be done per object, then `.slurp` is called on the object. Otherwise `.lines` is called on the object. Unless one provides their own logic for producing items to search in.

Related named arguments are (in alphabetical order):

  * :encoding - encoding to be used when creating items

  * :find - map sequence of step 1 to item producer

  * :produce-one - produce one item per given source

  * :produce-many - produce zero or more items by given source

  * :omit-item-number - do not store item numbers in result

  * :with-line-ending - produce lines with line endings

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 4. Create logic for matching

Take the logic of the pattern `Callable`, and create a `Callable` to do the actual matching with the items produced in step 3.

Related named arguments are (in alphabetical order):

  * :invert-match - invert the logic of matching

  * :old-new - produce pairs of old/new state

  * :quietly - absorb any warnings produced by the matcher

  * :silently - absorb any output done by the matcher

  * :stats - produce results and statistics

  * :stats-only - don't produce results, just statistics

### 5. Create logic for running

Take the matcher logic of the `Callable` of step 4 and create a runner `Callable` that will produce the items found and their possible context (such as extra items before or after). Assuming no context, the runner changes a return value of `False` from the matcher into `Empty`, a return value of `True` in the original item, and passes through any other value.

Related named arguments are (in alphabetical order):

  * :after-context - number of items to show after a match

  * :before-context - number of items to show before a match

  * :context - number of items to show around a match

  * :paragraph-context - items around match until false item

  * :passthru-context - pass on *all* items if there is a match

  * :max-matches-per-source - max # of matches per source

  * :passthru - pass on *all* items always

Matching items are represented by `PairMatched` objects, and items that have been added because of the above context arguments, are represented by `PairContext` objects. Unless `:omit-item-number` has been specified with a trueish value, in which case items will always be just a string, whether they matched or not (if part of a context specification).

### 6. Run the sequence(s)

The final step is to take the `Callable` of step 5 and run that repeatedly on the sequence of step 3. Make sure any phasers (`FIRST`, `NEXT` and `LAST`) are called at the appropriate time in a thread-safe manner. Inside the `Callable` of step 5, the dynamic variable `$*SOURCE` will be set to the source of the items being checked.

Either produces a sequence in which the key is the source, and the value is a `Slip` of `Pair`s where the key is the item-number and the value is item with the match, or whatever the pattern matcher returned.

Or, produces sequence of whatever a specified mapper returned and/or with uniqueifying enabled.

Related named arguments are (in alphabetical order):

  * :sort - sort the sources before processing

  * :eager - produce all results before creating Rak object

  * :mapper - code to map results of a single source

  * :map-all - also call mapper if a source has no matches

  * :sources-only - only produce the source of any match

  * :sources-without-only - produce the source without any match

  * :frequencies - produce items and their frequencies

  * :classify - classify items according to a single key

  * :categorize - classify items according to zero or more keys

  * :unique - only produce unique items

EXPORTED CLASSES
================

Rak
---

The return value of a `rak` search. Contains the following attributes:

### result

An `Iterable` with search results. This could be a lazy `Seq` or a fully vivified `List` (see below).

### completed

A `Bool` indicating whether the search has already been completed. This is typically `True` if statistics were asked to be collected, or the pattern `Callable` contained `LAST` phasers.

### stats

A `Map` with any statistics collected (so far, in case an exception was thrown). If the `Map` is not empty, it contains the following keys:

  * nr-sources - number of sources seen

  * nr-items - number of items inspected

  * nr-matches - number of items that matched

  * nr-passthrus - number of items that have passed through

  * nr-changes - number of items that would have been changed

### exception

Any `Exception` object that was caught.

PairContext
-----------

A subclass of `Pair` of which the `matched` method returns `False`. Used for non-matching items when item-numbers are required to be returned and a certain item context was requested.

PairMatched
-----------

A subclass of `PairContext` of which the `matched` method returns `True`. Used for matching items when item-numbers are required to be returned.

EXPORTED SUBROUTINES
====================

rak
---

The `rak` subroutine takes a `Callable` (or `Regex`) pattern as the only positional argument and quite a number of named arguments. Or it takes a `Callable` (or `Regex`) as the first positional argument for the pattern, and a hash with named arguments as the second positional argument. In the latter case, the hash will have the arguments removed that the `rak` subroutine needed for its configuration and execution.

### Return value

A `Rak` object (see above) is always returned. The object provides four attributes: `result` (with the result `Iterable`), `completed` (a Bool indicating whether all searching has been done already), `stats` (Map with any statistics) and `exception` (any `Exception` object or `Nil`).

#### Result Iterable

If the `:unique` argument was specified with a trueish value, then the result `Iterable` will just produce the unique values that were either explicitely returned by the matcher, or the unique items that matched.

Otherwise the value is an `Iterable` of `Pair`s which contain the source object as key (by default the absolute path of the file in which the pattern was found).

If there was only one item produced per source, then the value will be that value, or whatever was produced by the matching logic.

Otherwise the value will be a `Slip`. If no item numbers were requested, each element contains the result of matching. If item-numbers were requested, each element is a `Pair`, of which the key is the item-number where the pattern was found, and the value is the product of the search (which, by default, is the item in which the pattern was found).

In a graph:

    rak(...)
     |- Rak
         |- exception: Exception object or Nil
         |- stats: Map with statistics (if any)
         |- completed: Bool whether all searching done already
         |- result: Iterable
              |- Pair
              |   |- key: source object
              |   |- value:
              |        |- Slip
              |        |   |- PairMatched|PairContext
              |        |   |   |- key: item-number
              |        |   |   \- value: match result
              |        |   or
              |        |   \- match result
              |        or
              |        \- single item match result
              or
              \- unique match result

### Named Arguments

The following named arguments can be specified (in alphabetical order):

#### :accept(&filter)

If specified, indicates a `Callable` filter that will be given an `IO::Path` of the path. It should return `True` if the path is acceptable.

#### :accessed(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **access** time of the path. The `Callable` is passed a `Num` value of the access time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

#### :after-context(N)

Indicate the number of items that should also be returned **after** an item with a pattern match. Defaults to **0**.

#### :batch(N)

When hypering over multiple cores, indicate how many items should be processed per thread at a time. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

#### :before-context(N)

Indicate the number of items that should also be returned **before** an item with a pattern match. Defaults to **0**.

#### :blocks(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of blocks** used by the path on the filesystem on which the path is located. The `Callable` is passed the number of blocks of a path and is expected to return a trueish value to have the path be considered for further selection.

#### :categorize(&categorizer)

If specified, indicates the `Callable` that should return zero or more keys for a given item to have it categorized. This effectively replaces the source if an item by any of its key in the result. The result will contain the key/item(s) pairs ordered by most to least number of items per key.

#### :classify(&classifier)

If specified, indicates the `Callable` that should return a key for a given item to have it classified. This effectively replaces the source if an item by its key in the result. The result will contain the key/item(s) pairs ordered by most to least number of items per key.

#### :context(N)

Indicate the number of items that should also be returned around an item with a pattern match. Defaults to **0**.

#### :created(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **creation** time of the path. The `Callable` is passed a `Num` value of the creation time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

#### :degree(N)

When hypering over multiple cores, indicate the maximum number of threads that should be used. Defaults to whatever the system thinks is best (which **may** be sub-optimal).

#### :deny(&filter)

If specified, indicates a `Callable` filter that will be given an `IO::Path` of the path. It should return `True` if the path is **NOT** acceptable.

#### :device-number(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **device number** of the path. The `Callable` is passed the device number of the device on which the path is located and is expected to return a trueish value to have the path be considered for further selection.

#### :dir(&dir-matcher)

If specified, indicates the matcher that should be used to select acceptable directories with the `paths` utility. Defaults to `True` indicating **all** directories should be recursed into. Applicable for any situation where `paths` is used to create the list of files to check.

#### :dont-catch

Flag. If specified with a trueish value, will **not** catch any error during processing, but will throw any error again. Defaults to `False`, making sure that errors **will** be caught.

#### :eager

Flag. If specified with a trueish value, will **always** produce **all** results before returning the `Rak` object. Defaults to `False`, making result production lazy if possible.

#### :encoding("utf8-c8")

When specified with a string, indicates the name of the encoding to be used to produce items to check (typically by calling `lines` or `slurp`). Defaults to `utf8-c8`, the UTF-8 encoding that is permissive of encoding issues.

#### :exec($invocation)

If specified, indicates the name of a program and its arguments to be executed. Any `$_` in the invocation string will be replaced by the file being checked. The file will be included if the program runs to a successful conclusion.

#### :file(&file-matcher)

If specified, indicates the matcher that should be used to select acceptable files with the `paths` utility. Defaults to `True` indicating **all** files should be checked. Applicable for any situation where `paths` is used to create the list of files to check.

If the boolean value `False` is specified, then only directory paths will be produced. This only makes sense if `:find` is also specified.

#### :filesize(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of bytes** of the path. The `Callable` is passed the number of bytes of a path and is expected to return a trueish value to have the path be considered for further selection.

#### :files-from($filename)

If specified, indicates the name of the file from which a list of files to be used as sources will be read.

#### :find

Flag. If specified, maps the sources of items into items to search.

#### :frequencies

Flag. If specified, produces key/value `Pair`s in which the key is the item, and the value is the frequency with which the item was seen.

#### :gid(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **gid** of the path. The `Callable` is passed the numeric gid of a path and is expected to return a trueish value to have the path be considered for further selection. See also `owner` and `group` filters.

#### :hard-links(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **number of hard-links** of the path. The `Callable` is passed the number of hard-links of a path and is expected to return a trueish value to have the path be considered for further selection.

#### :has-setgid

Flag. If specified, indicates paths that have the SETGID bit set in their attributes, are (not) acceptable for further selection. Usually only makes sense when uses together with `:find`.

#### :has-setuid

Flag. If specified, indicates paths that have the SETUID bit set in their attributes, are (not) acceptable for further selection. Usually only makes sense when uses together with `:find`.

#### :inode(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **inode** of the path. The `Callable` is passed the inode of a path and is expected to return a trueish value to have the path be considered for further selection.

#### :invert-match

Flag. If specified with a trueish value, will negate the return value of the pattern if a `Bool` was returned. Defaults to `False`.

#### :ioify(&coercer)

If specified, indicates the `Callable` that will be called with a path and which should return an object on which `.lines` and `.slurp` can be called. Defaults to `*.IO`, creating an `IO::Path` object by default.

#### :is-empty

Flag. If specified, indicates paths, that are empty (aka: have a filesize of 0 bytes), are (not) acceptable for further selection. Usually only makes sense when uses together with `:find`.

#### :is-executable

Flag. If specified, indicates paths, that are **executable** by the current **user**, are (not) acceptable for further selection.

#### :is-group-executable

Flag. If specified, indicates paths, that are **executable** by the current **group**, are (not) acceptable for further selection.

#### :is-group-readable

Flag. If specified, indicates paths, that are **readable** by the current **group**, are (not) acceptable for further selection.

#### :is-group-writable

Flag. If specified, indicates paths, that are **writable** by the current **group**, are (not) acceptable for further selection.

#### :is-readable

Flag. If specified, indicates paths, that are **readable** by the current **user**, are (not) acceptable for further selection.

#### :is-owned-by-group

Flag. If specified, indicates only paths that are **owned** by the **group** of the current user, are (not) acceptable for further selection.

#### :is-owned-by-user

Flag. If specified, indicates only paths that are **owned** by the current **user**, are (not) acceptable for further selection.

#### :is-owner-executable

Flag. If specified, indicates paths, that are **executable** by the owner, are (not) acceptable for further selection.

#### :is-owner-readable

Flag. If specified, indicates paths, that are **readable** by the owner, are (not) acceptable for further selection.

#### :is-owner-writable

Flag. If specified, indicates paths, that are **writable** by the owner, are (not) acceptable for further selection.

#### :is-sticky

Flag. If specified, indicates paths that have the STICKY bit set in their attributes, are (not) acceptable for further selection. Usually only makes sense when uses together with `:find`.

#### :is-symbolic-link

Flag. If specified, indicates only paths that are symbolic links, are (not) acceptable for further selection.

#### :is-text

Flag. If specified, indicates only paths that contain text are (not) acceptable for further selection.

#### :is-world-executable

Flag. If specified, indicates paths, that are **executable** by any user or group, are (not) acceptable for further selection.

#### :is-world-readable

Flag. If specified, indicates paths, that are **readable** by any user or group, are (not) acceptable for further selection.

#### :is-world-writeable

Flag. If specified, indicates paths, that are **writable** by any user or group, are (not) acceptable for further selection.

#### :is-writable

Flag. If specified, indicates paths, that are **writable** by the current **user**, are (not) acceptable for further selection.

#### :mapper(&mapper)

If specified, indicates the `Callable` that will be called (in a thread-safe manner) for each source, with the matches of that source. The `Callable` is passed the source object, and a list of matches, if there were any matches. If you want the `Callable` to be called for every source, then you must also specify `:map-all`.

Whatever the mapper `Callable` returns, will become the result of the call to the `rak` subroutine. If you don't want any result to be returned, you can return `Empty` from the mapper `Callable`.

#### :map-all

Flag. If specified with a trueish value, will call the mapper logic, as specified with `:mapper`, even if a source has no matches. Defaults to `False`.

#### :max-matches-per-source(N)

Indicate the maximum number of items that may be produce per source. Defaults to **all** (which can also be specified by an falsish value).

#### :meta-modified(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **modification** time of the path. The `Callable` is passed a `Num` value of the modification time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

#### :mode(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **mode** of the path. The `Callable` is passed the mode of a path and is expected to return a trueish value to have the path be considered for further selection. This is really for advanced types of tests: it's probably easier to use any of the `readable`, `writeable` and `executable` filters.

#### :modified(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **modification** time of the path. The `Callable` is passed a `Num` value of the modification time (number of seconds since epoch) and is expected to return a trueish value to have the path be considered for further selection.

#### :old-new

Flag. If specified with a trueish value, will produce `Pair`s of the current value being investigated, and whatever was returned by the `Callable` pattern for that value (if what was returned was **not** a `Bool`, `Empty` or `Nil`) **if** that value was different from the original value. Defaults to `False`, meaning to just produce according to what was returned.

#### :omit-item-number

Flag. If specified with a trueish value, won't produce any `PairMatched` or `PairContext` objects in the result, but will just produce the result of the match. Defaults to `False`, meaning to include item numbers.

#### :paragraph-context

Flag. If specified with a trueish value, produce items **around** the empty with a pattern match until a falsish item is encountered.

#### :passthru

Flag. If specified with a trueish value, produces **all** items always.

#### :passthru-context

Flag. If specified with a trueish value, produces **all** items if there is at least one match.

#### :paths-from($filename)

If specified, indicates the name of the file from which a list of paths to be used as the base of the production of filename with a `paths` search.

#### :paths(@paths)

If specified, indicates a list of paths that should be used as the base of the production of filename with a `paths` search. If there is no other sources specification (from either the `:files-from`, `:paths-from` or `:sources`) then the current directory (aka ".") will be assumed. If that directory appears to be the top directory in a git repository, then `:under-version-control` will be assumed, only producing files that are under version control under that directory.

If a single hyphen is specified as the path, then STDIN will be assumed as the source.

#### :produce-many(&producer)

If specified, indicates a `Callable` that will be called given a source, and is expected to produce zero or more items to be inspected. Defaults to a producer that calles the `lines` method on a given source, with the `:encoding` and `:with-line-ending` arguments.

The `Callable` should return `Empty` if for some reason nothing could be produced.

#### :produce-one(&producer)

If specified, indicates a `Callable` that will be called given a source, and is expected to produce one items to be inspected.

The `Callable` should return `Nil` if for some reason nothing could be produced).

#### :recurse-symlinked-dir

Flag. If specified with a trueish value, will recurse into directories that are actually symbolic links. The default is `False`: do **not** recurse into symlinked directories.

#### :recurse-unmatched-dir

Flag. If specified with a trueish value, will recurse into directories that did **not** pass the :<dir>. No files will ever be produced from such directories, but further recursion will be done if directories are encountered. The default is `False`: do **not** recurse into directories that didn't match the `:dir` specification.

#### :quietly

Flag. If specified with a trueish value, will absorb any warnings that may occur when looking for the pattern.

#### :shell($invocation)

If specified, indicates the command(s) to be executed in a shell. Any `$_` in the invocation string will be replaced by the file being checked. The file will be included if the shell command(s) run to a successful conclusion.

#### :silently("out,err")

When specified with `True`, will absorb any output on STDOUT and STDERR. Optionally can only absorb STDOUT ("out"), STDERR ("err") and both STDOUT and STDERR ("out,err").

#### :sort(&logic)

When specified with `True`, will sort the sources alphabetically. Can also be specified with a `Callable`, which should contain the logic sorting (just as the argument to the `.sort` method.

#### :sources(@objects)

If specified, indicates a list of objects that should be used as a source for the production of items. Which generally means they cannot be just strings.

#### :sources-only

Flag. If specified with a trueish value, will only produce the source of a match once per source. Defaults to `False`.

#### :sources-without-only

Flag. If specified with a trueish value, will only produce the source of a match if there is **not** a single match. Defaults to `False`.

#### :stats

Flag. If specified with a trueish value, will keep stats on number of files and number of items seen, and make that available in the `stats` attribute of the `Rak` object.

#### :stats-only

Flag. If specified with a trueish value, will perform all searching, but only update counters and not produce any result. The statistics will be available in the `stats` attribute, and the `result` attribute will be `Empty`.

#### :uid(&filter)

If specified, indicates the `Callable` filter that should be used to select acceptable paths by the **uid** of the path. The `Callable` is passed the numeric uid of a path and is expected to return a trueish value to have the path be considered for further selection. See also `owner` and `group` filters.

#### :under-version-control($name = 'git')

If specified, indicates that any path specification that is a directory, should be considered as the root of a directory structure under some form of version control. If specified as `True`, will assume `git`. If such a path is under version control, then only files that are actually controlled, will be produced for further inspection. If it is **not** under version control, **no** files will be produced.

Currently, only `git` is supported.

#### :unique

Flag. If specified, indicates that only unique matches will be returned, instead of the normal sequence of source => result pairs.

#### :with-line-ending

Flag. If specified, indicates line endings are to be kept when producing items to check. Defaults to `False`, meaning that line endings are removed from items to check. Only applicable with line-based checking.

PATTERN RETURN VALUES
---------------------

The return value of the pattern `Callable` match is interpreted in the following way:

### True

If the `Bool`ean True value is returned, assume the pattern is found. Produce the item unless `:invert-match` was specified.

### False

If the `Bool`ean False value is returned, assume the pattern is **not** found. Do **not** produce the item unless `:invert-match` was specified.

### Nil

If `Nil` is returned, assume the pattern is **not** found. This can typically happen when a `try` is used in a pattern, and an execution error occurred. Do **not** produce the item unless `:invert-match` was specified.

### Empty

If the empty `Slip` is returned, assume the pattern is **not** found. Do **not** produce the item unless `:invert-match` was specified. Shown in stats as a `passthru`.

### any other value

Produce that value.

PHASERS
-------

Any `FIRST`, `NEXT` and `LAST` phaser that are specified in the pattern `Callable`, will be executed at the correct time.

MATCHED ITEMS vs CONTEXT ITEMS
------------------------------

The `Pair`s that contain the search result within an object, have an additional method mixed in: `matched`. This returns `True` for items that matched, and `False` for items that have been added because of a context specification (`:context`, `:before-context`, `:after-context`, `paragraph-context` or `passthru-context`).

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

