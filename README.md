# NAME

DBIx::Class::SQLA2 - SQL::Abstract v2 support in DBIx::Class

# SYNOPSIS

    $schema->connect_call_rebase_sqlmaker('DBIx::Class::SQLA2');

# DESCRIPTION

This is a work in progress for simplifying using SQLA2 with DBIC. This is for using w/ the
most recent version of DBIC.

For a simple way of using this, take a look at [DBIx::Class::Schema::SQLA2Support](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3ASchema%3A%3ASQLA2Support).

**EXPERIMENTAL**

This role itself will add handling of hashref-refs to select lists + group by clauses,
which will render the inner hashref as if it had been passed through to SQLA2 rather than
doing the recursive function rendering that DBIC does.

## Included Plugins

This will add the following SQLA2 plugins:

- [SQL::Abstract::Plugin::ExtraClauses](https://metacpan.org/pod/SQL%3A%3AAbstract%3A%3APlugin%3A%3AExtraClauses)

    Adds support for CTEs, and other fun new SQL syntax

- [SQL::Abstract::Plugin::WindowFunctions](https://metacpan.org/pod/SQL%3A%3AAbstract%3A%3APlugin%3A%3AWindowFunctions)

    Adds support for window functions and advanced aggregates.

- [SQL::Abstract::Plugin::Upsert](https://metacpan.org/pod/SQL%3A%3AAbstract%3A%3APlugin%3A%3AUpsert)

    Adds support for Upserts (ON CONFLICT clause)

- [SQL::Abstract::Plugin::BangOverrides](https://metacpan.org/pod/SQL%3A%3AAbstract%3A%3APlugin%3A%3ABangOverrides)

    Adds some hacky stuff so you can bypass/supplement DBIC's handling of certain clauses

# AUTHOR

Copyright (c) 2022 Veesh Goldman <veesh@cpan.org>

# LICENSE

This module is free software; you may copy this under the same
terms as perl itself (either the GNU General Public License or
the Artistic License)
