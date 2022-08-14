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
    if %_<symbolic-link>:exists {
        $seq = $seq.map:
          (%_<symbolic-link>:delete)
            ?? -> $path { path-is-symbolic-link($path) ?? $path !! Empty }
            !! -> $path { path-is-symbolic-link($path) ?? Empty !! $path }
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
    my $debug := %n<debug> // True;
    CATCH { return $_ => .message unless $debug }

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

    # Set up any mapper
    my &mapper;
    my &next-mapper-phaser;
    my $map-all := %n<map-all>;
    if %n<mapper>:exists {
        &mapper = %n<mapper>:delete;
        if &mapper.has-loop-phasers {
            $_() with &mapper.callable_for_phaser('FIRST');
            &next-mapper-phaser = $_ with &mapper.callable_for_phaser('NEXT');
        }
    }

    # Set up result sequence
    first-phaser() if &first-phaser;
    my atomicint $nr-files;
    my $result-seq := do if &mapper {
        my $lock := Lock.new;
        $sources-seq.map: -> $source {
            ++⚛$nr-files;
            producer($source).map(&runner).iterator.push-all(
              my $buffer := IterationBuffer.new
            );

            if $map-all || $buffer.elems {
                # thread-safely run mapper and associated phasers
                $lock.protect: {
                    my \result := mapper($source, $buffer.List);
                    next-phaser()        if &next-phaser;
                    next-mapper-phaser() if &next-mapper-phaser;
                    result
                }
            }
        }
    }
    elsif &next-phaser {
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

    # Need to run all searches before returning
    if $stats || &mapper || &last-phaser {
        $result-seq.iterator.push-all(my $buffer := IterationBuffer.new);
        last-phaser() if &last-phaser;
        if &mapper && &mapper.has-loop-phasers {
            $_() with &mapper.callable_for_phaser('LAST');
        }

        $stats
          ?? ($buffer.Seq, Map.new: (:$nr-files, :$nr-lines, :$nr-matches))
          !! $buffer.Seq
    }

    # We can be lazy
    else {
        $result-seq
    }
}

# vim: expandtab shiftwidth=4
