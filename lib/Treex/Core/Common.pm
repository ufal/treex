package Treex::Core::Common;
use utf8;
use Moose;
use Moose::Exporter;
use Moose::Util::TypeConstraints;
use MooseX::SemiAffordanceAccessor::Role::Attribute;
use Treex::Core::Log;
use Treex::Core::Config;
use Treex::Core::Resource;
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
    my $i        = 0;
    while ( ref $_[0] eq 'HASH' ) {
        my $spec = shift;
        if ( defined $spec->{default} ) {
            $args_ref->[$i] ||= $spec->{default};
        }
        $i++;
    }
    return @{$args_ref};
}

# Choose which variant to use according to Treex::Core::Config::$params_validate
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
    also            => 'Moose',
    class_metaroles => { attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute'] },
    as_is           => [
        \&Treex::Core::Log::log_fatal,
        \&Treex::Core::Log::log_warn,
        \&Treex::Core::Log::log_debug,
        \&Treex::Core::Log::log_set_error_level,
        \&Treex::Core::Log::log_info,
        \&List::MoreUtils::first_index,
        \&List::MoreUtils::all,
        \&List::MoreUtils::any,
        \&List::Util::first,
        \&Readonly::Readonly,
        \&Scalar::Util::weaken,
        \&Data::Dumper::Dumper,
        \&Moose::Util::TypeConstraints::enum,
        $validation_sub,
        ]
    );

sub import {
    utf8::import();
    goto &$import;
}

subtype 'Selector'
    => as 'Str'
    => where {m/^[a-z\d]*$/i}
=> message {"Selector must =~ /^[a-z\\d]*\$/i. You've provided $_"};    #TODO: this messege is not printed

subtype 'Layer'
    => as 'Str'
    => where {m/^[ptan]$/i}
=> message {"Layer must be one of: [P]hrase structure, [T]ectogrammatical, [A]nalytical, [N]amed entities, you've provided $_"};

subtype 'Message'                                                       #nonempty string
    => as 'Str'
    => where { $_ ne '' }
=> message {"Message must be nonempty"};

#preparation for possible future constraints
subtype 'Id'
    => as 'Str';

# TODO: Should this be named ZoneCode or ZoneLabel?
subtype 'ZoneCode'
    => as 'Str'
    => where { my ( $l, $s ) = split /_/, $_; is_lang_code($l) && ( !defined $s || $s =~ /^[a-z\d]*$/i ) }
=> message {'ZoneCode must be LangCode or LangCode_Selector, e.g. "en_src"'};

# ISO 639-1 language code with some extensions from ISO 639-2
# Added code for Modern Greek which comes under ISO 639-3
use Locale::Language;
my %EXTRA_LANG_CODES = (
    'bxr'     => "Buryat",
    'dsb'     => "Lower Sorbian",
    'ell'     => "ISO 639-3 code for Modern Greek",
    'grc'     => "ISO 639-2 code for Ancient Greek",
    'hsb'     => "Upper Sorbian",
    'hak'     => "Hakka",
    'kaa'     => "Karakalpak",
    'ku-latn' => "Kurdish in Latin script",
    'ku-arab' => "Kurdish in Arabic script",
    'ku-cyrl' => "Kurdish in Cyrillic script",
    'nan'     => "Taiwanese",
    'rmy'     => "Romany",
    'sah'     => "Yakut",
    'und'     => "ISO 639-2 code for undetermined/unknown language",
    'xal'     => "Kalmyk",
    'yue'     => "Cantonese"
);

my %IS_LANG_CODE = map { $_ => 1 } ( all_language_codes(), keys %EXTRA_LANG_CODES );

#enum 'LangCode' => keys %IS_LANG_CODE;
subtype 'LangCode'
    => as 'Str'
    => where { defined $IS_LANG_CODE{$_} }
=> message {'LangCode must be valid ISO 639-1 code. E.g. en, de, cs'};
sub is_lang_code { return $IS_LANG_CODE{ $_[0] }; }

sub get_lang_name {
    my $code = shift;
    return exists $EXTRA_LANG_CODES{$code} ? $EXTRA_LANG_CODES{$code} : code2language($code);
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
 use Moose;
 use Moose::Util::TypeConstraints qw(enum);
 use MooseX::SemiAffordanceAccessor;
 use MooseX::Params::Validate qw(pos_validated_list);
 use Treex::Core::Log;
 use Treex::Core::Config;
 use Treex::Core::Resource;
 use List::MoreUtils qw(all any first_index);
 use List::Util qw(first);
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
