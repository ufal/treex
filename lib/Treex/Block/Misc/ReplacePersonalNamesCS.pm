package Treex::Block::Misc::ReplacePersonalNamesCS;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();


my %frequent_names = (
    'Y' => [qw(Jiří Jan Petr Josef Pavel Jaroslav Martin Tomáš Miroslav
               František Zdeněk Václav Michal Karel Milan Vladimír Lukáš David Jakub Ladislav)],
    'S' => [qw(Novák Svoboda Novotný Dvořák Černý Procházka Kučera Veselý Horák Němec Pospíšil
               Pokorný Marek Hájek Jelínek Král Růžička Beneš Fiala Sedláček)],
);

my %mapping;

sub process_anode {
    my ( $self, $anode ) = @_;

    return if $anode->is_root;

    if ($anode->lemma =~ /;([YS])/) {
        my $lemma = $anode->lemma;
        my $type = $1;

        my $new_lemma = $mapping{$type}{$lemma};

        if (not defined $new_lemma) {
            my $rand_index = rand(scalar(@{$frequent_names{$type}}));
            $new_lemma = $frequent_names{$type}[$rand_index];
            $mapping{$type}{$lemma} = $new_lemma;
        }

        $anode->set_lemma($new_lemma);
        my ($new_form) = map {$_->get_form}
            $generator->forms_of_lemma( $new_lemma, { tag_regex => $anode->tag } );
        $anode->set_form($new_form);

    }
}

1;

=head1 NAME

Treex::Block::Misc::ReplacePersonalNamesCS

=head1 DESCRIPTION

Replace personal names (first names as well as surnames, signalled by lemma suffix)
by new names randomly chosen from the most frequent Czech names. Inflect the new names
accordingly to the morphological tag of original names.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
