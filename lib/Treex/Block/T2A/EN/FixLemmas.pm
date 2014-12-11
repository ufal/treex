package Treex::Block::T2A::EN::FixLemmas;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my %PERSPRON = (
    'S 1'        => 'I',
    'S 1 poss'   => 'my',
    'S 2'        => 'you',
    'S 2 poss'   => 'your',
    'S 3 M'      => 'he',
    'S 3 M poss' => 'his',
    'S 3 F'      => 'she',
    'S 3 F poss' => 'her',
    'S 3 N'      => 'it',
    'S 3 N poss' => 'its',
    'P 1'        => 'we',
    'P 1 poss'   => 'our',
    'P 2'        => 'you',
    'P 2 poss'   => 'your',
    'P 3'        => 'they',
    'P 3 poss'   => 'their',
);

sub process_anode {
    my ( $self, $anode ) = @_;
    my $lemma = $anode->lemma or return;

    # fix personal pronouns
    if ( $lemma eq '#PersPron' ) {
        my $num  = ( $anode->morphcat_number // '.' ) ne '.' ? $anode->morphcat_number : 'S';
        my $pers = ( $anode->morphcat_person // '.' ) ne '.' ? $anode->morphcat_person : '3';
        my $sig  = "$num $pers";

        if ( $pers eq '3' and $num eq 'S' ) {
            my $gen = ( $anode->morphcat_gender // '.' ne '.' ) ? $anode->morphcat_gender : 'N';
            $sig .= ' ' . $gen;
        }
        if ( $anode->morphcat_subpos eq 'S' ) {    # possessives
            $sig .= ' poss';
        }
        $anode->set_lemma( $PERSPRON{$sig} );
    }

    # fix negation particle
    elsif ( $lemma eq '#Neg' ) {
        $anode->set_lemma('not');
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::FixLemmas

=head1 DESCRIPTION

Fixing lemmas of personal pronouns and negation particles (converting C<#Neg> and C<#PersPron>
to corresponding surface values).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
