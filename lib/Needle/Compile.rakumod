#-------------------------------------------------------------------------------# Dependencies

use v6.*;  # Until 6.e is default

use has-word:ver<0.0.6+>:auth<zef:lizmat>;      # has-word all-words
use String::Utils:ver<0.0.25+>:auth<zef:lizmat> <
  has-marks is-lowercase is-whitespace non-word nomark
>;

#-------------------------------------------------------------------------------
# Type mixin related

my constant @ok-types = <
  and auto code contains ends-with equal file json-path not regex
  split starts-with url words
>;
my constant %ok-types = @ok-types.map: * => True;

my role Type {
    has $.type;

    method TWEAK() is hidden-from-backtrace {
        fail qq:to/ERROR/ unless %ok-types{$!type};
Type must be one of:
  @ok-types.join("\n  ")
not: '$!type'
ERROR
    }

    method ACCEPTS($_)   { %ok-types{.Str} // False }
    method Str (Type:D:) { self ~ "" }
    method raku(Type:D:) { callsame() ~ " but Type('$!type')" }
}
my constant StrType = Str but Type;

#-------------------------------------------------------------------------------
# JSON::Path support

my $json-path;

# Wrapper for JSON::Path object
my class JP {
    has $.jp;
    has $.pattern;

    my $cache := Map.new;
    method new($pattern) {
        $cache{$pattern} // do {
            CATCH {
                if X::AdHoc.ACCEPTS($_) {
                    my $message := .payload;
                    if $message.starts-with('JSON path parse error') {
                        my $pos := $message.words.tail.Int;
                        fail qq:to/ERROR/.chomp;
$message:
{$pattern.substr(0,$pos)}«$pattern.substr($pos,1)»$pattern.substr($pos + 1)
{" " x $pos}⏏
ERROR
                    }
                }
                fail .Str;
            }
            my $jp := $json-path.new($pattern);
            my $JP := self.bless(:$jp, :$pattern);

            # update cache in a threadsafe manner
            $cache := Map.new: $cache, Pair.new: $pattern, $JP;
            $JP
        }
    }

    method !late-stringification() {
        fail qq:!c:to/ERROR/.chomp;
Must do something with the JP object *inside* the pattern, such as:

'{ jp("$.pattern").Slip }'

to avoid late stringification of the JP object.
ERROR
    }

    method value()  { $!jp.value($*_) }
    method values() { $!jp.values($*_) }
    method paths()  { $!jp.paths($*_) }
    method paths-and-values() { $!jp.paths-and-values($*_) }

    method Seq()  { $!jp.values($*_)      }
    method Bool() { $!jp.values($*_).Bool }
    method list() { $!jp.values($*_).List }
    method List() { $!jp.values($*_).List }
    method Slip() { $!jp.values($*_).Slip }
    method gist() {
        $*_
          ?? $!jp.values($*_).gist
          !! self!late-stringification
    }
    method Str()  {
        $*_
          ?? $!jp.values($*_).Str
          !! self!late-stringification
    }

    method words()  { $!jp.values($*_).Str.words.Slip }
    method head(|c) { $!jp.values($*_).head(|c).Slip  }
    method tail(|c) { $!jp.values($*_).tail(|c).Slip  }
    method skip(|c) { $!jp.values($*_).skip(|c).Slip  }
}

# Allow postcircumfixes on jp($path)
my multi sub postcircumfix:<[ ]>(JP:D $self) {
    $self.values
}
my multi sub postcircumfix:<[ ]>(JP:D $self, Whatever) {
    $self.values
}
my multi sub postcircumfix:<[ ]>(JP:D $self, Int:D $pos) {
    $self.values[$pos].Slip
}
my multi sub postcircumfix:<[ ]>(JP:D $self, @pos) {
    $self.values[@pos].Slip
}
my multi sub postcircumfix:<[ ]>(JP:D $self, &pos) {
    $self.values[&pos].Slip
}
my multi sub postcircumfix:<[ ]>(Str:D $string, \pos) {
    $string.words[pos].Slip
}

# Allow for slip jp($path)
my multi sub slip(JP:D $self) {
    $self.values.Slip
}

# Magic self-installing JSON::Path support
my $lock := Lock.new;
my &jp = my sub jp-stub(str $pattern) {
    $lock.protect: {  # threadsafe loading of module
        if $json-path<> =:= Any {
            CATCH { fail "JSON::Path not installed" }
            $json-path := 'use JSON::Path:ver<1.7>; JSON::Path'.EVAL;
        }
    }

    # unstub ourselves, and call the original pattern on the unstubbed version
    (&jp = anon sub jp(str $pattern) { JP.new($pattern) })($pattern)
}

#-------------------------------------------------------------------------------
# Generic helper subs

# Very basic URL fetcher
my sub GET(Str:D $url) {
    (run 'curl', '-L', '-k', '-s', '-f', $url, :out).out.slurp || Nil
}

# Return True if ignorecase should be used
my sub ignorecase(Str:D $target, %_) {
    %_<ignorecase> || (%_<smartcase> && is-lowercase($target))
}

# Return True if ignoremark should be used
my sub ignoremark(Str:D $target, %_) {
    %_<ignoremark> || (%_<smartmark> && !has-marks($target))
}

#-------------------------------------------------------------------------------
# Helper subs that create ASTs

my proto sub make-method(|) {*}

# Make a method call with the given name and string argument
my multi sub make-method(
  Str:D $name,
  Str:D $needle,
        %_
) {
    make-method
      $name,
      RakuAST::StrLiteral.new($needle),
      %(
        ignorecase => ignorecase($needle, %_),
        ignoremark => ignoremark($needle, %_),
        (:matches if %_<matches>),
        (:global  if %_<globals>)
      )
}

# Make a method call with the given name and argument AST
my multi sub make-method(
            Str:D  $name,
  RakuAST::Node:D  $needle,
                   %_,
) {
    my $args := RakuAST::ArgList.new($needle);

    for <ignorecase ignoremark global> {
        $args.push(RakuAST::ColonPair::True.new($_)) if %_{$_};
    }

    my $ast := RakuAST::Term::TopicCall.new(
      RakuAST::Call::Method.new(
        name => RakuAST::Name.from-identifier($name),
        args => $args
      )
    );

    %_<matches> ?? with-matches($ast, $needle) !! $ast
}

# Basically do needle && value for matches only semantics
my sub with-matches(RakuAST::Node:D $left, RakuAST::Node:D $matches) {
    RakuAST::ApplyInfix.new(
      left  => $left,
      infix => RakuAST::Infix.new('&&'),
      right => RakuAST::ApplyPostfix.new(
        operand => RakuAST::Type::Simple.new(
          RakuAST::Name.from-identifier("Slip")
        ),
        postfix => RakuAST::Call::Method.new(
          name => RakuAST::Name.from-identifier("new"),
          args => RakuAST::ArgList.new($matches)
        )
      )
    )
}

# Use dispatch to handle different types of AST
my proto sub wrap-in-block(|) {*}

# Wrap the statement list in a compunit into a block, and wrap that
# in a new statement list in the compunit
my multi sub wrap-in-block(RakuAST::CompUnit:D $ast) {

    my $statement-list := $ast.statement-list;
    $ast.replace-statement-list(
      RakuAST::StatementList.new(
        RakuAST::Statement::Expression.new(
#          expression => RakuAST::Block.new(
#            :required-topic,
          expression => RakuAST::PointyBlock.new(
            signature => RakuAST::Signature.new(
              parameters => (
                RakuAST::Parameter.new(
                  target => RakuAST::ParameterTarget::Var.new(
                    name => "\$_"
                  )
                ),
              )
            ),
            body      => RakuAST::Blockoid.new($statement-list)
          )
        )
      )
    );
    $ast
}

# Wrap a given AST in a block with $_ as the only positional argument
my multi sub wrap-in-block(RakuAST::Node:D $ast is copy) {

    # Make sure we have a statement list
    $ast = RakuAST::StatementList.new(
      RakuAST::Statement::Expression.new(
        expression => $ast
      )
    ) unless $ast ~~ RakuAST::StatementList;

    # Make sure we have a lexically visible $/ to stop it potentially
    # being accessed from multiple threads simultaneously
    $ast.unshift-statement(
      RakuAST::Statement::Expression.new(
        expression => RakuAST::VarDeclaration::Simple.new(
          sigil       => '$',
          desigilname => RakuAST::Name.from-identifier('/')
        )
      )
    );

#    RakuAST::Block.new(
#      :required-topic,
    RakuAST::PointyBlock.new(
      signature => RakuAST::Signature.new(
        parameters => (
          RakuAST::Parameter.new(
            target => RakuAST::ParameterTarget::Var.new(
              name => "\$_"
            )
          ),
        )
      ),
      body      => RakuAST::Blockoid.new($ast)
    )
}

# Prefix a given AST with a negation
my sub prefix-not(RakuAST::Node:D $ast) {
    RakuAST::ApplyPrefix.new(
      prefix  => RakuAST::Prefix.new("not"),
      operand => $ast
    )
}

#-------------------------------------------------------------------------------
# Convert a given string to a type / value pair

my proto sub implicit2explicit(|) {*}

# Already explicit
my multi sub implicit2explicit(Pair:D $_) {
    %ok-types{.key}
      ?? $_
      !! fail "Don't know how to handler '$_.key()'"
}

# Mixed in type, take it out
my multi sub implicit2explicit(StrType:D $_) {
    .type => "" ~ $_
}

# Non-mixed in type, look what makes sense
my multi sub implicit2explicit(Str:D $_) {
    if .starts-with('!') {
        "not" => implicit2explicit(.substr(1))
    }
    elsif .starts-with('&') {
        "and" => implicit2explicit(.substr(1))
    }
    elsif .starts-with('§') {
        "words" => .substr(1)
    }
    elsif .starts-with('*') {
        .chars > 1
          ?? .substr-eq('.', 1)
            ?? :code(.substr(1))
            !! :code('$_ ' ~ .substr(1))
          !! :contains($_)
    }
    elsif .starts-with('{') && .ends-with('}') {
        "code" => .substr(1, *-1)
    }
    elsif .starts-with('/') && .ends-with('/') {
        .chars > 2
          ?? :regex(.substr(1, *-1))
          !! :contains($_)
    }
    elsif .starts-with('^') {
        if .ends-with('$') {
            "equal" => .substr(1, *-1)
        }
        else {
            "starts-with" => .substr(1)
        }
    }
    elsif .ends-with('$') {
        "ends-with" => .chop
    }
    elsif .starts-with('file:') {
        "file" => .substr(5)
    }
    elsif .starts-with('jp:') {
        "json-path" => .substr(3)
    }
    elsif .starts-with('s:') {
        "split" => .substr(2)
    }
    elsif .starts-with('url:') {
        "url" => .substr(4)
    }
    else {
        "contains" => $_
    }
}

#-------------------------------------------------------------------------------
# Handling of entries.  A single "handle" sub uses multi dispatch to handle
# all possible specifications, often dispatching to other candidates, and
# often recursively, to finally return an AST that can be called with the
# haystack as the parameter.

my proto sub handle(|) {*}

# Initial distribution
my multi sub handle(@raw, %_, :$type = "auto") {

    my @targets;
    my str @regexes;

    sub collect-any-regexes() {
        @targets.push(Pair.new('regex', @regexes.splice.join('|')))
          if @regexes;
    }

    if $type eq 'auto' {
        for @raw {
            my $target := $_ ~~ Pair ?? $_ !! implicit2explicit($_);

            # A(nother) regex
            if $target.key eq 'regex' {
                @regexes.push($target.value);
            }

            # Something else, combine any regexes first
            else {
                collect-any-regexes;
                @targets.push: $target;
            }
        }

        collect-any-regexes;
    }
    else {
        @targets = @raw.map: { $_ ~~ Pair ?? $_ !! Pair.new($type, $_) }
    }

    my $ast = handle @targets.head, %_;

    # All but the first element
    for @targets.skip {
        my $right := handle $_, %_;

        $ast = RakuAST::ApplyInfix.new(
          left  => $ast,
          infix => RakuAST::Infix.new(
            ($right.?type // "") eq 'and' ?? "&&" !! "||"
          ),
          right => $right,
        );
    }

    $ast
}

my multi sub handle(Pair:D $_, %_) {
    my $target := .value<>;
    $target ~~ List
      ?? handle $target, :type(.key), %_
      !! handle .key, .value, %_
}

my multi sub handle(StrType:D $_, %_) {
    handle .type, .Str, %_
}

my multi sub handle(Str:D $_, %nameds) {
    if .?type -> $type {
        handle $type, .Str, %nameds
    }
    else {
        handle "auto", $_, %nameds
    }
}

my multi sub handle("auto", Pair:D $_, %_) {
    handle $_, %_
}

my multi sub handle("auto", Str:D $_, %_) {
    handle implicit2explicit($_), %_
}

#-------------------------------------------------------------------------------
# Handlers that build custom ASTs

my multi sub handle("code", Str:D $spec is copy, %_) {

    if %_<repo> -> *@repos {
        $spec = @repos.map({ "use lib '$_';\n" }).join ~ $spec;
    }

    if %_<module> -> *@modules {
        $spec = @modules.map({ "use $_;\n" }).join ~ $spec;
    }
    my $ast := $spec.AST(:compunit);

    # Prefix: my $*_ := $_
    $ast.statement-list.unshift-statement(
      RakuAST::Statement::Expression.new(
        expression => RakuAST::VarDeclaration::Simple.new(
          sigil       => '$',
          twigil      => '*',
          desigilname => RakuAST::Name.from-identifier('_'),
          initializer => RakuAST::Initializer::Bind.new(
            RakuAST::Var::Lexical.new('$_')
          )
        )
      )
    );

    $ast
}

my multi sub handle("json-path", Str:D $spec, %_) {
    RakuAST::StatementList.new(
      # my $*_ := $_;
      RakuAST::Statement::Expression.new(
        expression => RakuAST::VarDeclaration::Simple.new(
          sigil       => "\$",
          twigil      => "*",
          desigilname => RakuAST::Name.from-identifier("_"),
          initializer => RakuAST::Initializer::Bind.new(
            RakuAST::Var::Lexical.new("\$_")
          )
        )
      ),
      RakuAST::Statement::Expression.new(
        # jp($spec).Slip
        expression => RakuAST::ApplyPostfix.new(
          operand => RakuAST::Call::Name.new(
            name => RakuAST::Name.from-identifier("jp"),
            args => RakuAST::ArgList.new(
              RakuAST::StrLiteral.new($spec)
            )
          ),
          postfix => RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier("Slip")
          )
        )
      )
    )
}

my multi sub handle("equal", Str:D $spec, %_) {
    my $left  = RakuAST::Var::Lexical.new('$_');
    my $right = $spec;

    if ignoremark($right, %_) {
        $left  = RakuAST::Call::Name.new(
          name => RakuAST::Name.from-identifier("nomark"),
          args => RakuAST::ArgList.new($left)
        );
        $right = nomark($right);
    }

    if ignorecase($right, %_) {
        $left  = RakuAST::Term::TopicCall.new(
          RakuAST::Call::Method.new(
            name => RakuAST::Name.from-identifier("fc")
          )
        );
        $right = $right.fc;
    }

    $right = RakuAST::StrLiteral.new($right);
    my $ast := RakuAST::ApplyInfix.new(
      left  => $left,
      infix => RakuAST::Infix.new("eq"),
      right => $right
    );

    %_<matches> ?? with-matches($ast, $right) !! $ast
}

my multi sub handle("file", Str:D $spec, %_) {

    # helper sub for getting pattern(s) from file
    sub read-patterns($io) {
        my @lines is List = $io.lines.map: {
             $_ unless is-whitespace($_) || .starts-with('#')
        }
        warn "No patterns found in '$spec'" unless @lines;

        @lines
    }

    if $spec eq '-' {
        handle read-patterns($*IN), %_
    }
    else {
        (my $io := $spec.IO).e && $io.r
          ?? handle read-patterns($io), %_
          !! fail "Could not read patterns from '$spec'"
    }
}

my multi sub handle("regex", Str:D $spec is copy, %_) {
    $spec .= trim;
    my $matches := %_<matches>;

    if $matches || non-word($spec) {
        my str $i = ignorecase($spec, %_) ?? ' :i' !! '';
        my str $m = ignoremark($spec, %_) ?? ' :m' !! '';
        my $ast   = "/$i$m $spec /".AST.statements.head.expression;

        if $matches {

            # effectively: .match($spec, :g) ?? $/.map({.Str}).Slip !! False
            RakuAST::Ternary.new(
              condition => make-method("match", $ast, %(:global)),
              then      => RakuAST::ApplyPostfix.new(
                operand => RakuAST::ApplyPostfix.new(
                  operand => RakuAST::Var::Lexical.new("\$/"),
                  postfix => RakuAST::Call::Method.new(
                    name => RakuAST::Name.from-identifier("map"),
                    args => RakuAST::ArgList.new(wrap-in-block(
                      RakuAST::Term::TopicCall.new(
                        RakuAST::Call::Method.new(
                          name => RakuAST::Name.from-identifier("Str")
                        )
                      )
                     ))
                  )
                ),
                postfix => RakuAST::Call::Method.new(
                  name => RakuAST::Name.from-identifier("Slip")
                )
              ),
              else      => RakuAST::Term::Name.new(
                RakuAST::Name.from-identifier("False")
              )
            )
        }
        else {
            make-method("contains", $ast, %())
        }
    }
    else {
        handle("contains", $spec, %_)
    }
}

my multi sub handle("words", Str:D $spec, %_) {
    fail("Cannot use word semantics on '$spec'") if non-word($spec);

    my $args := RakuAST::ArgList.new(
      RakuAST::Var::Lexical.new('$_'),
      RakuAST::StrLiteral.new($spec)
    );
    for <ignorecase ignoremark> {
        $args.push(RakuAST::ColonPair::True.new($_)) if %_{$_};
    }

    %_<matches>
      ?? RakuAST::ApplyInfix.new(
           left  => RakuAST::Call::Name.new(
             name => RakuAST::Name.from-identifier("all-words"),
             args => $args
           ),
           infix => RakuAST::Infix.new("||"),
           right => RakuAST::Term::Name.new(
             RakuAST::Name.from-identifier("False")
           )
         )
      !! RakuAST::Call::Name.new(
           name => RakuAST::Name.from-identifier("has-word"),
           args => $args
         )
}

#-------------------------------------------------------------------------------
# Handlers that do a method call on the topic

my multi sub handle("contains", Str:D $spec, %_) {
    %_<matches>
      ?? handle "regex", "'$spec'", %_
      !! make-method "contains", $spec, %_
}
my multi sub handle("ends-with", Str:D $spec, %_) {
    %_<matches>
      ?? handle "regex", "'$spec'\$", %_
      !! make-method "ends-with", $spec, %_
}
my multi sub handle("starts-with", Str:D $spec, %_) {
    %_<matches>
      ?? handle "regex", "^'$spec'", %_
      !! make-method "starts-with", $spec, %_
}

#-------------------------------------------------------------------------------
# Handlers that modify other handlers

my multi sub handle("and", Any:D $spec, %_) {
    handle($spec, %_) but Type<and>;
}

my multi sub handle("not", Any:D $spec, %_) {
    my $ast := handle $spec, %_;
    if $ast ~~ RakuAST::CompUnit {
        my $last := $ast.statement-list.statements.tail;
        $last.set-expression(prefix-not $last.expression);
        $ast
    }
    else {
        prefix-not $ast
    }
}

my multi sub handle("split", Str:D $spec, %_) {
    handle $spec.words, %_
}

my multi sub handle("url", Str:D $spec, %nameds) {
    my $url := $spec.contains(/^ \w+ '://' /)
      ?? $spec
      !! "https://$spec";
    if GET($url) -> $patterns {
        handle $patterns.lines, %nameds
    }
    else {
        fail "Could not fetch patterns from '$spec'";
    }
}

# Huh?
my multi sub handle(Any:D $spec, %_) {
    fail "Don't know how to handle '$spec.raku()'";
}
my multi sub handle(Str:D $type, Str:D $spec, %_) {
    fail "Don't know how to handle '$type' for '$spec'";
}
my multi sub handle(Str:D $type, Any:D $spec, %_) {
    fail "Don't know how to handle '$type' for '$spec.raku()'";
}

#-------------------------------------------------------------------------------
# The frontend

my proto sub compile-needle(|) {
    CATCH { return .Failure }
    {*}
}

my multi sub compile-needle(*%_) {
    if %_ {
        if %_ == 1 {
            wrap-in-block(handle %_.head, %_).EVAL
        }
        else {
            fail "Can only specify one pair as a named argument";
        }
    }
    else {
        fail "Must specify at least one needle";
    }
}

my multi sub compile-needle(Positional:D $spec is raw, *%_) {
#say handle $spec, %_;
    wrap-in-block(handle $spec, %_).EVAL
}

my multi sub compile-needle($spec, *%_) {
#say wrap-in-block(handle $spec, %_);
    wrap-in-block(handle $spec, %_).EVAL
}

my multi sub compile-needle(*@spec, *%_) {
#say handle @spec, %_;
    wrap-in-block(handle @spec, %_).EVAL
}

#-------------------------------------------------------------------------------
# Exporting logic

my sub EXPORT(*@names) {
    my %export;
    %export<&compile-needle> := &compile-needle;

    my @huh;
    for @names {
        unless $_ eq 'compile-needle' {
            $_ eq 'implicit2explicit'
              ?? (%export<&implicit2explicit> := &implicit2explicit)
              !! $_ eq 'Type'
                ?? (%export<Type> := Type)
                !! $_ eq 'StrType'
                  ?? (%export<StrType> := StrType)
                  !! @huh.push($_);
        }
    }

    @huh
      ?? die "Don't know how to export: @huh.join(", ")"
      !! %export.Map
}

# vim: expandtab shiftwidth=4
