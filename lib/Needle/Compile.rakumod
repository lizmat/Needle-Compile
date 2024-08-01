#-------------------------------------------------------------------------------# Dependencies

use v6.*;  # Until 6.e is default

use has-word:ver<0.0.4+>:auth<zef:lizmat>;      # has-word
use String::Utils:ver<0.0.24+>:auth<zef:lizmat> <
  non-word has-marks is-lowercase
>;

#-------------------------------------------------------------------------------# Helper subs

my proto sub make-method(|) {*}

# Make a method call with the given name and string argument
my multi sub make-method(
  Str:D $name,
  Str:D $needle,
        %_,
        $class = RakuAST::Call::Method
) {
    make-method
      $name,
      RakuAST::StrLiteral.new($needle),
      %(
        ignorecase => ignorecase($needle, %_),
        ignoremark => ignoremark($needle, %_)
      ),
      $class
}

# Make a method call with the given name and argument AST
my multi sub make-method(
            Str:D $name,
  RakuAST::Node:D $needle,
                  %_,
                  $class = RakuAST::Call::Method
) {
    my $args := RakuAST::ArgList.new($needle);
    if %_ {
        for <ignorecase ignoremark> {
            $args.push(RakuAST::ColonPair::True.new($_)) if %_{$_};
        }
    }

    RakuAST::Term::TopicCall.new(
      $class.new(
        name => RakuAST::Name.from-identifier($name),
        args => $args
      )
    )
}

# Return True if ignorecase should be used
my sub ignorecase(Str:D $target, %_) {
    %_<ignorecase> || (%_<smartcase> && is-lowercase($target))
}

# Return True if ignoremark should be used
my sub ignoremark(Str:D $target, %_) {
    %_<ignoremark> || (%_<smartmark> && !has-marks($target))
}

# Wrap a given AST in a block with $_ as the only positional argument
my sub wrap-in-block(RakuAST::Node:D $ast) {
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
      body      => RakuAST::Blockoid.new(
        RakuAST::StatementList.new(
          RakuAST::Statement::Expression.new(
            expression => $ast
          )
        )
      )
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
# Handling of entries.  A single "handle" sub uses multi dispatch to handle
# all possible specifications, often dispatching to other candidates, and
# often recursively, to finally return an AST that can be called with the
# haystack as the parameter.

my proto sub handle(|) {*}

# Initial distribution
my multi sub handle(@_, %_) {
    my $type :=  @_.?type // "auto";
    my $ast := handle $type, @_.head, %_;

    # All but the first element
    for @_.skip {
        $ast := RakuAST::ApplyInfix.new(
          left  => $ast,
          infix => RakuAST::Infix.new("||"),
          right => handle($type, $_, %_)
        );
    }

    $ast
}
my multi sub handle(Pair:D $_, %_) {
    handle .key, .value, %_
}
my multi sub handle(Str:D $_, %nameds) {
    if .?type -> $type {
        handle($type, $_, %nameds);
    }
    else {
        handle("auto", $_, %nameds);
    }
}

# The "auto" distributors
my multi sub handle("auto", Str:D $_, %_) {
    if .starts-with('§') {
        handle "words", .substr(1), %_
    }
    elsif .starts-with('*') {
        handle "code", .substr(1), %{}
    }
    elsif .starts-with('{') && .ends-with('}') {
        handle "code", .substr(1, *-1), %_
    }
    elsif .starts-with('/') && .ends-with('/') {
        handle "code", .substr(1, *-1), %_
    }
    elsif .starts-with('^') {
        if .ends-with('$') {
            handle "equal", .substr(1, *-1), %_
        }
        else {
            handle "starts-with", .substr(1), %_
        }
    }
    elsif .ends-with('$') {
        handle "ends-with", .chop, %_
    }
    else {
        handle "contains", $_, %_
    }
}

# Handlers that build custom ASTs
my multi sub handle("code", Str:D $spec, %_) {
    $spec.AST
}
my multi sub handle("equal", Str:D $spec, %_) {
    RakuAST::ApplyInfix.new(
      left  => RakuAST::StrLiteral.new($spec),
      infix => RakuAST::Infix.new("eq"),
      right => RakuAST::Var::Lexical.new("\$_")
    )
}
my multi sub handle("regex", Str:D $spec is copy, %_) {
    if non-word($spec) {
        my str $i = ignorecase($spec, %_) ?? ' :i' !! '';
        my str $m = ignoremark($spec, %_) ?? ' :m' !! '';
        my $ast := "/$i$m $spec /".AST.statements.head.expression;
        make-method("contains", $ast, %())
    }
    else {
        handle("contains", $spec, %_)
    }
}

# Handlers that do a method call on the topic
my multi sub handle("contains", Str:D $spec, %_) {
    make-method "contains", $spec, %_
}
my multi sub handle("ends-with", Str:D $spec, %_) {
    make-method "ends-with", $spec, %_
}
my multi sub handle("starts-with", Str:D $spec, %_) {
    make-method "starts-with", $spec, %_
}
my multi sub handle("words", Str:D $spec, %_) {
    RakuAST::Call::Name.new(
      name => RakuAST::Name.from-identifier("has-word"),
      args => RakuAST::ArgList.new(
        RakuAST::Var::Lexical.new("\$_"),
        RakuAST::StrLiteral.new($spec),
      )
    )
}

# Handlers that modify other handlers
my multi sub handle("not", Any:D $spec, %_) {
    prefix-not handle $spec, %_
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

my sub compile-needle(*@spec, *%_) is export {
    my @nodes = @spec.map: { handle $_, %_ }

    if @nodes == 1 {
#say @nodes.head;
        wrap-in-block(@nodes.head).EVAL
    }
    else {
        NYI "multiple needles"
    }
}

my $needle := compile-needle "§foo", :smartcase;
say $needle("foo");
say $needle("bar foob");

# vim: expandtab shiftwidth=4
