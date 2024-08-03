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
use Needle::Compile "Type";

# accept haystack if "bar" as word is found
my &needle = compile-needle("bar" but Type("words"));
```

If the specified needle supports a `.type` method, then that method will be called to determine the type. This can be done with the `Type` role that is optionally exported.

If you specify `"Type"` in the `use` statement, a `Type` role will be exported that allows you to mixin a type with a given string. The `Type` role will only allow known types in its specification. If that is too restrictive for your application, you can define your own `Type` role. Which can be as simple as:

```raku
my role Type { $.type }
```

If you want to be able to dispatch on strings that have a `but Type` mixed in, you can also import the `StrType` class:

```raku
use Needle::Compile <Type StrType>;

say "foo" but Type<words> ~~ Str;      # True
say "foo" but Type<words> ~~ StrType;  # True
say "foo"                 ~~ StrType;  # False
```

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
# accept haystack if "bar" is NOT found
my &needle = compile-needle('!bar');
```

This is a meta-marker. Assumes the string given (without the `!`) should be processed, and its result negated (see: type is "not").

#### starts with &

```raku
# accept haystack if "foo" and "bar" are found
my &needle = compile-needle('foo', '&bar');
```

This is a meta-marker. Marks the needle produced for the given string (without the `&`) as needing an `&&` infix with its predecessor be processed, rather than the default `||` infix (see: type is "and").

#### starts with §

```raku
# accept haystack if "bar" is found as a word
my &needle = compile-needle('§bar');
```

Assumes the string given (without the `§`) should match with word-boundary semantics applied (see: type is "words").

#### starts with *

```raku
# accept haystack if alphabetically before "bar"
my &is-before = compile-needle('* before "bar"');

# return every haystack uppercased
my &uppercased = compile-needle('*.uc');
```

Assumes the given string is a valid `WhateverCode` specification and attempts to produce that specification accordingly (see: type is "code").

#### starts with ^

```raku
# accept haystack if it starts with "bar"
my &needle = compile-needle('^bar');
```

Assumes the string given (without the `^`) should match with `.starts-with` semantics applied (see: type is "starts-with").

#### starts with file:

```raku
# accept matching patterns in file "always"
my &needle = compile-needle('file:always');
```

Assumes the given string (without the `file:` prefix) is a valid path specification, pointing to a file containing the patterns to be used (see: type is "file").

#### starts with jp:

```raku
# return result of JSON::Path query "auth"
my &needle = compile-needle('jp:auth');
```

Assumes the given string (without the `jp:` prefix) is a valid [`JSON Path`](https://en.wikipedia.org/wiki/JSONPath) specification (see: type is "json-path").

#### starts with s:

```raku
# accept if string contains "foo" *and* "bar"
my &needle = compile-needle('s:foo &bar');
```

Splits the given string (without the `s:` prefix) on whitespace and interpretes the result as a list of needles (see: type is "split").

#### ends with $

```raku
# accept haystack if it ends with "bar"
my &needle = compile-needle('bar$');
```

Assumes the string given (without the `$`) should match with `.ends-with` semantics applied (see: type is "ends-with").

#### starts with ^ and ends with $

```raku
# accept haystack if it is equal to "bar"
my &needle = compile-needle('^bar$');
```

Assumes the string given (without the `^` and `$`) should match exactly (see: type is "equal").

#### starts with / and ends with /

```raku
# accept haystack if it matches "bar" as a regular expression
my &needle = compile-needle('/bar/');
```

Assumes the string given (without the `/`'s) is a regex and attempts to produce a `Regex` object and wraps that in a call to `.contains` (see: type is "regex").

#### starts with { and ends with }

```raku
# return the lowercased, whitespace trimmed haystack
my &needle = compile-needle('{.trim.lc}');
```

Assumes the string given (without the `{` and `}`) is an expression and attempts to produce the code (see: type is "code").

#### none of the above

```raku
# accept haystack if it contains "bar"
my &needle = compile-needle("bar");
```

Assumes the string given should match with `.contains` semantics applied (see: type is "contains").

### and

```raku
# accept haystack if "foo" and "bar" are found
my &needle = compile-needle('foo', "and" => 'bar');
```

This is a meta-marker. Marks the needle produced for the given string as needing an `&&` infix with its predecessor be processed, rather than the default `||` infix. Has no meaning on the first (or only) needle in a list of needles.

### code

```raku
# return uppercase version of the haystack
my &needle = compile-needle("code" => ".uc");
```

Assumes the string is an expression and attempts to produce that code, with the haystack being presented as the topic (`$_`).

To facilitate the use of libraries that wish to access that topic, it is also available as the `$*_` dynamic variable.

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

### file

```raku
# return result of matching patterns in file "always"
my &needle = compile-needle("file" => 'always');
```

Assumes the given string is a valid path specification, pointing to a file containing the patterns to be used.

The following types of lines will be ignored:

  * empty lines

  * lines consisting of whitespace only

  * lines starting with "#"

#### starts with jp:

### json-path

```raku
# return result of JSON::Path query "auth"
my &needle = compile-needle("json-path" => 'auth');
```

Assumes the given string is a valid [`JSON Path`](https://en.wikipedia.org/wiki/JSONPath) specification.

Must have the [`JSON::Path`](https://raku.land/cpan:JNTHN/JSON::Path) module installed.

The generated `Callable` will expect an `Associative` haystack (aka, a <Hash>) to be passed, and will return a `Slip` with any results.

```raku
# return result of JSON::Path query "auth"
my &needle = compile-needle({ jp('auth').Slip });
```

Alternately, you can also the `jp()` function. This returns a specialized `JP` object. Note that simply specifying a call to the `jp` function is not enough: one must do something with it. In the above example calling `.Slip` will cause the actual querying to happen.

See "Doing JSON path queries in code needles" for more information.

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

### split

```raku
# accept if string contains "foo" *and* "bar"
my &needle = compile-needle("split" => 'foo &bar');
```

This is a meta-type: it splits the given string on whitespace and interpretes the result as a list of needles.

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

Assumes the string is a needle that will match if the needle is found with word boundaries on either side of the needle.

Doing JSON path queries in code needles
---------------------------------------

```raku
# return result of JSON::Path query "auth"
my &needle = compile-needle({ jp('auth').Slip });
```

The initial call to the `jp` function will attempt to load the `JSON::Path` module, and fail if it cannot. If the load is successful, it will create an object of the (internal) `JP` class with the giveni pattern.

If the `JSON::Path` module was already loaded, it will either produce the `JP` object from a cache, or create a new `JP` object.

The object as such, does nothing. It needs to have a method called on it **within the scope of the code needle** to properly function.

If you're using the (implicit) `"json-path"` type for your needle, this is done automatically for you, by calling the `.Slip` method on it.

The following methods can be called on the `JP` object:

<table class="pod-table">
<thead><tr>
<th>method</th> <th>selected</th>
</tr></thead>
<tbody>
<tr> <td>.value</td> <td>The first selected value</td> </tr> <tr> <td>.values</td> <td>All selected values as a Seq</td> </tr> <tr> <td>.paths</td> <td>The paths of all selected values as a Seq</td> </tr> <tr> <td>.paths-and-values</td> <td>Interleaved selected paths and values</td> </tr> <tr> <td>.words</td> <td>All words in selected values as a Slip</td> </tr> <tr> <td>.head</td> <td>The first N selected values as a Slip</td> </tr> <tr> <td>.tail</td> <td>The last N selected values as a Slip</td> </tr> <tr> <td>.skip</td> <td>Skip N selected values, produce rest as a Slip</td> </tr> <tr> <td>.Seq</td> <td>All selected values as a Seq</td> </tr> <tr> <td>.Bool</td> <td>True if any values selected, else False</td> </tr> <tr> <td>.List</td> <td>All selected values as a List</td> </tr> <tr> <td>.Slip</td> <td>All selected values as a Slip</td> </tr> <tr> <td>.gist</td> <td>All selected values stringified as a gist</td> </tr> <tr> <td>.Str</td> <td>All selected values stringified</td> </tr>
</tbody>
</table>

```raku
# return first and third result of JSON::Path query "auth" as a Slip
my &needle = compile-needle({ jp('auth')[0,2] });
```

Furthermore, you can use postcircumfix `[ ]` on the `JP` object to select values from the result.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Needle-Compile . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

