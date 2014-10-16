package Treex::Block::T2A::NL::FixLemmas;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my %PERSPRON = (
    'sing 1'      => 'ik',
    'sing 2 inf'  => 'je',
    'sing 2 pol'  => 'u',
    'sing 3 masc' => 'hij',
    'sing 3 fem'  => 'zij',
    'sing 3 com'  => 'hij',
    'sing 3 neut' => 'het',
    'plu 1'       => 'wij',
    'plu 2 inf'   => 'jullie',
    'plu 2 inf'   => 'u',
    'plu 3'       => 'zij',
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
        if ( $pers eq '3' and $num eq 'sing' ) {
            $sig .= ' ' . ( $anode->iset->gender || 'neut' );
        }
        $anode->set_lemma( $PERSPRON{$sig} );
    }

    # fix negation particle
    elsif ( $lemma eq '#Neg' ) {
        $anode->set_lemma('niet');
    }
    
    # fix compound word lemmas (lower case letters but no upper-case letter follows an underscore)
    elsif ( $lemma =~ /_\p{Ll}/ and $lemma !~ /_\p{Lu}/){
        $lemma =~ s/ing_/ings/g; # verzekering_maatschappij -> verzekeringsmaatschappij
        $lemma =~ s/beroep_/beroeps/g; # beroep_ethiek -> beroepsethiek
        $lemma =~ s/_//g;
        $anode->set_lemma($lemma);
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
