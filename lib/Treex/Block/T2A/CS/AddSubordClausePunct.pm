package Treex::Block::T2A::CS::AddSubordClausePunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubordClausePunct';

has 'open_punct' => ( is => 'ro', 'isa' => 'Str', default => '^[„‚]$' );

has 'close_punct' => ( is => 'ro', 'isa' => 'Str', default => '^[“‘]$' );

override 'no_comma_between' => sub {
    my ($self, @nodes) = @_;

    # b) left or right token is a conjunction
    #    (Commas in front of conjunctions are solved in Add_coord_punct.)
    #next if any { $_ eq 'Coord' } @afuns[$i, $i + 1]; #!!! tohle by bylo lepsi reseni, ale na afuny zatim neni spoleh
    return 1 if any { $_ =~ /^(a|ale|nebo|buď)$/ } map { $_->lemma } @nodes;    # deleted "i" because of "i kdyz"
    return 0;
};

override 'postprocess_comma' => sub {
    my ( $self, $anode, $comma ) = @_;

    # left token is a closing quote
    # A special typographic rule says the comma should go before quotes,
    # if the quoted text is a whole clause. For example:
    # „Nechci,“ řekl Karel.
    # Bydleli jsme v hotelu „Hilton“, který spadl.
    # Actually, it is even more complicated.
    # According to ÚJČ (http://prirucka.ujc.cas.cz/?id=162):
    # Pepa říkal: „Pavel je kanón.“
    # Můj děd říkával, že „konec všechno napraví“.
    if ( $anode->lemma eq '“' ) {

        # However, most reference translations follow the source sentence wording, not ÚJČ.
        my $src_zone = $anode->get_bundle()->get_zone( 'en', 'src' );
        if ( !$src_zone || $src_zone->sentence !~ /[»"'”],/ ) {

            # Filter out cases as "Hilton", by looking for a verb inside the quotes
            my (@prev_nodes) = grep { $_->ord < $anode->ord } ( $anode->get_root->get_descendants( { ordered => 1 } ) );
            foreach my $cur_node ( reverse @prev_nodes ) {
                last if $cur_node->lemma eq '„';
                if ( $cur_node->morphcat_pos eq 'V' ) {
                    $comma->shift_before_node($anode);
                    last;
                }
            }
        }
    }
};

override 'postprocess_sentence' => sub {
    my ( $self, $aroot ) = @_;

    # moving commas in 'clausal' pronominal expletives such as ',pote co' -> 'pote, co';
    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    foreach my $i ( 0 .. $#anodes - 2 ) {
        if ($anodes[ $i + 1 ]->lemma eq 'poté'
            and $anodes[$i]->lemma   eq ','
            )
        {

            #            print $anodes[$i]->get_address."\n";
            $anodes[$i]->shift_after_node( $anodes[ $i + 1 ], { without_children => 1 } );
        }
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSubordClausePunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas on clause boundaries
(boundaries of relative clauses as well as
of clauses introduced with subordination conjunction).

Czech coordination conjunctions are avoided.

Note: Contains a hack specific to EN-CS translation regarding
moving the comma before/after the punctuation.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
