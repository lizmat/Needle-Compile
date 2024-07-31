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

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/eigenstates . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2020, 2021, 2022, 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

