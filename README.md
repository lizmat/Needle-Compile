[![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions) [![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions) [![Actions Status](https://github.com/lizmat/Needle-Compile/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Needle-Compile/actions)

NAME
====

Needle::Compile - compile a search needle specification

SYNOPSIS
========

```raku
use Needle::Compile;

my &needle = compile-needle("bar");
say needle("foo bar baz");             # True
say needle("Huey, Dewey, and Louie");  # False
```

DESCRIPTION
===========

Needle::Compile exports a single subroutine "compile-needle" that takes a number of arguments that specify a search query, and returns a `Callable` that can be called with a given haystack to see if there is a match.

It can as such be used as the argument to the `rak` subroutine provided by the [`rak`](https://raku.land/zef:lizmat/rak) distribution.

SEARCH QUERY SPECIFICATION
==========================

A query can consist of multiple needles of different types. A type of needle can be specified in 3 ways:

  * implicitely

By using textual markers at the start and end of the given string needle (see: type is "auto").

  * explicitely

By specifying a needle as a `Pair`, with the key being a string describing the type.

  * mixed in

If the needle specified supports a `.type` method, then that method will be called to determine the type.

Modifiers
---------

Many types of matches support `ignorecase` and `ignoremark` semantics. These can be specified explicitely (with the `:ignorecase` and `:ignoremark` named arguments), or implicitely with the `:smartcase` and `:smartmark` named arguments.

  * smartcase

If the needle is a string and does **not** contain any uppercase characters, then `ignorecase` semantics will be assumed.

  * smartmark

If the needle is a string and does **not** contain any characters with accents, then `ignoremark` semantics will be assumed.

Types of matches
----------------

### auto

This is the default type of match. It looks at the given string for a number of markers, and adjust the type of match and the string accordingly. The following markers are recognized:

  * starts with !

This is a meta-marker. Assumes the string given (without the `!`) should be processed, and its result negated (see: type is "not")

  * starts with §

Assumes the string given (without the `§`) should match with word-boundary semantics applied (see: type is "code").

  * starts with *

Assumes the given string is a valid `WhateverCode` specification and attempts to produce that specification accordingly (see: type is "code").

  * starts with ^

Assumes the string given (without the `^`) should match with `.starts-with` semantics applied (see: type is "starts-with").

  * ends with $

Assumes the string given (without the `$`) should match with `.ends-with` semantics applied (see: type is "ends-with").

  * starts with ^ and ends with $

Assumes the string given (without the `^` and `$`) should match exactly (see: type is "equal").

  * starts with / and ends with /

Assumes the string given (without the `/`'s) is a regex and attempts to produce a `Regex` object and wraps that in a call to `.contains` (see: type is "regex").

  * starts with { and ends with }

Assumes the string given (without the `{` and `}`) is an expression and attempts to produce the code (see: type is "code").

  * none of the above

Assumes the string given should match with `.contains` semantics applied (see: type is "contains").

### code

Assumes the string is an expression and attempts to produce that code, with the haystack being presented as the topic (`$_`).

### contains

Assumes the string is a needle in a call to `.contains`.

### ends-with

Assumes the string is a needle in a call to `.ends-with`.

### equal

Assumes the string is a needle to compare with the haystack using infix `eq` semantics.

### not

This is a meta-type: it inverts the result of the result of matching of the given needle (which can be anything otherwise acceptable).

### regex

Assumes the string is a regex specification to be used as a needle in a call to `.contains`.

### starts-with

Assumes the string is a needle in a call to `.starts-with`.

### words

Assumes the string is a needle that will match if the needle is found with word-boundaries on eiher side of the needle.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Needle-Compile . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

