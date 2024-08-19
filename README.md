[![Actions Status](https://github.com/lizmat/rak/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/rak/actions) [![Actions Status](https://github.com/lizmat/rak/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/rak/actions) [![Actions Status](https://github.com/lizmat/rak/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/rak/actions)

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

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:dir</td> <td>filter for directory basename check to include</td> </tr> <tr> <td>:file</td> <td>filter for file basename check to include</td> </tr> <tr> <td>:files-from</td> <td>file containing filenames as source</td> </tr> <tr> <td>:ioify</td> <td>code to create IO::Path-like objects with</td> </tr> <tr> <td>:paths</td> <td>paths to recurse into if directory</td> </tr> <tr> <td>:paths-from</td> <td>file containing paths to recurse into</td> </tr> <tr> <td>:recurse-symlinked-dir</td> <td>recurse into symlinked directories</td> </tr> <tr> <td>:recurse-unmatched-dir</td> <td>recurse into directories not matching :dir</td> </tr> <tr> <td>:sources</td> <td>list of objects to be considered as source</td> </tr> <tr> <td>:under-version-control</td> <td>only include paths under version control</td> </tr>
</tbody>
</table>

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 2. Filter applicable objects

Filter down the list of sources from step 1 on any additional filesystem related properties. This assumes that the list of objects created are strings of absolute paths to be checked (except where otherwise indicated).

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:accept</td> <td>given an IO::Path, is path acceptable</td> </tr> <tr> <td>:accessed</td> <td>when was path last accessed</td> </tr> <tr> <td>:blocks</td> <td>number of filesystem blocks</td> </tr> <tr> <td>:created</td> <td>when was path created</td> </tr> <tr> <td>:deny</td> <td>given an IO::Path, is path NOT acceptable</td> </tr> <tr> <td>:device-number</td> <td>device number on which path is located</td> </tr> <tr> <td>:exec</td> <td>run program, include if successful</td> </tr> <tr> <td>:filesize</td> <td>size of the path in bytes</td> </tr> <tr> <td>:gid</td> <td>numeric gid of the path</td> </tr> <tr> <td>:hard-links</td> <td>number of hard-links to path on filesystem</td> </tr> <tr> <td>:has-setgid</td> <td>has SETGID bit set in attributes</td> </tr> <tr> <td>:has-setuid</td> <td>has SETUID bit set in attributes</td> </tr> <tr> <td>:inode</td> <td>inode of path on filesystem</td> </tr> <tr> <td>:is-empty</td> <td>is path empty (filesize == 0)</td> </tr> <tr> <td>:is-executable</td> <td>is path executable by current user</td> </tr> <tr> <td>:is-group-executable</td> <td>is path executable by group</td> </tr> <tr> <td>:is-group-readable</td> <td>is path readable by group</td> </tr> <tr> <td>:is-group-writable</td> <td>is path writable by group</td> </tr> <tr> <td>:is-moarvm</td> <td>is path a MoarVM bytecode file</td> </tr> <tr> <td>:is-owned-by-group</td> <td>is path owned by group of current user</td> </tr> <tr> <td>:is-owned-by-user</td> <td>is path owned by current user</td> </tr> <tr> <td>:is-owner-executable</td> <td>is path executable by owner</td> </tr> <tr> <td>:is-owner-readable</td> <td>is path readable by owner</td> </tr> <tr> <td>:is-owner-writable</td> <td>is path writable by owner</td> </tr> <tr> <td>:is-pdf</td> <td>is path a PDF file</td> </tr> <tr> <td>:is-readable</td> <td>is path readable by current user</td> </tr> <tr> <td>:is-sticky</td> <td>has STICKY bit set in attributes</td> </tr> <tr> <td>:is-symbolic-link</td> <td>is path a symbolic link</td> </tr> <tr> <td>:is-text</td> <td>does path contains text?</td> </tr> <tr> <td>:is-world-executable</td> <td>is path executable by any user</td> </tr> <tr> <td>:is-world-readable</td> <td>is path readable by any user</td> </tr> <tr> <td>:is-world-writable</td> <td>is path writable by any user</td> </tr> <tr> <td>:is-writable</td> <td>is path writable by current user</td> </tr> <tr> <td>:meta-modified</td> <td>when meta information of path was modified</td> </tr> <tr> <td>:mode</td> <td>the mode of the path</td> </tr> <tr> <td>:modified</td> <td>when path was last modified</td> </tr> <tr> <td>:shell</td> <td>run shell command, include if successful</td> </tr> <tr> <td>:uid</td> <td>numeric uid of path</td> </tr>
</tbody>
</table>

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 3. Produce items to search in (apply transformers)

The third step is to create the logic for creating items to search in from the objects in step 2. If search is to be done per object, then `.slurp` is called on the object. Otherwise `.lines` is called on the object. Unless one provides their own logic for producing items to search in.

Related named arguments are (in alphabetical order):

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:encoding</td> <td>encoding to be used when creating items</td> </tr> <tr> <td>:find</td> <td>map sequence of step 1 to item producer</td> </tr> <tr> <td>:produce-one</td> <td>produce one item per given source</td> </tr> <tr> <td>:produce-many</td> <td>produce zero or more items by given source</td> </tr> <tr> <td>:produce-many-pairs</td> <td>produce 0+ items by given source as pairs</td> </tr> <tr> <td>:omit-item-number</td> <td>do not store item numbers in result</td> </tr> <tr> <td>:with-line-ending</td> <td>produce lines with line endings</td> </tr>
</tbody>
</table>

The result of this step, is a (potentially lazy and hyperable) sequence of objects.

### 4. Create logic for matching

Take the logic of the pattern `Callable`, and create a `Callable` to do the actual matching with the items produced in step 3.

Related named arguments are (in alphabetical order):

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:invert-match</td> <td>invert the logic of matching</td> </tr> <tr> <td>:old-new</td> <td>produce pairs of old/new state</td> </tr> <tr> <td>:quietly</td> <td>absorb any warnings produced by the matcher</td> </tr> <tr> <td>:silently</td> <td>absorb any output done by the matcher</td> </tr> <tr> <td>:stats</td> <td>produce results and full statistics</td> </tr> <tr> <td>:stats-only</td> <td>don&#39;t produce results, just statistics</td> </tr>
</tbody>
</table>

### 5. Create logic for running

Take the matcher logic of the `Callable` of step 4 and create a runner `Callable` that will produce the items found and their possible context (such as extra items before or after). Assuming no context, the runner changes a return value of `False` from the matcher into `Empty`, a return value of `True` in the original item, and passes through any other value.

Related named arguments are (in alphabetical order):

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:also-first</td> <td>initial items to show if there is a match</td> </tr> <tr> <td>:always-first</td> <td>initial items to show always</td> </tr> <tr> <td>:after-context</td> <td>number of items to show after a match</td> </tr> <tr> <td>:before-context</td> <td>number of items to show before a match</td> </tr> <tr> <td>:context</td> <td>number of items to show around a match</td> </tr> <tr> <td>:paragraph-context</td> <td>items around match until false item</td> </tr> <tr> <td>:passthru-context</td> <td>pass on *all* items if there is a match</td> </tr> <tr> <td>:max-matches-per-source</td> <td>max # of matches per source</td> </tr> <tr> <td>:passthru</td> <td>pass on *all* items always</td> </tr>
</tbody>
</table>

Matching items are represented by `PairMatched` objects, and items that have been added because of the above context arguments, are represented by `PairContext` objects. Unless `:omit-item-number` has been specified with a trueish value, in which case items will always be just a string, whether they matched or not (if part of a context specification).

### 6. Run the sequence(s)

The final step is to take the `Callable` of step 5 and run that repeatedly on the sequence of step 3. Make sure any phasers (`FIRST`, `NEXT` and `LAST`) are called at the appropriate time in a thread-safe manner. Inside the `Callable` of step 5, the dynamic variable `$*SOURCE` will be set to the source of the items being checked.

Either produces a sequence in which the key is the source, and the value is a `Slip` of `Pair`s where the key is the item-number and the value is item with the match, or whatever the pattern matcher returned.

Or, produces sequence of whatever a specified mapper returned and/or with uniqueifying enabled.

Related named arguments are (in alphabetical order):

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>:categorize</td> <td>classify items according to zero or more keys</td> </tr> <tr> <td>:classify</td> <td>classify items according to a single key</td> </tr> <tr> <td>:eager</td> <td>produce all results before creating Rak object</td> </tr> <tr> <td>:frequencies</td> <td>produce items and their frequencies</td> </tr> <tr> <td>:map-all</td> <td>also call mapper if a source has no matches</td> </tr> <tr> <td>:mapper</td> <td>code to map results of a single source</td> </tr> <tr> <td>:progress</td> <td>code to show progress of running</td> </tr> <tr> <td>:sort</td> <td>sort the result of :unique</td> </tr> <tr> <td>:sort-sources</td> <td>sort the sources before processing</td> </tr> <tr> <td>:sources-only</td> <td>only produce the source of any match</td> </tr> <tr> <td>:sources-without-only</td> <td>produce the source without any match</td> </tr> <tr> <td>:unique</td> <td>only produce unique items</td> </tr>
</tbody>
</table>

EXPORTED CLASSES
================

Rak
---

The return value of a `rak` search. Contains the following attributes:

### completed

A `Bool` indicating whether the search has already been completed.

### exception

Any `Exception` object that was caught.

### nr-changes

Number of items (that would have been) changed.

### nr-items

Number of items inspected.

### nr-matches

Number of items that matched.

### nr-passthrus

Number of items that have passed through.

### nr-sources

Number of sources seen.

### result

A `Seq` with search results. This could be a lazy `Seq` or a `Seq` on a fully vivified `List`.

### stats

A `Map` with any statistics collected (so far, in case an exception was thrown). If the `Map` is not empty, it contains the following keys:

<table class="pod-table">
<thead><tr>
<th>argument</th> <th>meaning</th>
</tr></thead>
<tbody>
<tr> <td>nr-sources</td> <td>number of sources seen</td> </tr> <tr> <td>nr-items</td> <td>number of items inspected</td> </tr> <tr> <td>nr-matches</td> <td>number of items that matched</td> </tr> <tr> <td>nr-passthrus</td> <td>number of items that have passed through</td> </tr> <tr> <td>nr-changes</td> <td>number of items that would have been changed</td> </tr>
</tbody>
</table>

If the `Map` is empty, then no statistics (other than `nr-sources`) have been collected.

Note that if the result is lazy, then the statistics won't be complete until every result has been processed.

PairContext
-----------

A subclass of `Pair` of which both the `matched` **and** `changed` method return `False`. Used for non-matching items when item-numbers are required to be returned and a certain item context was requested.

PairMatched
-----------

A subclass of `PairContext` of which the `matched` method returns `True`, but the `changed` method returns `False`. Used for matching items when item-numbers are required to be returned.

PairChanged
-----------

A subclass of `PairMatched` of which the `matched` **and** `changed` method return `True`. Used for changed items when item-numbers are required to be returned.

Progress
--------

Passed to the `:progress` `Callable` 5 times per second while searching is taking place. It provides several methods that allow a search application to show what is going on.

### nr-changes

Number of items (that would have been) changed. Continuously updated if the search has not been completed yet.

### nr-items

Number of items inspected. Continuously updated if the search has not been completed yet.

### nr-matches

Number of items that matched. Continuously updated if the search has not been completed yet.

### nr-passthrus

Number of items that have passed through. Continuously updated if the search has not been completed yet.

### nr-sources

Number of sources seen. Continuously updated if the search has not been completed yet.

EXPORTED SUBROUTINES
====================

rak
---

The `rak` subroutine takes a `Callable` (or `Regex`) pattern as the only positional argument and quite a number of named arguments. Or it takes a `Callable` (or `Regex`) as the first positional argument for the pattern, and a hash with named arguments as the second positional argument. In the latter case, the hash will have the arguments removed that the `rak` subroutine needed for its configuration and execution.

### Return value

A `Rak` object (see above) is always returned. The object provides three attributes: `result` (with the result `Iterable`), `completed` (a Bool indicating whether all searching has been done already), and `exception` (any `Exception` object or `Nil`).

Additionally it provides five methods that allow you to monitor progress and/or provide statistics at the end of a search. They are: `nr-sources`, `nr-items`, `nr-matches`, `nr-changes`, `nr-passthrus`.

#### Result Iterable

If the `:unique` argument was specified with a trueish value, then the result `Iterable` will just produce the unique values that were either explicitely returned by the matcher, or the unique items that matched.

Otherwise the value is an `Iterable` of `Pair`s which contain the source object as key (by default the absolute path of the file in which the pattern was found).

If there was only one item produced per source, then the value will be that value, or whatever was produced by the matching logic.

Otherwise the value will be a `Slip`. If no item numbers were requested, each element contains the result of matching. If item-numbers were requested, each element is a `Pair`, of which the key is the item-number where the pattern was found, and the value is the product of the search (which, by default, is the item in which the pattern was found).

In a graph:

    rak(...)
     |- Rak
         |- exception: Exception object or Nil
         |- nr-sources: number of sources seen
         |- nr-items: number of items seen
         |- nr-matches: number of matches seen
         |- nr-changes: number of changes (that could be) done
         |- nr-passthrus: number of passthrus done
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

#### :also-first(N)

Indicate the number of initial items to be produced **if** there is an item with a pattern match. Defaults to **0**. If specified as a flag, will assume **1**.

#### :always-first(N)

Indicate the number of initial items to be **always** be produced regardless whether there is an item with a pattern match or not. Defaults to **0**. If specified as a flag, will assume **1**.

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

#### :is-moarvm

Flag. If specified, indicates only paths that are `MoarVM` bytecode files are (not) acceptable for further selection.

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

#### :is-pdf

Flag. If specified, indicates only paths that are `PDF` files are (not) acceptable for further selection.

#### :is-readable

Flag. If specified, indicates paths, that are **readable** by the current **user**, are (not) acceptable for further selection.

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

Indicate the maximum number of items that may be produce per source. Defaults to **all** (which can also be specified by a falsish value).

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

#### :produce-many(&producer)

If specified, indicates a `Callable` that will be called given a source, and is expected to produce zero or more items to be inspected. Defaults to a producer that calles the `lines` method on a given source, with the `:encoding` and `:with-line-ending` arguments.

The `Callable` should return `Empty` if for some reason nothing could be produced.

#### :produce-many-pairs(&producer)

If specified, indicates a `Callable` that will be called given a source, and is expected to produce zero or more `PairContext` objects to be inspected, in which the key represents the item number.

This option will set the `:omit-item-number` option to `False`.

The `Callable` should return `Empty` if for some reason nothing could be produced.

#### :produce-one(&producer)

If specified, indicates a `Callable` that will be called given a source, and is expected to produce one items to be inspected.

The `Callable` should return `Nil` if for some reason nothing could be produced).

#### :progress(&announcer)

If specified, indicates a `Callable` that will be called 5 times per second to indicate how the search action is progressing. It will either be called with a `Progress` object (while the search action is still progressing) or **without** any arguments to indicate that search has completed.

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

When specified with `True`, will sort the result alphabetically (using foldcase logic). Can also be specified with a `Callable`, which should contain the logic sorting (just as the argument to the `.sort` method).

Only supported with `:unique` at this time.

#### :sort-sources(&logic)

When specified with `True`, will sort the sources alphabetically (using foldcase logic). Can also be specified with a `Callable`, which should contain the logic sorting (just as the argument to the `.sort` method).

#### :sources(@objects)

If specified, indicates a list of objects that should be used as a source for the production of items. Which generally means they cannot be just strings.

#### :sources-only

Flag. If specified with a trueish value, will only produce the source of a match once per source. Defaults to `False`.

#### :sources-without-only

Flag. If specified with a trueish value, will only produce the source of a match if there is **not** a single match. Defaults to `False`.

#### :stats

Flag. If specified with a trueish value, will keep stats on number number of items seen, number of matches, number of changes and number of passthrus. Stats on number of sources seen, will always be kept.

Note that on lazy results, the statistics won't be complete until all results have been processed.

#### :stats-only

Flag. If specified with a trueish value, will perform all searching, but only update counters and not produce any result. The statistics will be available in `nr-xxx` methods, and the `result` attribute will be `Empty`. Note that this causes eager evaluation.

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

Copyright 2022, 2023, 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

