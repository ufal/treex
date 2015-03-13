package Treex::Core::Common;

use strict;
use warnings;
use 5.010;

use utf8;
use Moose::Exporter;
use Moose::Util::TypeConstraints;
use MooseX::SemiAffordanceAccessor::Role::Attribute 0.09;
use Treex::Core::Log;
use Treex::Core::Config;
use Treex::Core::Resource;
use Treex::Core::Types;
use Treex::Core::Files;
use List::MoreUtils;
use List::Util;
use Scalar::Util;
use Readonly;
use Data::Dumper;

# sub reference for validating of params
# Sets default values for unspecified params
my $validation_sub;

# Quick alternative for MooseX::Params::Validate::pos_validated_list
sub pos_validated_list {
    my $args_ref = shift;
    my @args = @{$args_ref};
    my $i        = 0;
    while ( ref $_[0] eq 'HASH' ) {
        my $spec = shift;
        if ( defined $spec->{default} ) {
            $args[$i] //= $spec->{default};
        }
        $i++;
    }
    return @args;
}

# Choose which variant to use according to $Treex::Core::Config::params_validate
if ( $Treex::Core::Config::params_validate == 2 ) {    ## no critic (ProhibitPackageVars)
    require MooseX::Params::Validate;
    $validation_sub = \&MooseX::Params::Validate::pos_validated_list;
}
else {
    $validation_sub = \&pos_validated_list;
}

my ( $import, $unimport, $init_meta ) =
    Moose::Exporter->build_import_methods(
    install         => [qw(unimport init_meta)],
    class_metaroles => { attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute'] },
    as_is           => [
        \&Treex::Core::Log::log_fatal,
        \&Treex::Core::Log::log_warn,
        \&Treex::Core::Log::log_debug,
        \&Treex::Core::Log::log_set_error_level,
        \&Treex::Core::Log::log_info,
        \&Treex::Core::Types::get_lang_name,
        \&Treex::Core::Types::is_lang_code,
        \&Treex::Core::Resource::require_file_from_share,
        \&List::MoreUtils::first_index,
        \&List::MoreUtils::all,
        \&List::MoreUtils::any,
        \&List::MoreUtils::none,
        \&List::MoreUtils::uniq,
        \&List::Util::first,
        \&List::Util::min,
        \&List::Util::max,
        \&Readonly::Readonly,
        \&Scalar::Util::weaken,
        \&Data::Dumper::Dumper,
        \&Moose::Util::TypeConstraints::enum,
        $validation_sub,
        ]
    );

sub import {
    feature->import(':5.10');
    utf8::import();
    goto &$import;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Common - shorten the "C<use>" part of your Perl codes

=head1 SYNOPSIS

Write just

 use Treex::Core::Common;

Instead of

 use utf8;
 use strict;
 use warnings;
 use Moose::Util::TypeConstraints qw(enum);
 use MooseX::SemiAffordanceAccessor;
 use MooseX::Params::Validate qw(pos_validated_list);
 use Treex::Core::Log;
 use Treex::Core::Config;
 use Treex::Core::Resource;
 use Treex::Core::Types;
 use Treex::Core::Files;
 use List::MoreUtils qw(all any none uniq first_index);
 use List::Util qw(first min max);
 use Scalar::Util qw(weaken);
 use Readonly qw(Readonly);
 use Data::Dumper qw(Dumper);


=head1 SUBROUTINES

=over

=item $language_name = get_lang_name($iso639_code)

=item $bool = is_lang_code($iso639_code)

=item pos_validated_list

This subroutine is automatically exported. Depending on the value of
L<$Treex::Core::Config::params_validate|Treex::Core::Config/params_validate>
it is either the (slow) one from
L<MooseX::Params::Validate> or a fast one, that does
no type checking.

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
