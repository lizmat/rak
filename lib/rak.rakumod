# The modules that we need here, with their full identities
use Git::Files:ver<0.0.6>:auth<zef:lizmat>;      # git-files
use hyperize:ver<0.0.2>:auth<zef:lizmat>;        # hyperize raceize
use paths:ver<10.0.9>:auth<zef:lizmat> 'paths';  # paths
use path-utils:ver<0.0.18>:auth<zef:lizmat>;     # path-*
use Trap:ver<0.0.1>:auth<zef:lizmat>;            # Trap

# code to convert a path into an object that can do .lines and .slurp
my &ioify = *.IO;

# The classes for matching and not-matching items (that have been added
# because of some context argument having been specified).
my class PairContext is Pair is export {
    method matched(--> False) { }
    method Str(--> Str:D) { self.key ~ ':' ~ self.value }
}
my class PairMatched is PairContext is export {
    method matched(--> True) { }
}

# Create an eager slip for a given Seq
my sub eagerSlip($seq) {
    $seq.iterator.push-all(my $buffer := IterationBuffer.new);
    $buffer.Slip
}

# Message for humans on STDERR
my sub warn-if-human-on-stdin(--> Nil) {
    note "Reading from STDIN, please enter source and ^D when done:"
      if $*IN.t;
}

# Return a Seq with ~ paths substituted for actual home directory paths
my sub paths-from-file($from) {
    my $home := $*HOME.absolute ~ '/';
    warn-if-human-on-stdin if $from eq '-';
    ($from eq '-'
      ?? $*IN.lines
      !! ioify($from.subst(/^ '~' '/'? /, $home)).lines
    ).map: *.subst(/^ '~' '/'? /, $home)
}

# Return a Map with named arguments for "paths"
my sub paths-arguments(%_) {
    my $dir  := %_<dir>:delete;
    my $file := %_<file>:delete;
    my $follow-symlinks := (%_<recurse-symlinked-dir>:delete) // False;
    my $recurse         := (%_<recurse-unmatched-dir>:delete) // False;
    my $readable-files  := (%_<is-readable>:delete)           // True;
    Map.new: (:$dir, :$file, :$recurse, :$follow-symlinks, :$readable-files);
}

# Obtain paths for given revision control system and specs
my sub uvc-paths($uvc, *@specs) {
    $uvc<> =:= True || $uvc eq 'git'
      ?? git-files @specs
      !! die "Don't know how to select files for '$uvc'";
}

my @temp-files;
END .unlink for @temp-files;

# Check if argument looks like a URL, and if so, fetch it
my sub fetch-if-url(Str:D $target) {
    if $target.contains(/^ \w+ '://' /) {
        my $proc := run 'curl', $target, :out, :err;
        if $proc.out.slurp(:close) -> $contents {
            my $io := $*TMPDIR.add('rak-' ~ $*PID ~ '-' ~ time);
            $io.spurt($contents);
            @temp-files.push: $io;
            $proc.err.slurp(:close);
            # Hide an IO object with the URL hidden in it inside
            # the absolute path of the object, so that all file
            # attribute tests, that require a string, will just
            # work without blowing up because they can't coerce
            # an IO::Path to a native string
            role HideIO { has IO::Path:D $.IO is required }
            $io.absolute but HideIO($io but $target)
        }
        else {
            $proc.err.slurp(:close);
            Empty
        }
    }
}

# Convert a given seq producing paths to a seq producing files
my sub paths-to-files($iterable, $degree, %_) {
    if %_<under-version-control>:delete -> $uvc {
        uvc-paths($uvc, $iterable)
    }
    else {
        my %paths-arguments := paths-arguments(%_);
        $iterable.&hyperize(1, $degree).map: {
            path-exists($_)
              ?? path-is-regular-file($_)
                ?? $_
                !! paths($_, |%paths-arguments).Slip
              !! fetch-if-url($_)
        }
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
    if %_<is-empty>:exists {
        $seq = $seq.map:
          (%_<is-empty>:delete)
            ?? -> $path { path-is-empty($path) ?? $path !! Empty }
            !! -> $path { path-is-empty($path) ?? Empty !! $path }
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

    if %_<is-owned-by-user>:exists {
        $seq = $seq.map:
          (%_<is-owned-by-user>:delete)
            ?? -> $path { path-is-owned-by-user($path) ?? $path !! Empty }
            !! -> $path { path-is-owned-by-user($path) ?? Empty !! $path }
    }
    if %_<is-owned-by-group>:exists {
        $seq = $seq.map:
          (%_<is-owned-by-group>:delete)
            ?? -> $path { path-is-owned-by-group($path) ?? $path !! Empty }
            !! -> $path { path-is-owned-by-group($path) ?? Empty !! $path }
    }

    if %_<is-writable>:exists {
        $seq = $seq.map:
          (%_<is-writable>:delete)
            ?? -> $path { path-is-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-writable($path) ?? Empty !! $path }
    }
    if %_<is-executable>:exists {
        $seq = $seq.map:
          (%_<is-executable>:delete)
            ?? -> $path { path-is-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-executable($path) ?? Empty !! $path }
    }

    if %_<has-setuid>:exists {
        $seq = $seq.map:
          (%_<has-setuid>:delete)
            ?? -> $path { path-has-setuid($path) ?? $path !! Empty }
            !! -> $path { path-has-setuid($path) ?? Empty !! $path }
    }
    if %_<has-setgid>:exists {
        $seq = $seq.map:
          (%_<has-setgid>:delete)
            ?? -> $path { path-has-setgid($path) ?? $path !! Empty }
            !! -> $path { path-has-setgid($path) ?? Empty !! $path }
    }
    if %_<is-sticky>:exists {
        $seq = $seq.map:
          (%_<is-sticky>:delete)
            ?? -> $path { path-is-sticky($path) ?? $path !! Empty }
            !! -> $path { path-is-sticky($path) ?? Empty !! $path }
    }

    if %_<is-owner-readable>:exists {
        $seq = $seq.map:
          (%_<is-owner-readable>:delete)
            ?? -> $path { path-is-owner-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-owner-readable($path) ?? Empty !! $path }
    }
    if %_<is-owner-writable>:exists {
        $seq = $seq.map:
          (%_<is-owner-writable>:delete)
            ?? -> $path { path-is-owner-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-owner-writable($path) ?? Empty !! $path }
    }
    if %_<is-owner-executable>:exists {
        $seq = $seq.map:
          (%_<is-owner-executable>:delete)
            ?? -> $path { path-is-owner-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-owner-executable($path) ?? Empty !! $path }
    }

    if %_<is-group-readable>:exists {
        $seq = $seq.map:
          (%_<is-group-readable>:delete)
            ?? -> $path { path-is-group-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-readable($path) ?? Empty !! $path }
    }
    if %_<is-group-writable>:exists {
        $seq = $seq.map:
          (%_<is-group-writable>:delete)
            ?? -> $path { path-is-group-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-writable($path) ?? Empty !! $path }
    }
    if %_<is-group-executable>:exists {
        $seq = $seq.map:
          (%_<is-group-executable>:delete)
            ?? -> $path { path-is-group-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-group-executable($path) ?? Empty !! $path }
    }

    if %_<is-symbolic-link>:exists {
        $seq = $seq.map:
          (%_<is-symbolic-link>:delete)
            ?? -> $path { path-is-symbolic-link($path) ?? $path !! Empty }
            !! -> $path { path-is-symbolic-link($path) ?? Empty !! $path }
    }

    if %_<is-world-readable>:exists {
        $seq = $seq.map:
          (%_<is-world-readable>:delete)
            ?? -> $path { path-is-world-readable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-readable($path) ?? Empty !! $path }
    }
    if %_<is-world-writable>:exists {
        $seq = $seq.map:
          (%_<is-world-writable>:delete)
            ?? -> $path { path-is-world-writable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-writable($path) ?? Empty !! $path }
    }
    if %_<is-world-executable>:exists {
        $seq = $seq.map:
          (%_<is-world-executable>:delete)
            ?? -> $path { path-is-world-executable($path) ?? $path !! Empty }
            !! -> $path { path-is-world-executable($path) ?? Empty !! $path }
    }

    if %_<accept>:delete -> &code {
        $seq = $seq.map: -> $path { code(ioify $path) ?? $path !! Empty }
    }

    if %_<deny>:delete -> &code {
        $seq = $seq.map: -> $path { code(ioify $path) ?? Empty !! $path }
    }

    if %_<exec>:delete -> $command {
        $seq = $seq.map: -> $path {
            run($command.subst('$_', $path, :g)) ?? $path !! Empty
        }
    }
    if %_<shell>:delete -> $command {
        $seq = $seq.map: -> $path {
            shell($command.subst('$_', $path, :g)) ?? $path !! Empty
        }
    }

    if %_<is-text>:exists {
        $seq = $seq.map:
          (%_<is-text>:delete)
            ?? -> $path { path-is-text($path) ?? $path !! Empty }
            !! -> $path { path-is-text($path) ?? Empty !! $path }
    }

    if %_<is-moarvm>:exists {
        $seq = $seq.map:
          (%_<is-moarvm>:delete)
            ?? -> $path { path-is-moarvm($path) ?? $path !! Empty }
            !! -> $path { path-is-moarvm($path) ?? Empty !! $path }
    }

    if %_<is-pdf>:exists {
        $seq = $seq.map:
          (%_<is-pdf>:delete)
            ?? -> $path { path-is-pdf($path) ?? $path !! Empty }
            !! -> $path { path-is-pdf($path) ?? Empty !! $path }
    }

    $seq.map: &ioify
}

# Return a matcher Callable for a given pattern.
my sub make-matcher(&pattern, %_) {
    my &matcher := %_<invert-match>:delete
      ?? -> $haystack {
             my $result := pattern($haystack);
             $result =:= True
               ?? False
               !! not-acceptable($result)
                 ?? True
                 !! $result
         }
      !! &pattern;

    my $silently := (%_<silently>:delete)<>;
    if %_<quietly>:delete {
        # the existence of a CONTROL block appears to disallow use of ternaries
        # 2022.07
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
                CONTROL { .resume if CX::Warn.ACCEPTS($_) }
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

# Not matching
my sub not-acceptable($result is copy) {
    $result := $result<>;
    $result =:= False || $result =:= Empty || $result =:= Nil
}

# Return a runner Callable for passthru
my sub make-passthru-runner(&matcher, $item-number) {
    $item-number
      ?? -> $item {
             my $result := matcher($item.value);
             not-acceptable($result)
               ?? $item
               !! PairMatched.new:
                     $item.key,
                     $result =:= True ?? $item.value !! $result
         }
      !! -> $item {
             my $result := matcher($item);
             $result =:= True || not-acceptable($result)
               ?? $item
               !! $result
         }
}

# Return a runner Callable for passthru context
my sub make-passthru-context-runner(&matcher, $item-number) {
    my $after;
    my @before;
    $item-number
      ?? -> $item {
             my $value  := $item.value;
             my $result := matcher($value);
             if not-acceptable($result) {  # no match
                 if $after {
                     $item
                 }
                 else {
                     @before.push($item);
                     Empty
                 }
             }
             else {  # match or something else was produced from match
                 $after = True;
                 @before.push(
                   PairMatched.new:
                     $item.key,
                     $result =:= True ?? $value !! $result
                 ).splice.Slip
             }
         }
      !! -> $item {
             my $result := matcher($item);
             if not-acceptable($result) {  # no match
                 if $after {
                     $item
                 }
                 else {
                     @before.push($item);
                     Empty
                 }
             }
             else {  # match or something else was produced from match
                 $after = True;
                 @before.push(
                   $result =:= True ?? $item !! $result
                 ).splice.Slip
             }
         }
}

# Return a runner Callable for paragraph context around items
my multi sub make-paragraph-context-runner(
  &matcher, $item-number, int $max-matches
) {
    my int $matches-seen;
    my $after;
    my @before;
    $item-number
      ?? -> $item {
             my $value := $item.value;
             if $matches-seen == $max-matches {  # enough matches seen
                 $after
                   ?? $value
                     ?? $item
                     !! (last)
                   !! (last)
             }
             else {  # must still try to match
                 my $result := matcher($value);
                 if not-acceptable($result) {  # no match
                     if $after {
                         if $value {
                             $item
                         }
                         else {
                             $after = False;
                             Empty
                         }
                     }
                     else {
                         $value
                           ?? @before.push($item)
                           !! @before.splice;
                         Empty
                     }
                 }
                 else {  # match or something else was produced from match
                     ++$matches-seen;
                     $after = True;
                     @before.push(
                       PairMatched.new:
                         $item.key,
                         $result =:= True ?? $value !! $result
                     ).splice.Slip
                 }
             }
         }
      # no item numbers needed
      !! -> $item {
             if $matches-seen == $max-matches {  # enough matches seen
                 $after
                   ?? $item
                     ?? $item
                     !! (last)
                   !! (last)
             }
             else {  # must still try to match
                 my $result := matcher($item);
                 if not-acceptable($result) {  # no match
                     if $after {
                         if $item {
                             $item
                         }
                         else {
                             $after = False;
                             Empty
                         }
                     }
                     else {
                         $item
                           ?? @before.push($item)
                           !! @before.splice;
                         Empty
                     }
                 }
                 else {  # match or something else was produced from match
                     ++$matches-seen;
                     $after = True;
                     @before.push(
                       $result =:= True ?? $item !! $result
                     ).splice.Slip
                 }
             }
         }
}
my multi sub make-paragraph-context-runner(&matcher, $item-number) {
    my $after;
    my @before;
    $item-number
      ?? -> $item {
             my $value  := $item.value;
             my $result := matcher($value);
             if not-acceptable($result) {  # no match
                 if $after {
                     if $value {
                         $item
                     }
                     else {
                         $after = False;
                         Empty
                     }
                 }
                 else {
                     $value
                       ?? @before.push($item)
                       !! @before.splice;
                     Empty
                 }
             }
             else {  # match or something else was produced from match
                 $after = True;
                 @before.push(
                   PairMatched.new:
                     $item.key,
                     $result =:= True ?? $value !! $result
                 ).splice.Slip
             }
         }
      # no item numbers needed
      !! -> $item {
             my $result := matcher($item);
             if not-acceptable($result) {  # no match
                 if $after {
                     if $item {
                         $item
                     }
                     else {
                         $after = False;
                         Empty
                     }
                 }
                 else {
                     $item
                       ?? @before.push($item)
                       !! @before.splice;
                     Empty
                 }
             }
             else {  # match or something else was produced from match
                 $after = True;
                 @before.push(
                   $result =:= True ?? $item !! $result
                 ).splice.Slip
             }
         }
}

# Return a runner Callable for numeric context around items
my multi sub make-numeric-context-runner(
  &matcher, $item-number, $before, $after, int $max-matches
) {
    my int $matches-seen;
    if $before {
        my $todo;
        my @before;
        $item-number
          ?? -> $item {
                 if $matches-seen == $max-matches {  # seen enough matches
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         last
                     }
                 }
                 else {
                     my $value  := $item.value;
                     my $result := matcher($value);
                     if not-acceptable($result) {  # no match
                         if $todo {
                             --$todo; $item
                         }
                         else {
                             @before.shift if @before.elems == $before;
                             @before.push: $item;
                             Empty
                         }
                     }

                     else {  # match or something was produced from match
                         ++$matches-seen;
                         $todo = $after;
                         @before.push(
                           PairMatched.new:
                             $item.key,
                             $result =:= True ?? $value !! $result
                         ).splice.Slip
                     }
                 }
             }
          # no item numbers needed
          !! -> $item {
                 if $matches-seen == $max-matches {  # seen enough matches
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         last
                     }
                 }
                 else {
                     my $result := matcher($item);
                     if not-acceptable($result) {  # no match
                         if $todo {
                             --$todo; $item
                         }
                         else {
                             @before.shift if @before.elems == $before;
                             @before.push: $item;
                             Empty
                         }
                     }

                     else {  # match or something was produced from match
                         ++$matches-seen;
                         $todo = $after;
                         @before.push(
                           $result =:= True ?? $item !! $result
                         ).splice.Slip
                     }
                 }
             }
    }
    else {
        my $todo;
        $item-number
          ?? -> $item {
                 if $matches-seen == $max-matches {  # seen enough matches
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         last
                     }
                 }
                 else {
                     my $value  := $item.value;
                     my $result := matcher($value);
                     if not-acceptable($result) {  # no match
                         if $todo {
                             --$todo; $item
                         }
                         else {
                             Empty
                         }
                     }
                     else {  # match or something was produced from match
                         ++$matches-seen;
                         $todo = $after;
                         PairMatched.new:
                           $item.key,
                           $result =:= True ?? $value !! $result
                     }
                 }
             }
          # no item numbers needed
          !! -> $item {
                 if $matches-seen == $max-matches {  # seen enough matches
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         last
                     }
                 }
                 else {
                     my $result := matcher($item);
                     if not-acceptable($result) {  # no match
                         if $todo {
                             --$todo; $item
                         }
                         else {
                             Empty
                         }
                     }
                     else {  # match or something was produced from match
                         ++$matches-seen;
                         $todo = $after;
                         $result =:= True ?? $item !! $result
                     }
                 }
             }
    }
}
my multi sub make-numeric-context-runner(
  &matcher, $item-number, $before, $after
) {
    if $before {
        my $todo;
        my @before;

        $item-number
          ?? -> $item {
                 my $value  := $item.value;
                 my $result := matcher($value);
                 if not-acceptable($result) {  # no match
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         @before.shift if @before.elems == $before;
                         @before.push: $item;
                         Empty
                     }
                 }
                 else {  # match or something was produced from match
                     $todo = $after;
                     @before.push(
                       PairMatched.new:
                         $item.key,
                         $result =:= True ?? $value !! $result
                     ).splice.Slip
                 }
             }
          # no item numbers needed
          !! -> $item {
                 my $result := matcher($item);
                 if not-acceptable($result) {  # no match
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         @before.shift if @before.elems == $before;
                         @before.push: $item;
                         Empty
                     }
                 }
                 else {  # match or something was produced from match
                     $todo = $after;
                     @before.push(
                       $result =:= True ?? $item !! $result
                     ).splice.Slip
                 }
             }
    }
    else {
        my $todo;
        $item-number
          ?? -> $item {
                 my $value  := $item.value;
                 my $result := matcher($value);
                 if not-acceptable($result) {  # no match
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         Empty
                     }
                 }
                 else {  # match or something was produced from match
                     $todo = $after;
                     PairMatched.new:
                       $item.key,
                       $result =:= True ?? $value !! $result
                 }
             }
          # no item numbers needed
          !! -> $item {
                 my $result := matcher($item);
                 if not-acceptable($result) {  # no match
                     if $todo {
                         --$todo; $item
                     }
                     else {
                         Empty
                     }
                 }
                 else {  # match or something was produced from match
                     $todo = $after;
                     $result =:= True ?? $item !! $result
                 }
             }
    }
}

# Base case of a runner from a matcher without any context
my multi sub make-runner(&matcher, $item-number, int $max-matches) {
    my int $matches-seen;
    $item-number
      ?? -> $item {
             last if $matches-seen == $max-matches;

             my $value  := $item.value;
             my $result := matcher($value);
             if not-acceptable($result) {
                 Empty
             }
             else {
                 ++$matches-seen;
                 PairMatched.new:
                   $item.key,
                   $result =:= True ?? $value !! $result
             }
         }
      # no item numbers needed
      !! -> $item {
             last if $matches-seen == $max-matches;

             my $result := matcher($item);
             if not-acceptable($result) {
                 Empty
             }
             else {
                 ++$matches-seen;
                 $result =:= True ?? $item !! $result
             }
         }
}
my multi sub make-runner(&matcher, $item-number) {
    $item-number
      ?? -> $item {
             my $value  := $item.value;
             my $result := matcher($value);
             not-acceptable($result)
               ?? Empty
               !! PairMatched.new:
                    $item.key,
                    $result =:= True ?? $value !! $result
         }
      # no item numbers needed
      !! -> $item {
             my $result := matcher($item);
             not-acceptable($result)
               ?? Empty
               !! $result =:= True ?? $item !! $result
         }
}

# Stub the Rak class here
our class Rak { ... }

proto sub rak(|) is export {*}
multi sub rak(&pattern, *%n) {
    rak &pattern, %n
}
multi sub rak(&pattern, %n) {
    # any execution error will be caught and become a return state
    my $CATCH := !(%n<dont-catch>:delete);
    CATCH {
        $CATCH
          ?? (return Rak.new: exception => $_)
          !! .rethrow;
    }

    # Determine how we make IO::Path-like objects
    &ioify = $_ with %n<ioify>:delete;

    # Some settings we always need
    my $batch     := %n<batch>:delete;
    my $degree    := %n<degree>:delete;
    my $enc       := %n<encoding>:delete // 'utf8-c8';
    my $eagerSlip := True;

    my sub get-sources-seq() {
        my $seq := do if %n<files-from>:delete -> $files-from {
            paths-from-file($files-from).map: {
                path-exists($_) ?? $_ !! fetch-if-url($_)
            }
        }
        elsif %n<paths-from>:delete -> $paths-from {
            paths-to-files(paths-from-file($paths-from), $degree, %n)
        }
        elsif %n<paths>:delete -> $paths {
            my $home := $*HOME.absolute ~ '/';
            paths-to-files(
              $paths.map(*.subst(/^ '~' '/'? /, $home)),
              $degree,
              %n
            ).&hyperize($batch, $degree)
        }
        elsif %n<under-version-control>:delete -> $uvc {
            uvc-paths($uvc)
        }
        elsif !($*IN.t) {
            $eagerSlip := False;
            return $*IN
        }
        else {
            paths(".", |paths-arguments(%n)).&hyperize($batch, $degree)
        }

        # Step 2. filtering on properties
        make-property-filter($seq, %n);
    }

    # Step 1: sources sequence
    my $sources-seq = %n<sources>:delete // get-sources-seq;

    # sort sources if we want them sorted
    if %n<sort-sources>:delete -> $sort {
        $sources-seq = Bool.ACCEPTS($sort)
          ?? $sources-seq.sort(*.fc)
          !! $sources-seq.sort($sort)
    }

    # Some flags that we need
    my $eager := %n<eager>:delete;
    my $sources-only;
    my $sources-without-only;
    my $unique;
    my $sort;
    my $frequencies;
    my $classify;
    my $categorize;
    my $item-number;
    my $max-matches-per-source;

    if %n<sources-only>:delete {
        $sources-only := True;
        $item-number  := False;
        $max-matches-per-source := 1;
    }
    elsif %n<sources-without-only>:delete {
        $sources-without-only := $sources-only := True;
        $item-number  := False;
        $max-matches-per-source := 1;
    }
    else {
        $max-matches-per-source := %n<max-matches-per-source>:delete;
        if %n<unique>:delete {
            $unique      := $eager := True;
            $item-number := False;

            $sort := %n<sort>:delete;
        }
        elsif %n<frequencies>:delete {
            $frequencies := $eager := True;
            $item-number := False;
        }
        elsif %n<classify>:delete -> &classifier {
            $classify    := &classifier;
            $eager       := True;
            $item-number := False;
        }
        elsif %n<categorize>:delete -> &categorizer {
            $categorize  := &categorizer;
            $eager       := True;
            $item-number := False;
        }
        elsif %n<produce-one>:exists {
            $item-number := False;
        }
        else {
            $item-number := !(%n<omit-item-number>:delete);
        }
    }

    # Step 3: producer Callable
    my &producer := do if (%n<produce-one>:delete) -> $produce-one {
          # no item numbers produced ever
          -> $source {
              (my $producer := $produce-one($source)) =:= Nil
                ?? ()
                !! ($producer,)
          }
    }
    elsif (%n<produce-many>:delete)<> -> $produce-many {
        $item-number
          ?? -> $source {
                 my int $line-number;
                 $produce-many($source).map: {
                     PairContext.new: ++$line-number, $_
                 }
             }
          # no item numbers produced
          !! -> $source { $produce-many($source) }
    }
    elsif %n<find>:delete {
        $eagerSlip := False;
        my $seq := $sources-seq<>;
        $sources-seq = ("<find>",);
        my int $line-number;
        $item-number
          ?? -> $ { $seq.map: { PairContext.new: ++$line-number, $_ } }
          !! -> $ { $seq }
    }
    else {
        my $chomp := !(%n<with-line-endings>:delete);
        -> $source {
            # source exists and is readable
            my $is-IO := IO::Path.ACCEPTS($source);
            if ($is-IO && $source.r) || !$is-IO {
                my $seq := $source.lines(:$chomp, :$enc);

                # Hyperize files of more than 2 MB
                $seq := $seq.hyper(:batch(4096))
                  if $is-IO && $source.s > 2097152;

                my int $line-number;
                $item-number
                  ?? $seq.map: { PairContext.new: ++$line-number, $_ }
                  !! $seq
            }
        }
    }

    # Step 4: matching logic
    # The matcher Callable should take a haystack as the argument, and
    # call the pattern with that.  And optionally do some massaging to make
    # sure we get the right thing.  But in all other aspects, the matcher
    # has the same API as the pattern.
    my &matcher = &pattern =:= &defined
      ?? &defined
      !! make-matcher(
           Regex.ACCEPTS(&pattern) ?? *.contains(&pattern) !! &pattern,
           %n
         );

    # Want to have pair of old/new
    if %n<old-new>:delete {
        my &old-matcher = &matcher;
        &matcher = -> $old {
            my $new := old-matcher($old);
            unless Bool.ACCEPTS($new) || $new =:= Empty || $new =:= Nil {
                Pair.new($old, $new) unless $new eqv $old;
            }
        }
    }

    # Stats keeping stuff: these lexical variables will be directly accessible
    # through the Rak object that is returned.  This is ok to do, since each
    # call to the "rak" subroutine will result in a unique Rak object, so
    # there's no danger of these lexicals seeping into the wrong Rak object
    my $stats;
    my $stats-only;
    my atomicint $nr-sources;
    my atomicint $nr-items;
    my atomicint $nr-matches;
    my atomicint $nr-passthrus;
    my atomicint $nr-changes;

    # Progress monitoring class, to be passed on when :progress is specified
    my $progress := %n<progress>:delete;
    my $cancellation;
    class Progress {
        method nr-sources()   { ⚛$nr-sources   }
        method nr-items()     { ⚛$nr-items     }
        method nr-matches()   { ⚛$nr-matches   }
        method nr-passthrus() { ⚛$nr-passthrus }
        method nr-changes()   { ⚛$nr-changes   }
    }

    # The result class returned by the rak call
    class Rak {
        has $.result    is built(:bind) = Empty;  # search result
        has $.completed is built(:bind) = False;  # True if done already
        has $.exception is built(:bind) = Nil;    # What was thrown

        # Final stats access
        method stats() {
            $stats || $stats-only
              ?? Map.new((
                  :$nr-changes, :$nr-items, :$nr-matches,
                  :$nr-passthrus, :$nr-sources
                 ))
              !! BEGIN Map.new
        }

        # Final progress access
        method nr-sources()   { ⚛$nr-sources   }
        method nr-items()     { ⚛$nr-items     }
        method nr-matches()   { ⚛$nr-matches   }
        method nr-passthrus() { ⚛$nr-passthrus }
        method nr-changes()   { ⚛$nr-changes   }

        method stop-progress() {
            if $cancellation {
                $cancellation.cancel;
                $progress();  # indicate we're done to the progress logic
            }
        }
    }

    # Only interested in counts, so update counters and remove result
    if $stats-only := %n<stats-only>:delete {
        my &old-matcher = &matcher;
        &matcher = -> $_ {
            ++⚛$nr-items;
            my $result := old-matcher($_);
            if $result =:= Empty {
                ++$nr-passthrus;
            }
            elsif Bool.ACCEPTS($result) {
                ++⚛$nr-matches if $result;
            }
            else {
                ++⚛$nr-matches;
                ++⚛$nr-changes unless $result eqv $_;
            }
            Empty
        }
    }

    # Add any stats keeping if necessary
    elsif ($stats := %n<stats>:delete) || $progress {
        my &old-matcher = &matcher;
        &matcher = -> $_ {
            ++⚛$nr-items;
            my $result := old-matcher($_);
            if $result =:= Empty {
                ++$nr-passthrus;
            }
            elsif Bool.ACCEPTS($result) {
                ++⚛$nr-matches if $result;
            }
            else {
                ++⚛$nr-matches;
                ++⚛$nr-changes unless $result eqv $_;
            }
            $result
        }
    }

    # Step 5: contextualizing logic
    # The runner Callable should take a PairContext object as the argument,
    # and call the matcher with that.  If the result is True, then it should
    # produce that line as a PairMatched object with the original value, and
    # any other items as as PairContext objects.  If the result is False, it
    # should produce Empty.  In any other case, it should produce a
    # PairMatched object with the original key, and the value returned by
    # the matcher as its value.  To make sure each source gets its own
    # closure clone, the runner is actually a Callable returning the actual
    # runner code Callable.
    my &runner := do if $stats-only {
        $eager := True;
        # simplest runner for just counting
        -> { make-runner &matcher, $item-number }
    }

    # special passthru contexts
    elsif %n<passthru>:delete {
        -> { make-passthru-runner &matcher, $item-number }
    }
    elsif %n<passthru-context>:delete {
        -> { make-passthru-context-runner &matcher, $item-number }
    }

    # limit on number of matches
    elsif $max-matches-per-source -> int $max {
        if %n<context>:delete -> $context {
            -> { make-numeric-context-runner &matcher,
                   $item-number, $context, $context, $max }
        }
        elsif %n<before-context>:delete -> $before {
            my $after := %n<after-context>:delete;
            -> { make-numeric-context-runner &matcher,
                   $item-number, $before, $after, $max }
        }
        elsif %n<after-context>:delete -> $after {
            -> { make-numeric-context-runner &matcher,
                   $item-number, Any, $after, $max }
        }
        elsif %n<paragraph-context>:delete {
            -> { make-paragraph-context-runner &matcher,
                   $item-number, $max }
        }
        else {
            -> { make-runner &matcher, $item-number, $max }
        }
    }
    # no limit on number of matches
    elsif %n<context>:delete -> $context {
        -> { make-numeric-context-runner &matcher,
               $item-number, $context, $context }
    }
    elsif %n<before-context>:delete -> $before {
        my $after := %n<after-context>:delete;
        -> { make-numeric-context-runner &matcher,
               $item-number, $before, $after }
    }
    elsif %n<after-context>:delete -> $after {
        -> { make-numeric-context-runner &matcher,
               $item-number, Any, $after }
    }
    elsif %n<paragraph-context>:delete {
        -> { make-paragraph-context-runner &matcher, $item-number }
    }
    else {
        -> { make-runner &matcher, $item-number }
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

    # Set up any mapper if not just counting
    my &mapper;
    my $map-all;
    my &next-mapper-phaser;
    my &last-mapper-phaser;
    if !$stats-only && (%n<mapper>:exists) {
        $map-all := %n<map-all>:delete;
        &mapper   = %n<mapper>:delete;
        if &mapper.has-loop-phasers {
            $_() with &mapper.callable_for_phaser('FIRST');
            &next-mapper-phaser = $_ with &mapper.callable_for_phaser('NEXT');
            &last-mapper-phaser = $_ with &mapper.callable_for_phaser('LAST');
        }
    }

    # Set up result sequence
    first-phaser() if &first-phaser;

    # A mapper was specified
    my $result-seq := do if &mapper {
        my $lock := Lock.new;
        $sources-seq.map: $sources-without-only
          ?? -> $*SOURCE {
                 ++⚛$nr-sources;
                 if producer($*SOURCE).map(runner).iterator.pull-one
                   =:= IterationEnd {
                     # thread-safely run mapper and associated phasers
                     $lock.protect: {
                         my \result := mapper($*SOURCE);
                         next-phaser()        if &next-phaser;
                         next-mapper-phaser() if &next-mapper-phaser;
                         result
                     }
                 }
             }
          !! $sources-only
            ?? -> $*SOURCE {
                   ++⚛$nr-sources;
                   unless producer($*SOURCE).map(runner).iterator.pull-one
                     =:= IterationEnd {
                       # thread-safely run mapper and associated phasers
                       $lock.protect: {
                           my \result := mapper($*SOURCE);
                           next-phaser()        if &next-phaser;
                           next-mapper-phaser() if &next-mapper-phaser;
                           result
                       }
                   }
               }
            !! -> $*SOURCE {
                   ++⚛$nr-sources;
                   producer($*SOURCE).map(runner).iterator.push-all(
                     my $buffer := IterationBuffer.new
                   );

                   if $map-all || $buffer.elems {
                       # thread-safely run mapper and associated phasers
                       $lock.protect: {
                           my \result := mapper($*SOURCE, $buffer.List);
                           next-phaser()        if &next-phaser;
                           next-mapper-phaser() if &next-mapper-phaser;
                           result
                       }
                   }
               }
    }

    # Only want sources
    elsif $sources-only {
        my $lock := Lock.new if &next-phaser;
        $sources-seq.map: -> $*SOURCE {
            ++⚛$nr-sources;
            my \result := producer($*SOURCE).map(runner).iterator.pull-one;
            $lock.protect(&next-phaser) if $lock;
            if $sources-without-only {
                $*SOURCE if result =:= IterationEnd
            }
            else {
                $*SOURCE unless result =:= IterationEnd
            }
        }
    }

    # The matcher has a NEXT phaser
    elsif &next-phaser {
        my $lock := Lock.new;
        $sources-seq.map: -> $*SOURCE {
            ++⚛$nr-sources;
            my \result :=
              Pair.new: $*SOURCE, eagerSlip producer($*SOURCE).map: runner;
            $lock.protect: &next-phaser;
            result
        }
    }

    # Want each file to eager Slip its items
    elsif $eagerSlip {
        $sources-seq.map: -> $*SOURCE {
            ++⚛$nr-sources;
            Pair.new: $*SOURCE, eagerSlip producer($*SOURCE).map: runner
        }
    }

    # Each file (probably only one) will run over items lazily
    else {
        $sources-seq.map: -> $*SOURCE {
            ++⚛$nr-sources;
            Pair.new: $*SOURCE, producer($*SOURCE).map: runner
        }
    }

    # Set up any progress reporting and associated cancellation
    $cancellation := $*SCHEDULER.cue(-> { $progress(Progress) }, :every(.2))
      if $progress;

    # If we're not only counting
    unless $stats-only {
        my $lock := Lock.new;  # all of these need race protection

        # Only want unique matches
        if $unique {
            my %seen;
            $result-seq := $result-seq.map: {
                my $outer := Pair.ACCEPTS($_) ?? .value !! $_;
                if Iterable.ACCEPTS($outer) {
                    $outer.map({
                        my $inner := Pair.ACCEPTS($_) ?? .value !! $_;
                        $inner
                          unless $lock.protect: -> { %seen{$inner.WHICH}++ }
                    }).Slip
                }
                else {
                    $outer
                      unless $lock.protect: -> { %seen{$outer.WHICH}++ }
                }
            }
            if $sort {
                $result-seq := Bool.ACCEPTS($sort)
                  ?? $result-seq.sort(*.fc)
                  !! $result-seq.sort($sort)
            }
        }

        # Want classification
        elsif $classify -> &classifier {
            my %classified{Any};

            my sub store(\key, $value) {
                $lock.protect: {
                    (%classified{key} //
                      (%classified{key} := IterationBuffer.new)
                    ).push: $value;
                }
            }

            for $result-seq {
                my $outer := Pair.ACCEPTS($_) ?? .value !! $_;
                if Iterable.ACCEPTS($outer) {
                    for $outer {
                        my $value := Pair.ACCEPTS($_) ?? .value !! $_;
                        store classifier($value), $value;
                    }
                }
                else {
                    store classifier($outer), $outer;
                    my $key := classifier($outer);
                    $lock.protect: {
                        (%classified{$key} // (%classified{$key} := []))
                          .push: $outer;
                    }
                }
            }
            $result-seq := %classified.sort(-*.value.elems).map: {
                Pair.new: .key, .value.List
            }
        }

        # Want categorization
        elsif $categorize -> &categorizer {
            my %categorized{Any};

            my sub store(\keys, $value) {
                $lock.protect: {
                    for keys -> $key {
                        (%categorized{$key} //
                          (%categorized{$key} := IterationBuffer.new)
                        ).push: $value;
                    }
                }
            }

            for $result-seq {
                my $outer := Pair.ACCEPTS($_) ?? .value !! $_;
                if Iterable.ACCEPTS($outer) {
                    for $outer {
                        my $value := Pair.ACCEPTS($_) ?? .value !! $_;
                        store categorizer($value), $value;
                    }
                }
                else {
                    store categorizer($outer), $outer;
                }
            }
            $result-seq := %categorized.sort(-*.value.elems).map: {
                Pair.new: .key, .value.List
            }
        }
    }

    # Need to run all searches before returning
    my %args;
    if $eager
      || $stats    # XXX this should really be lazy
      || &last-mapper-phaser
      || &last-phaser {
        my $buffer := IterationBuffer.new;

        # Convert to frequency map if so requested
        if $frequencies {
            my %bh is Bag = $result-seq.map: *.value.Slip;
            %bh.sort({
                $^b.value cmp $^a.value || $^a.key cmp $^b.key
            }).iterator.push-all: $buffer;
        }

        # Normal collection
        else {
            $result-seq.iterator.push-all: $buffer;
        }

        # Run the phasers if any
        last-phaser()        if &last-phaser;
        last-mapper-phaser() if &last-mapper-phaser;

        $stats-only
          ?? Rak.new(:completed)
          !! Rak.new(:completed, :result($buffer.List))
    }

    # We can be lazy
    else {
        Rak.new: result => $result-seq<>
    }
}

# vim: expandtab shiftwidth=4
