=begin pod

=head1 NAME

Needle::Compile - compile a search needle specification

=head1 SYNOPSIS

=begin code :lang<raku>

use Needle::Compile;

my &needle = compile-needle("bar");
say needle("foo bar baz");             # True
say needle("Huey, Dewey, and Louie");  # False

=end code

=head1 DESCRIPTION

Needle::Compile exports a single subroutine "compile-needle" that takes
a number of arguments that specify a search query, and returns a C<Callable>
that can be called with a given haystack to see if there is a match.

It can as such be used as the argument to the C<rak> subroutine provided
by the L<C<rak>|https://raku.land/zef:lizmat/rak> distribution.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/eigenstates . Comments and
Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2020, 2021, 2022, 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
