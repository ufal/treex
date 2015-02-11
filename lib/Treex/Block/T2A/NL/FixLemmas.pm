package Treex::Block::T2A::NL::FixLemmas;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my %PERSPRON = (
    'sing 1'             => 'ik',
    'sing 1 poss'        => 'mijn',
    'sing 2 inf'         => 'je',
    'sing 2 inf poss'    => 'je',
    'sing 2 pol'         => 'u',
    'sing 2 pol poss'    => 'uw',
    'sing 3 reflex'      => 'zich',
    'sing 3 masc'        => 'hij',
    'sing 3 masc poss'   => 'zijn',
    'sing 3 fem'         => 'zij',
    'sing 3 fem poss'    => 'haar',
    'sing 3 com'         => 'hij',
    'sing 3 com poss'    => 'zijn',
    'sing 3 neut'        => 'het',
    'sing 3 neut poss'   => 'zijn',
    'plur 1'             => 'wij',
    'plur 1 poss'        => 'ons',
    'plur 2 inf'         => 'jullie',
    'plur 2 inf poss'    => 'jullie',
    'plur 2 pol'         => 'u',
    'plur 2 pol poss'    => 'uw',
    'plur 3'             => 'zij',
    'plur 3 poss'        => 'hun',
    'plur 3 reflex'      => 'zich',
);

sub process_anode {
    my ( $self, $anode ) = @_;
    my $lemma = $anode->lemma or return;

    # fix personal pronouns
    if ( $lemma eq '#PersPron' ) {
        my ( $num, $pers ) = ( $anode->iset->number || 'sing', $anode->iset->person || '3' );
        my $sig = "$num $pers";

        if ( $pers eq '2' ) {
            $sig .= ' ' . ( $anode->iset->politeness || 'inf' );
        }
        if ( $pers eq '3' and $anode->iset->reflex and not $anode->iset->poss ){
            $sig .= ' reflex';
        }
        if ( $pers eq '3' and $num eq 'sing' and not $anode->iset->reflex and not $anode->iset->poss ) {
            $sig .= ' ' . ( $anode->iset->gender || 'neut' );
        }
        if ( $anode->iset->poss ) {
            if ( $pers eq '3' and $num eq 'sing' ){
                $sig .= ' ' . ( $anode->iset->possgender || 'neut' );
            }
            $sig .= ' poss';
        }
        $anode->set_lemma( $PERSPRON{$sig} );
    }

    # fix negation particle
    elsif ( $lemma eq '#Neg' ) {
        $anode->set_lemma('niet');
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::NL::FixLemmas

=head1 DESCRIPTION

Fixing lemmas of personal pronouns and negation particles (converting C<#Neg> and C<#PersPron>
to corresponding surface values).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
