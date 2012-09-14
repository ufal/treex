#!/usr/bin/env perl

use Test::More;
use Treex::Core::Common;

use Moose::Util::TypeConstraints qw(find_type_constraint);
ok(find_type_constraint('Treex::Type::NonNegativeInt'), 'Find type defined not directly in Common but in used module');

done_testing();
