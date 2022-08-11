# The modules that we need here, with their full identities
use has-word:ver<0.0.3>:auth<zef:lizmat>;
use hyperize:ver<0.0.2>:auth<zef:lizmat>;
use paths:ver<10.0.7>:auth<zef:lizmat>;
use Trap:ver<0.0.1>:auth<zef:lizmat>;

# Pre-process literal strings looking like a regex
my sub regexify($pattern, %_) {
    my $i := %_<ignorecase>:delete ?? ':i' !! '';
    my $m := %_<ignoremark>:delete ?? ':m' !! '';
    "/$i$m $pattern.substr(1)".EVAL
}

# Return prelude from --repository and --module parameters
my sub prelude(%_) {
    my $prelude = "";
    if %_<repository>:delete -> \libs {
        $prelude = libs.map({"use lib '$_'; "}).join;
    }
    if %_<module>:delete -> \modules {
        $prelude ~= modules.map({"use $_; "}).join;
    }
    $prelude
}

# Pre-process non literal string needles, return Callable if possible
my sub codify(Str() $pattern, %_?) {

    # Handle smartcase
    %_<ignorecase> = !$pattern.contains(/ <:upper> /)
      if (%_<ignorecase>:!exists) && (%_<smartcase>:delete);

    $pattern.starts-with('/') && $pattern.ends-with('/')
      ?? regexify($pattern, %_)
      !! $pattern.starts-with('{') && $pattern.ends-with('}')
        ?? (prelude(%_) ~ 'my $ := -> $_ ' ~ $pattern).EVAL
        !! $pattern.starts-with('*.')
          ?? (prelude(%_) ~ 'my $ := ' ~ $pattern).EVAL
          !! $pattern
}

# Return Callable for a pattern that is not supposed to be code
my sub needleify($pattern, $highlightable, %_) {
    my $i := %_<ignorecase>:delete;
    my $m := %_<ignoremark>:delete;
    my $type := %_<type>:delete || 'contains';

    if $type eq 'words' {
        $highlightable() if $highlightable;
        $i
          ?? $m
            ?? *.&has-word($pattern, :i, :m)
            !! *.&has-word($pattern, :i)
          !! $m
            ?? *.&has-word($pattern, :m)
            !! *.&has-word($pattern)
    }
    elsif $type eq 'contains' | 'starts-with' | 'ends-with' {
        $highlightable() if $highlightable;
        $i
          ?? $m
            ?? *."$type"($pattern, :i, :m)
            !! *."$type"($pattern, :i)
          !! $m
            ?? *."$type"($pattern, :m)
            !! *."$type"($pattern)
    }
    else {
        die "Don't know how to handle type: $type";
    }
}

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
    my $dir  := (%_<dir>:delete)  // True;
    my $file := (%_<file>:delete) // True;
    Map.new: (:$dir, :$file)
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

# Return a Callable for matching an entry
my sub make-matcher(&needle, %_) {
    my &matcher := %_<invert-match>:delete
      ?? -> $haystack {
             my $result := needle($haystack);
             Bool.ACCEPTS($result)
               ?? $result
                 ?? Empty
                 !! $haystack
               !! $result =:= Empty
                 ?? $haystack
                 !! $result
         }
      !! -> $haystack {
             my $result := needle($haystack);
             Bool.ACCEPTS($result)
               ?? $result
                 ?? $haystack
                 !! Empty
               !! $result =:= Empty
                 ?? $haystack
                 !! $result
         }

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
my sub make-paragraph-context-runner(&matcher) {
    my $after;
    my @before;
    -> $haystack {
        my $result := matcher($haystack);
        if $result {
            $after = True;
            @before.push($result).splice.Slip
        }
        elsif $after {
            if $haystack {
                $haystack
            }
            else {
                $after = False;
                Empty
            }
        }
        elsif $haystack {
            @before.push: $haystack;
            Empty
        }
        else {
            @before.splice;
            Empty
        }
    }
}

# Return a runner Callable for numeric context around lines
my sub make-numeric-context-runner(&matcher, $before, $after) {
    if $before {
        my $line-number = 0;
        my $todo;
        my @before;
        -> $haystack {
            ++$line-number;
            my $result := matcher($haystack);
            if $result {
                $todo = $after;
                $line-number = $line-number - @before.elems - 1;
                @before.push($result).splice.map({
                    Pair.new: ++$line-number, $_
                }).Slip
            }
            elsif $todo {
                --$todo;
                Pair.new: $line-number, $haystack
            }
            else {
                @before.shift if @before.elems == $before;
                @before.push: $haystack;
                Empty
            }
        }
    }
    else {
        my $line-number = 0;
        my $todo;
        -> $haystack {
            ++$line-number;
            my $result := matcher($haystack);
            if $result {
                $todo = $after;
                Pair.new: $line-number, $result
            }
            elsif $todo {
                --$todo;
                Pair.new: $line-number, $haystack
            }
            else {
                Empty
            }
        }
    }
}

# Base case of a runner from a matcher
sub make-runner(&matcher) {
    my $line-number = 0;
    -> $haystack {
        ++$line-number;
        (my $result := matcher($haystack))
          ?? Pair.new($line-number, $result)
          !! Empty
    }
}

proto sub rak(|) is export {*}
multi sub rak(&needle, *%n) {
    rak &needle, %n
}
multi sub rak(&needle, %n) {
    CATCH { return $_ => .message }

    my $batch  := %n<batch>:delete;
    my $degree := %n<degree>:delete;
    my $enc    := %n<encoding>:delete // 'utf8-c8';

    my $sources-seq := do if %n<files-from>:delete -> $files-from {
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
    elsif %n<sources>:delete -> @sources {
        @sources
    }
    else {
        paths ".", |paths-arguments(%n)
    }

    my &first-phaser;
    my &next-phaser;
    my &last-phaser;
    if &needle.has-loop-phasers {
        &first-phaser = &needle.callable_for_phaser('FIRST');
        &next-phaser  = &needle.callable_for_phaser('NEXT');
        &last-phaser  = &needle.callable_for_phaser('LAST');
    }

    my &producer := do if (%n<per-file>:delete)<> -> $per-file {
        $per-file =:= True
          ?? -> $source {
                 CATCH { return Empty }
                 Str.ACCEPTS($source)
                   ?? $source.IO.slurp(:$enc)
                   !! $source.slurp(:$enc)
             }
          !! $per-file
    }
    elsif (%n<per-line>:delete)<> -> $per-line {
        $per-line =:= True
          ?? -> $source {
                 CATCH { return Empty }
                 Str.ACCEPTS($source)
                   ?? $source.IO.lines(:$enc)
                   !! $source.lines(:$enc)
             }
          !! $per-line
    }
    else {
        -> $source {
            CATCH { return Empty }
            Str.ACCEPTS($source)
              ?? $source.IO.lines(:$enc)
              !! $source.lines(:$enc)
        }
    }

    my &matcher = make-matcher(&needle, %n);
    my &runner := do if %n<paragraph-context>:delete {
        make-paragraph-context-runner(&matcher)
    }
    elsif %n<context>:delete -> $context {
        make-numeric-context-runner(&matcher, $context, $context)
    }
    elsif %n<before-context>:delete -> $before {
        make-numeric-context-runner(&matcher, $before, %n<after-context>:delete)
    }
    elsif %n<after-context>:delete -> $after {
        make-numeric-context-runner(&matcher, Any, $after)
    }
    else {
        make-runner(&matcher)
    }

    first-phaser() if &first-phaser;
    my $result-seq := do if &next-phaser {
        my $lock := Lock.new;
        $sources-seq.map: -> $source {
            my \result :=
              Pair.new: $source, (producer($source).map: &runner).Slip;
            $lock.protect: &next-phaser;
            result
        }
    }
    else {
        $sources-seq.map: -> $source {
            Pair.new: $source, (producer($source).map: &runner).Slip
        }
    }


    if &last-phaser {
        my @result = $result-seq;
        last-phaser();
        @result
    }
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

The C<rak> subroutine basically goes through 4 steps to produce a
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

=head3 2. Produce items to search in

The second step is to create the logic for creating items to
search in from the objects in step 1.  If search is to be done
per object, then C<.slurp> is called on the object.  Otherwise
C<.lines> is called on the object.  Unless one provides their
own logic for producing items to search in.

Related named arguments are (in alphabetical order):

=item :encoding - encoding to be used when creating items
=item :per-file - logic to create one item per object
=item :per-line - logic to create one item per line in the object

The result of this step, is a (potentially lazy and hyperable)
sequence of objects.

=head3 3. Create logic for matching

Take the logic of the pattern C<Callable>, and create a C<Callable> to
do the actual matching with the items produced in step 2.

Related named arguments are (in alphabetical order):

=item :invert-match - invert the logic of matching
=item :quietly - absorb any warnings produced by the matcher
=item :silently - absorb any output done by the matcher

=head3 4. Create logic for contextualizing

Take the logic of the C<Callable> of step 3 and create a C<Callable>
that will produce the items found and their possible context.  If
no specific context setting is found, then it will just use the
C<Callable> of step 3.

Related named arguments are (in alphabetical order):

=item :after-context - number of lines to show after a match
=item :before-context - number of lines to show before a match
=item :context - number of lines to show around a match
=item :paragraph-context - lines around match until empty line

=head3 5. Run the sequence(s)

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

The C<rak> subroutine takes a C<Callable> pattern as the only positional
argument and quite a number of named arguments.  Or it takes a C<Callable>
as the first positional argument for the pattern, and a hash with named
arguments as the second positional argument.  In the latter case, the
hash will have the arguments removed that the C<rak> subroutine needed
for its configuration and execution.

It returns either a C<Pair> (with an C<Exception> as key, and the
exception message as the value), or a C<Seq> or C<HyperSeq> that
contains the source object as key (by default a C<IO::Path> object
of the file in which the pattern was found), and a C<Slip> of
key / value pairs, in which the key is the line-number where the
pattern was found, and the value is the product of the search
(which, by default, is the line in which the pattern was found).

The following named arguments can be specified (in alphabetical
order):

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

=head3 :context(N)

Indicate the number of lines that should also be returned around
a line with a pattern match.  Defaults to B<0>.

=head3 :degree(N)

When hypering over multiple cores, indicate the maximum number of
threads that should be used.  Defaults to whatever the system
thinks is best (which B<may> be sub-optimal).

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

=head3 :file(&file-matcher)

If specified, indicates the matcher that should be used to select
acceptable files with the C<paths> utility.  Defaults to C<True>
indicating B<all> files should be checked.  Applicable for any
situation where C<paths> is used to create the list of files to
check.

=head3 :files-from($filename)

If specified, indicates the name of the file from which a list
of files to be used as sources will be read.

=head3 :invert-match

Flag. If specified with a trueish value, will negate the return
value of the pattern if a C<Bool> was returned.  Defaults to
C<False>.

=head3 :paragraph-context

Flag. If specified with a trueish value, produce lines B<around>
the line with a pattern match until an empty line is encountered.

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

=head3 :silently("out,err")

When specified with C<True>, will absorb any output on STDOUT
and STDERR.  Optionally can only absorb STDOUT ("out"), STDERR
("err") and both STDOUT and STDERR ("out,err").

=head3 :sources(@objects)

If specified, indicates a list of objects that should be used
as a source for the production of lines.

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
