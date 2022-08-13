# The modules that we need here, with their full identities
use has-word:ver<0.0.3>:auth<zef:lizmat>;
use hyperize:ver<0.0.2>:auth<zef:lizmat>;
use paths:ver<10.0.7>:auth<zef:lizmat>;
use path-utils:ver<0.0.4>:auth<zef:lizmat>;
use Trap:ver<0.0.1>:auth<zef:lizmat>;

my class PairMatched is Pair is export { method matched(--> True)  { } }
my class PairContext is Pair is export { method matched(--> False) { } }

# Return a Seq with ~ paths substituted for actual home directory paths
my sub paths-from-file($from) {
    my $home := $*HOME.absolute ~ '/';
    ($from eq '-'
      ?? $*IN.lines
      !! $from.subst(/^ '~' '/'? /, $home).IO.lines
    ).map:
      *.subst(/^ '~' '/'? /, $home)
}

# Return a Map with named arguments for "paths"
my sub paths-arguments(%_) {
    my $dir             := (%_<dir>:delete)             // True;
    my $file            := (%_<file>:delete)            // True;
    my $follow-symlinks := (%_<follow-symlinks>:delete) // False;
    Map.new: (:$dir, :$file, :$follow-symlinks)
}

# Convert a given seq producing paths to a seq producing files
my sub paths-to-files($seq, $degree, %_) {
    my %paths-arguments := paths-arguments(%_);
    $seq.&hyperize(1, $degree).map: {
        is-regular-file($_)
          ?? $_
          !! paths($_, |%paths-arguments).Slip
    }
}

# Adapt a sources sequence to apply any property filters specified
my sub make-property-filter($seq is copy, %_) {
    if %_<modified>:delete -> &modified {
        $seq = $seq.map: -> $path {
            modified(path-modified($path)) ?? $path !! Empty
        }
    }
    if %_<created>:delete -> &created {
        $seq = $seq.map: -> $path {
            created(path-created($path)) ?? $path !! Empty
        }
    }
    if %_<accessed>:delete -> &accessed {
        $seq = $seq.map: -> $path {
            accessed(path-accessed($path)) ?? $path !! Empty
        }
    }
    if %_<meta-modified>:delete -> &meta-modified {
        $seq = $seq.map: -> $path {
            meta-modified(path-meta-modified($path)) ?? $path !! Empty
        }
    }
    if %_<filesize>:delete -> &filesize {
        $seq = $seq.map: -> $path {
            filesize(path-filesize($path)) ?? $path !! Empty
        }
    }

    if %_<mode>:delete -> &mode {
        $seq = $seq.map: -> $path { mode(path-mode($path)) ?? $path !! Empty }
    }
    if %_<uid>:delete -> &uid {
        $seq = $seq.map: -> $path { uid(path-uid($path)) ?? $path !! Empty }
    }
    if %_<gid>:delete -> &gid {
        $seq = $seq.map: -> $path { gid(path-gid($path)) ?? $path !! Empty }
    }

    if %_<device-number>:delete -> &device-number {
        $seq = $seq.map: -> $path {
            device-number(path-device-number($path)) ?? $path !! Empty
        }
    }
    if %_<inode>:delete -> &inode {
        $seq = $seq.map: -> $path {
            inode(path-inode($path)) ?? $path !! Empty
        }
    }
    if %_<hard-links>:delete -> &hard-links {
        $seq = $seq.map: -> $path {
            hard-links(path-hard-links($path)) ?? $path !! Empty
        }
    }
    if %_<blocks>:delete -> &blocks {
        $seq = $seq.map: -> $path {
            blocks(path-blocks($path)) ?? $path !! Empty
        }
    }

    if %_<owned-by-user>:exists {
        $seq = $seq.map:
          (%_<owned-by-user>:delete)
            ?? -> $path { path-is-owned-by-user($path) ?? $path !! Empty }
            !! -> $path { path-is-owned-by-user($path) ?? Empty !! $path }
    }
    if %_<owned-by-group>:exists {
        $seq = $seq.map:
          (%_<owned-by-group>:delete)
            ?? -> $path { path-is-owned-by-group($path) ?? $path !! Empty }
            !! -> $path { path-is-owned-by-group($path) ?? Empty !! $path }
    }

    if %_<readable>:exists {
        $seq = $seq.map:
          (%_<readable>:delete)
            ?? -> $path { path-is-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-readable($path) ?? Empty !! $path }
    }
    if %_<writable>:exists {
        $seq = $seq.map:
          (%_<writable>:delete)
            ?? -> $path { path-is-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-writable($path) ?? Empty !! $path }
    }
    if %_<executable>:exists {
        $seq = $seq.map:
          (%_<executable>:delete)
            ?? -> $path { path-is-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-executable($path) ?? Empty !! $path }
    }

    if %_<group-readable>:exists {
        $seq = $seq.map:
          (%_<readable>:delete)
            ?? -> $path { path-is-group-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-readable($path) ?? Empty !! $path }
    }
    if %_<group-writable>:exists {
        $seq = $seq.map:
          (%_<group-writable>:delete)
            ?? -> $path { path-is-group-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-writable($path) ?? Empty !! $path }
    }
    if %_<group-executable>:exists {
        $seq = $seq.map:
          (%_<group-executable>:delete)
            ?? -> $path { path-is-group-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-executable($path) ?? Empty !! $path }
    }

    if %_<world-readable>:exists {
        $seq = $seq.map:
          (%_<world-readable>:delete)
            ?? -> $path { path-is-world-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-readable($path) ?? Empty !! $path }
    }
    if %_<world-writable>:exists {
        $seq = $seq.map:
          (%_<world-writable>:delete)
            ?? -> $path { path-is-world-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-writable($path) ?? Empty !! $path }
    }
    if %_<world-executable>:exists {
        $seq = $seq.map:
          (%_<world-executable>:delete)
            ?? -> $path { path-is-world-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-executable($path) ?? Empty !! $path }
    }

    $seq
}

# Return a matcher Callable for a given pattern.
my sub make-matcher(&pattern, %_) {
    my &matcher := %_<invert-match>:delete
      ?? -> $haystack {
             Bool.ACCEPTS(my $result := pattern($haystack))
               ?? !$result
               !! $result
         }
      !! &pattern;

    my $silently := (%_<silently>:delete)<>;
    if %_<quietly>:delete {
        # the existence of a CONTROL block appears to disallow use of ternaries
        # 2202.07
        if $silently {
            if $silently =:= True || $silently eq 'out,err' | 'err,out' {
                -> $haystack {
                    CONTROL { .resume if CX::Warn.ACCEPTS($_) }
                    Trap(my $*OUT, my $*ERR);
                    matcher($haystack)
                }
            }
            elsif $silently eq 'out' {
                -> $haystack {
                    CONTROL { .resume if CX::Warn.ACCEPTS($_) }
                    Trap(my $*OUT);
                    matcher($haystack)
                }
            }
            elsif $silently eq 'err' {
                -> $haystack {
                    CONTROL { .resume if CX::Warn.ACCEPTS($_) }
                    Trap(my $*ERR);
                    matcher($haystack)
                }
            }
            else {
                die "Unexpected value for --silently: $silently"
            }
        }
        else {
            -> $haystack {
                CONTROL { .resume if CX::Warns.ACCEPTS($) }
                matcher($haystack)
            }
        }
    }
    elsif $silently {  # and not quietly
        $silently =:= True || $silently eq 'out,err' | 'err,out'
            ?? -> $haystack { Trap(my $*OUT, my $*ERR); matcher($haystack) }
            !! $silently eq 'out'
              ?? -> $haystack { Trap(my $*OUT); matcher($haystack) }
              !! $silently eq 'err'
                ?? -> $haystack { Trap(my $*ERR); matcher($haystack) }
                !! die "Unexpected value for --silently: $silently"
    }
    else {
        &matcher
    }
}

# Return a runner Callable for paragrap context around lines
my sub make-passthru-context-runner(&matcher) {
    -> $item {
        my $result := matcher($item.value);

        $result =:= False
          ?? $item
          !! PairMatched.new:
               $item.key,
               $result =:= True ?? $item.value !! $result
    }
}

# Return a runner Callable for paragrap context around lines
my sub make-paragraph-context-runner(&matcher) {
    my $after;
    my @before;
    -> $item {
        my $result := matcher($item.value);

        # no match
        if $result =:= False || $result =:= Empty {
            if $after {
                if $item.value {
                    $item
                }
                else {
                    $after = False;
                    Empty
                }
            }
            else {
                @before.push: $item;
                Empty
            }
        }

        # match or something else was produced from match
        else {
            $after = True;
            @before.push(
              PairMatched.new:
                $item.key,
                $result =:= True ?? $item.value !! $result
            ).splice.Slip
        }
    }
}

# Return a runner Callable for numeric context around lines
my sub make-numeric-context-runner(&matcher, $before, $after) {
    if $before {
        my $todo;
        my @before;
        -> $item {
            my $result := matcher($item.value);

            # no match
            if $result =:= False || $result =:= Empty {
                if $todo {
                    --$todo;
                    $item
                }
                else {
                    @before.shift if @before.elems == $before;
                    @before.push: $item;
                    Empty
                }
            }

            # match or something was produced from match
            else {
                $todo = $after;
                @before.push(
                  PairMatched.new:
                    $item.key,
                    $result =:= True ?? $item.value !! $result
                ).splice.Slip
            }
        }
    }
    else {
        my $todo;
        -> $item {
            my $result := matcher($item.value);

            # no match
            if $result =:= False || $result =:= Empty {
                if $todo {
                    --$todo;
                    $item
                }
                else {
                    Empty
                }
            }

            # match or something was produced from match
            else {
                $todo = $after;
                PairMatched.new:
                  $item.key,
                  $result =:= True ?? $item.value !! $result
            }
        }
    }
}

# Base case of a runner from a matcher
sub make-runner(&matcher) {
    -> $item {
        my $result := matcher($item.value);
        $result =:= False
          ?? Empty
          !! $result =:= Empty
            ?? $item
            !! PairMatched.new:
                 $item.key,
                 $result =:= True ?? $item.value !! $result
    }
}

proto sub rak(|) is export {*}
multi sub rak(&pattern, *%n) {
    rak &pattern, %n
}
multi sub rak(&pattern, %n) {
    # any execution error will ne caught and become a return state
    CATCH { return $_ => .message }

    # Some settings we always need
    my $batch  := %n<batch>:delete;
    my $degree := %n<degree>:delete;
    my $enc    := %n<encoding>:delete // 'utf8-c8';

    # Step 1: sources sequence
    my $sources-seq = do if %n<files-from>:delete -> $files-from {
        paths-from-file($files-from)
    }
    elsif %n<paths-from>:delete -> $paths-from {
        paths-to-files(paths-from-file($paths-from), $degree, %n)
    }
    elsif %n<paths>:delete -> $paths {
        if $paths eq '-' {
            $*IN
        }
        else {
            my $home := $*HOME.absolute ~ '/';
            paths-to-files(
              $paths.map(*.subst(/^ '~' '/'? /, $home)),
              $degree,
              %n
            )
        }
    }
    elsif %n<sources>:delete -> $sources {
        $sources
    }
    else {
        paths ".", |paths-arguments(%n)
    }

    # Step 2. filtering on properties
    $sources-seq = make-property-filter($sources-seq, %n);

    # Step 3: producer Callable
    my &producer := do if (%n<per-file>:delete)<> -> $per-file {
        $per-file =:= True
          ?? -> $source {
                 CATCH { return Empty }
                 (PairContext.new: 1, Str.ACCEPTS($source)
                   ?? $source.IO.slurp(:$enc)
                   !! $source.slurp(:$enc),
                 )
             }
          !! $per-file  # assume Callable
    }
    elsif (%n<per-line>:delete)<> -> $per-line {
        $per-line =:= True
          ?? -> $source {
                 CATCH { return Empty }
                 my $seq := Str.ACCEPTS($source)
                   ?? $source.IO.lines(:$enc)
                   !! $source.lines(:$enc);
                 my $line-number = 0;
                 $seq.map: { PairContext.new: ++$line-number, $_ }
             }
          !! $per-line  # assume Callable
    }
    elsif %n<find>:delete {
        my $seq := $sources-seq<>;
        $sources-seq = ("<find>",);
        my $line-number = 0;
        -> $ { $seq.map: { PairContext.new: ++$line-number, $_ } }
    }
    else {
        -> $source {
            CATCH { return Empty }
            my $seq := Str.ACCEPTS($source)
              ?? $source.IO.lines(:$enc)
              !! $source.lines(:$enc);
            my $line-number = 0;
            $seq.map: { PairContext.new: ++$line-number, $_ }
        }
    }

    # Step 4: matching logic
    # The matcher Callable should take a haystack as the argument, and
    # call the pattern with that.  And optionally do some massaging to make
    # sure we get the right thing.  But in all other aspects, the matcher
    # has the same API as the pattern.
    my &matcher = make-matcher(
      Regex.ACCEPTS(&pattern) ?? *.contains(&pattern) !! &pattern,
      %n
    );

    # Add any stats keeping if necessary
    my $stats := %n<stats>:delete;
    my atomicint $nr-lines;
    my atomicint $nr-matches;
    if $stats {
        my &old-matcher = &matcher;
        &matcher = -> $_ {
            ++⚛$nr-lines;
            my $result := old-matcher($_);
            ++⚛$nr-matches if $result;
            $result
        }
    }

    # Step 5: contextualizing logic
    # The runner Callable should take a PairContext object as the argument,
    # and call the matcher with that.  If the result is True, then it should
    # produce that line as a PairMatched object with the original value, and
    # any other lines as as PairContext objects.  If the result is False, it
    # should produce Empty.  In any other case, it should produce a
    # PairMatched object with the original key, and the value returned by
    # the matcher as its value.
    my &runner := do if %n<context>:delete -> $context {
        make-numeric-context-runner(&matcher, $context, $context)
    }
    elsif %n<before-context>:delete -> $before {
        make-numeric-context-runner(&matcher, $before, %n<after-context>:delete)
    }
    elsif %n<after-context>:delete -> $after {
        make-numeric-context-runner(&matcher, Any, $after)
    }
    elsif %n<paragraph-context>:delete {
        make-paragraph-context-runner(&matcher)
    }
    elsif %n<passthru-context>:delete {
        make-passthru-context-runner(&matcher)
    }
    else {
        make-runner(&matcher)
    }

    # Step 6: run the sequences
    my &first-phaser;
    my &next-phaser;
    my &last-phaser;
    if &pattern.has-loop-phasers {
        &first-phaser = &pattern.callable_for_phaser('FIRST');
        &next-phaser  = &pattern.callable_for_phaser('NEXT');
        &last-phaser  = &pattern.callable_for_phaser('LAST');
    }

    # Set up result sequence
    first-phaser() if &first-phaser;
    my atomicint $nr-files;
    my $result-seq := do if &next-phaser {
        my $lock := Lock.new;
        $sources-seq.map: -> $source {
            ++⚛$nr-files;
            my \result :=
              Pair.new: $source, (producer($source).map: &runner).Slip;
            $lock.protect: &next-phaser;
            result
        }
    }
    else {
        $sources-seq.map: -> $source {
            ++⚛$nr-files;
            Pair.new: $source, (producer($source).map: &runner).Slip
        }
    }

    # If we want to have stats, we need to run all searches
    if $stats {
        my @result = $result-seq;
        last-phaser() if &last-phaser;
        (@result, Map.new: (:$nr-files, :$nr-lines))
    }

    # With a LAST phaser, need to run all searches before firing
    elsif &last-phaser {
        my @result = $result-seq;
        last-phaser();
        @result
    }

    # No LAST phaser, let the caller handle laziness
    else {
        $result-seq
    }
}

=begin pod

=head1 NAME

rak - look for clues in stuff

=head1 SYNOPSIS

=begin code :lang<raku>

use rak;

for rak *.contains("foo") -> (:key($path), :value(@found)) {
    if @found {
        say "$path:";
        say .key ~ ':' ~ .value for @found;
    }
}

=end code

=head1 DESCRIPTION

The C<rak> subroutine provides a mostly abstract core search
functionality to be used by modules such as C<App::Rak>.

=head1 THEORY OF OPERATION

The C<rak> subroutine basically goes through 6 steps to produce a
result.

=head2 1. Acquire sources

The first step is determining the objects that should be searched
for the specified pattern.  If an object is a C<Str>, it will be
assume that it is a path specification of a file to be searched in
some form and an C<IO::Path> object will be created for it.

Related named arguments are (in alphabetical order):

=item :dir - filter for directory basename check to include
=item :file - filter for file basename check to include
=item :files-from - file containing filenames as source
=item :paths - paths to recurse into if directory
=item :paths-from - file containing paths to recurse into
=item :sources - list of objects to be considered as source

The result of this step, is a (potentially lazy and hyperable)
sequence of objects.

=head2 2. Filter applicable objects

Filter down the list of sources from step 1 on any additional filesystem
related properties.  This assumes that the list of objects created, are
strings of absolute paths to be checked.

=item :accessed - when was path last accessed
=item :blocks- number of filesystem blocks
=item :created - when was path created
=item :device-number - device number on which path is located
=item :executable - is path executable
=item :filesize - size of the path in bytes
=item :gid - numeric gid of the path
=item :group-executable - is path executable by group
=item :group-readable - is path readable by group
=item :group-writable - is path writable 
=item :hard-links - number of hard-links to path on filesystem
=item :inode - inode of path on filesystem
=item :meta-modified - when meta information of path was modified
=item :mode - the mode of the path
=item :modified - when path was last modified
=item :owned-by-group - is path owned by group of current user
=item :owned-by-user - is path owned by current user
=item :readable - is path readable by current user
=item :uid - numeric uid of path
=item :world-executable - is path executable by any user
=item :world-readable - is path readable by any user
=item :world-writable - is path writable by any user
=item :writable - is path writable by current user

The result of this step, is a (potentially lazy and hyperable)
sequence of objects.

=head3 3. Produce items to search in

The second step is to create the logic for creating items to
search in from the objects in step 1.  If search is to be done
per object, then C<.slurp> is called on the object.  Otherwise
C<.lines> is called on the object.  Unless one provides their
own logic for producing items to search in.

Related named arguments are (in alphabetical order):

=item :encoding - encoding to be used when creating items
=item :find - map sequence of step 1 to item producer
=item :per-file - logic to create one item per object
=item :per-line - logic to create one item per line in the object

The result of this step, is a (potentially lazy and hyperable)
sequence of objects.

=head3 4. Create logic for matching

Take the logic of the pattern C<Callable>, and create a C<Callable> to
do the actual matching with the items produced in step 2.

Related named arguments are (in alphabetical order):

=item :invert-match - invert the logic of matching
=item :quietly - absorb any warnings produced by the matcher
=item :silently - absorb any output done by the matcher

=head3 5. Create logic for running

Take the matcher logic of the C<Callable> of step 3 and create a runner
C<Callable> that will produce the items found and their possible context
(such as extra lines before or after).  Assuming no context, the runner
changes a return value of C<False> from the matcher into C<Empty>, a
return value of C<True> in the original line, and passes through any other
value.

Matching lines are C<PairMatched> objects, and lines that have been added
because of context are C<PairContext> objects.

Related named arguments are (in alphabetical order):

=item :after-context - number of lines to show after a match
=item :before-context - number of lines to show before a match
=item :context - number of lines to show around a match
=item :paragraph-context - lines around match until empty line
=item :passthru-context - pass on *all* lines

=head3 6. Run the sequence(s)

The final step is to take the C<Callable> of step 4 and run that
repeatedly on the sequence of step 1, and for each item of that
sequence, run the sequence of step 2 on that.  Make sure any
phasers (C<FIRST>, C<NEXT> and C<LAST>) are called at the appropriate
time in a thread-safe manner.  And produce a sequence in which the
key is the source, and the value is a C<Slip> of C<Pair>s where the
key is the line-number and the value is line with the match, or
whatever the pattern matcher returned.

=head1 EXPORTED SUBROUTINES

=head2 rak

The C<rak> subroutine takes a C<Callable> (or C<Regex>) pattern as the only
positional argument and quite a number of named arguments.  Or it takes a
C<Callable> (or C<Regex>) as the first positional argument for the pattern,
and a hash with named arguments as the second positional argument.  In the
latter case, the hash will have the arguments removed that the C<rak>
subroutine needed for its configuration and execution.

It returns either a C<Pair> (with an C<Exception> as key, and the
exception message as the value), or an C<Iterable> of C<Pair>s which
contain the source object as key (by default a C<IO::Path> object
of the file in which the pattern was found), and a C<Slip> of
key / value pairs, in which the key is the line-number where the
pattern was found, and the value is the product of the search
(which, by default, is the line in which the pattern was found).

The following named arguments can be specified (in alphabetical
order):

=head3 :accessed(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<access> time of the path.  The C<Callable> is
passed a C<Num> value of the access time (number of seconds since epoch)
and is expected to return a trueish value to have the path be considered
for further selection.

=head3 :after-context(N)

Indicate the number of lines that should also be returned B<after>
a line with a pattern match.  Defaults to B<0>.

=head3 :batch(N)

When hypering over multiple cores, indicate how many items should be
processed per thread at a time.  Defaults to whatever the system
thinks is best (which B<may> be sub-optimal).

=head3 :before-context(N)

Indicate the number of lines that should also be returned B<before>
a line with a pattern match.  Defaults to B<0>.

=head3 :blocks(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<number of blocks> used by the path on the filesystem
on which the path is located.  The C<Callable> is passed the number of blocks
of a path and is expected to return a trueish value to have the path be
considered for further selection.

=head3 :context(N)

Indicate the number of lines that should also be returned around
a line with a pattern match.  Defaults to B<0>.

=head3 :created(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<creation> time of the path.  The C<Callable> is
passed a C<Num> value of the creation time (number of seconds since epoch)
and is expected to return a trueish value to have the path be considered
for further selection.

=head3 :degree(N)

When hypering over multiple cores, indicate the maximum number of
threads that should be used.  Defaults to whatever the system
thinks is best (which B<may> be sub-optimal).

=head3 :device-number(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<device number> of the path.  The C<Callable> is
passed the device number of the device on which the path is located and is
expected to return a trueish value to have the path be considered for further
selection.

=head3 :dir(&dir-matcher)

If specified, indicates the matcher that should be used to select
acceptable directories with the C<paths> utility.  Defaults to C<True>
indicating B<all> directories should be recursed into.  Applicable
for any situation where C<paths> is used to create the list of files
to check.

=head3 :encoding("utf8-c8")

When specified with a string, indicates the name of the encoding
to be used to produce items to check (typically by calling
C<lines> or C<slurp>).  Defaults to C<utf8-c8>, the UTF-8
encoding that is permissive of encoding issues.

=head3 :executable

Flag.  If specified, indicates only paths that are B<executable> by the current
B<user>, are (not) acceptable for further selection.

=head3 :file(&file-matcher)

If specified, indicates the matcher that should be used to select
acceptable files with the C<paths> utility.  Defaults to C<True>
indicating B<all> files should be checked.  Applicable for any
situation where C<paths> is used to create the list of files to
check.

=head3 :filesize(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<number of bytes> of the path.  The C<Callable> is
passed the number of bytes of a path and is expected to return a trueish
value to have the path be considered for further selection.

=head3 :files-from($filename)

If specified, indicates the name of the file from which a list
of files to be used as sources will be read.

=head3 :find

Flag.  If specified, maps the sources of items into items to search.

=head3 :gid(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<gid> of the path.  The C<Callable> is passed the
numeric gid of a path and is expected to return a trueish value to have the
path be considered for further selection.  See also C<owner> and C<group>
filters.

=head3 :group-executable

Flag.  If specified, indicates only paths that are B<executable> by the current
B<group>, are (not) acceptable for further selection.

=head3 :group-readable

Flag.  If specified, indicates only paths that are B<readable> by the current
B<group>, are (not) acceptable for further selection.

=head3 :group-writable

Flag.  If specified, indicates only paths that are B<writable> by the current
B<group>, are (not) acceptable for further selection.

=head3 :hard-links(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<number of hard-links> of the path.  The C<Callable>
is passed the number of hard-links of a path and is expected to return a
trueish value to have the path be considered for further selection.

=head3 :inode(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<inode> of the path.  The C<Callable> is passed the
inode of a path and is expected to return a trueish value to have the path be
considered for further selection.

=head3 :invert-match

Flag. If specified with a trueish value, will negate the return
value of the pattern if a C<Bool> was returned.  Defaults to
C<False>.

=head3 :meta-modified(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<modification> time of the path.  The C<Callable> is
passed a C<Num> value of the modification time (number of seconds since epoch)
and is expected to return a trueish value to have the path be considered
for further selection.

=head3 :mode(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<mode> of the path.  The C<Callable> is passed the
mode of a path and is expected to return a trueish value to have the path be
considered for further selection.  This is really for advanced types of tests:
it's probably easier to use any of the C<readable>, C<writeable> and
C<executable> filters.

=head3 :modified(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<modification> time of the path.  The C<Callable> is
passed a C<Num> value of the modification time (number of seconds since epoch)
and is expected to return a trueish value to have the path be considered
for further selection.

=head3 :paragraph-context

Flag. If specified with a trueish value, produce lines B<around>
the line with a pattern match until an empty line is encountered.

=head3 :passthru-context

Flag. If specified with a trueish value, produces B<all> lines.

=head3 :paths-from($filename)

If specified, indicates the name of the file from which a list
of paths to be used as the base of the production of filename
with a C<paths> search.

=head3 :paths(@paths)

If specified, indicates a list of paths that should be used
as the base of the production of filename with a C<paths>
search.  If there is no other sources specification (from
either the C<:files-from>, C<paths-from> or C<sources>) then
the current directory (aka ".") will be assumed.

If a single hyphen is specified as the path, then STDIN will be
assumed as the source.

=head3 :per-file(&producer)

If specified, indicates that searches should be done on a per-file
basis.  Defaults to doing searches on a per-line basis.

If specified with a C<True> value, indicates that the C<slurp>
method will be called on each source before being checked with
pattern.  If the source is a C<Str>, then it will be assumed to
be a path name to read from.

If specified with a C<Callable>, it indicates the code to be
executed from a given source to produce the single item to be
checked for the pattern.

=head3 :per-line(&producer)

If specified, indicates that searches should be done on a per-line
basis.

If specified with a C<True> value (which is also the default),
indicates that the C<lines> method will be called on each source
before being checked with pattern.  If the source is a C<Str>,
then it will be assumed to be a path name to read lines from.

If specified with a C<Callable>, it indicates the code to be
executed from a given source to produce the  itemi to be checked
for the pattern.

=head3 :quietly

Flag. If specified with a trueish value, will absorb any warnings
that may occur when looking for the pattern.

=head3 :readable

Flag.  If specified, indicates only paths that are B<readable> by the current
B<user>, are (not) acceptable for further selection.

=head3 :owned-by-group

Flag.  If specified, indicates only paths that are B<owned> by the B<group>
of the current user, are (not) acceptable for further selection.

=head3 :owned-by-user

Flag.  If specified, indicates only paths that are B<owned> by the current
B<user>, are (not) acceptable for further selection.

=head3 :silently("out,err")

When specified with C<True>, will absorb any output on STDOUT
and STDERR.  Optionally can only absorb STDOUT ("out"), STDERR
("err") and both STDOUT and STDERR ("out,err").

=head3 :sources(@objects)

If specified, indicates a list of objects that should be used
as a source for the production of lines.

=head3 :stats

Flag.  If specified with a trueish value, will keep stats on number
of files and number of lines seen.  And instead of just returning
the results sequence, will then return a C<List> of the result
sequence as the first argument, and a C<Map> with statistics as the
second argument.

=head3 :uid(&filter)

If specified, indicates the C<Callable> filter that should be used to select
acceptable paths by the B<uid> of the path.  The C<Callable> is passed the
numeric uid of a path and is expected to return a trueish value to have the
path be considered for further selection.  See also C<owner> and C<group>
filters.

=head3 :world-executable

Flag.  If specified, indicates only paths that are B<executable> by any user
or group, are (not) acceptable for further selection.

=head3 :world-readable

Flag.  If specified, indicates only paths that are B<readable> by any user
or group, are (not) acceptable for further selection.

=head3 :world-writeable

Flag.  If specified, indicates only paths that are B<writable> by any user
or group, are (not) acceptable for further selection.

=head3 :writable

Flag.  If specified, indicates only paths that are B<writable> by the current
B<user>, are (not) acceptable for further selection.

=head2 PATTERN RETURN VALUES

The return value of the pattern C<Callable> is interpreted in the
following ways:

=head3 True

If the C<Bool>ean True value is returned, assume the pattern is found.
Produce the line unless C<:invert-match> was specified.

=head3 False

If the C<Bool>ean Fals value is returned, assume the pattern is B<not>
found.  Do B<not> produce the line unless C<:invert-match> was specified.

=head3 Empty

Always produce the line.  Even if C<:invert-match> was specified.

=head3 any other value

Produce that value.

=head2 PHASERS

Any C<FIRST>, C<NEXT> and C<LAST> phaser that are specified in the
pattern C<Callable>, will be executed at the correct time.

=head2 MATCHING LINES vs CONTEXT LINES

The C<Pair>s that contain the search result within an object, have
an additional method mixed in: C<matched>.  This returns C<True> for
lines that matched, and C<False> for lines that have been added because
of a context specification (C<:context>, C<:before-context>, C<:after-context>
or C<paragraph-context>).

These C<Pair>s can also be recognized by their class: C<PairMatched> versus
C<PairContext>, which are also exported.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/rak .
Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
