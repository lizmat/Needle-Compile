[![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions) [![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions) [![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions)

NAME
====

Needle::Compile - compile a search needle specification

SYNOPSIS
========

```raku
use Needle::Compile;

my &basic = compile-needle("bar");
say basic("foo bar baz");             # True
say basic("Huey, Dewey, and Louie");  # False

my &capitals-ok = compile-needle("bar", :ignorecase);
say capitals-ok("foo bar baz");             # True
say capitals-ok("FOO BAR BAZ");             # True
say capitals-ok("Huey, Dewey, and Louie");  # False
```

DESCRIPTION
===========

Needle::Compile exports a single subroutine "compile-needle" that takes a number of arguments that specify a search query needle, and returns a `Callable` that can be called with a given haystack to see if there is a match.

It can as such be used as the argument to the `rak` subroutine provided by the [`rak`](https://raku.land/zef:lizmat/rak) distribution.

SEARCH QUERY SPECIFICATION
==========================

A query can consist of multiple needles of different types. A type of needle can be specified in 3 ways:

### implicitely

```raku
# accept haystack if "bar" as word is found
my &needle = compile-needle("§bar");
```

By using textual markers at the start and end of the given string needle (see: type is "auto").

### explicitely

```raku
# accept haystack if "bar" as word is found
my &needle = compile-needle("words" => "bar");
```

By specifying a needle as a `Pair`, with the key being a string describing the type.

### mixed in

```raku
my role Type { has $.type }

# accept haystack if "bar" as word is found
my &needle = compile-needle("bar" but Type("words"));
```

If the needle specified supports a `.type` method, then that method will be called to determine the type.

Modifiers
---------

Many types of matches support `ignorecase` and `ignoremark` semantics. These can be specified explicitely (with the `:ignorecase` and `:ignoremark` named arguments), or implicitely with the `:smartcase` and `:smartmark` named arguments.

### ignorecase

```raku
# accept haystack if "bar" is found, regardless of case
my &needle = compile-needle("bar", :ignorecase);
```

Allow characters to match even if they are of mixed case.

### smartcase

```raku
# accept haystack if "bar" is found, regardless of case
my &anycase = compile-needle("bar", :smartcase);

# accept haystack if "Bar" is found
my &exactcase = compile-needle("Bar", :smartcase);
```

If the needle is a string and does **not** contain any uppercase characters, then `ignorecase` semantics will be assumed.

### ignoremark

```raku
# accept haystack if "bar" is found, regardless of any accents
my &anycase = compile-needle("bar", :ignoremark);
```

Allow characters to match even if they have accents (or not).

### smartmark

```raku
# accept haystack if "bar" is found, regardless of any accents
my &anymark = compile-needle("bar", :smartmark);

# accept haystack if "bår" is found
my &exactmark = compile-needle("bår", :smartcase);
```

If the needle is a string and does **not** contain any characters with accents, then `ignoremark` semantics will be assumed.

Types of matches
----------------

### auto

This is the default type of match. It looks at the given string for a number of markers, and adjust the type of match and the string accordingly. The following markers are recognized:

#### starts with !

```raku
my role Type { has $.type }

# accept haystack if "bar" is NOT found
my &implicit = compile-needle("!bar");
my &bypair   = compile-needle("not" => "bar");
my &mixedin  = compile-needle("bar" but Type<not>);
```

This is a meta-marker. Assumes the string given (without the `!`) should be processed, and its result negated (see: type is "not")

#### starts with §

```raku

```

Assumes the string given (without the `§`) should match with word-boundary semantics applied (see: type is "code").

#### starts with *

```raku

```

Assumes the given string is a valid `WhateverCode` specification and attempts to produce that specification accordingly (see: type is "code").

#### starts with ^

```raku

```

Assumes the string given (without the `^`) should match with `.starts-with` semantics applied (see: type is "starts-with").

#### ends with $

```raku

```

Assumes the string given (without the `$`) should match with `.ends-with` semantics applied (see: type is "ends-with").

#### starts with ^ and ends with $

```raku

```

Assumes the string given (without the `^` and `$`) should match exactly (see: type is "equal").

#### starts with / and ends with /

```raku

```

Assumes the string given (without the `/`'s) is a regex and attempts to produce a `Regex` object and wraps that in a call to `.contains` (see: type is "regex").

#### starts with { and ends with }

```raku

```

Assumes the string given (without the `{` and `}`) is an expression and attempts to produce the code (see: type is "code").

#### none of the above

```raku
# accept haystack if it contains "bar"
my &needle = compile-needle("bar");
```

Assumes the string given should match with `.contains` semantics applied (see: type is "contains").

### code

```raku
# return uppercase version of the haystack
my &needle = compile-needle("code" => ".uc");
```

Assumes the string is an expression and attempts to produce that code, with the haystack being presented as the topic (`$_`).

### contains

```raku
# accept haystack if it contains "bar"
my &needle = compile-needle("contains" => "bar");
```

Assumes the string is a needle in a call to `.contains`.

### ends-with

```raku
# accept haystack if it ends with "bar"
my &needle = compile-needle("ends-with" => "bar");
```

Assumes the string is a needle in a call to `.ends-with`.

### equal

```raku
# accept haystack if it is equal to "bar"
my &needle = compile-needle("equal" => "bar");
```

Assumes the string is a needle to compare with the haystack using infix `eq` semantics.

### not

```raku
# accept haystack if "bar" is NOT found
my &needle = compile-needle("not" => "bar");
```

This is a meta-type: it inverts the result of the result of matching of the given needle (which can be anything otherwise acceptable).

### regex

```raku
# accept haystack if "bar" is found
my &needle = compile-needle("regex" => "bar");
```

Assumes the string is a regex specification to be used as a needle in a call to `.contains`.

### starts-with

```raku
# accept haystack if it starts with "bar"
my &needle = compile-needle("starts-with" => "bar");
```

Assumes the string is a needle in a call to `.starts-with`.

### words

```raku
# accept haystack if "bar" is found as a word
my &needle = compile-needle("words" => "bar");
```

Assumes the string is a needle that will match if the needle is found with word boundaries on eiher side of the needle.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Needle-Compile . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

