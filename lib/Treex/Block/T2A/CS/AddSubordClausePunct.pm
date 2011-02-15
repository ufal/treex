package Treex::Block::T2A::CS::AddSubordClausePunct;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot          = $zone->get_atree();
    my @anodes         = $aroot->get_descendants( { ordered => 1 } );
    my @clause_numbers = map { $_->clause_number } @anodes;
    ##my @afuns          = map { $_->afun || '' } @anodes;
    my @lemmas = map { lc $_->lemma || '' } @anodes;
    push @lemmas, 'dummy';

    foreach my $i ( 0 .. $#anodes - 1 ) {

        # Skip if we are not at the clause boundary
        next if $clause_numbers[$i] == $clause_numbers[ $i + 1 ];

        # Skip words with clause_number=0 (e.g. brackets separating clauses)
        next if !$clause_numbers[ $i + 1 ];

        # Now, we are at the clause boundary
        # ($nodes[$i] and $nodes[$i+1] have different clause_number).
        # However, on some boundaries the comma is not needed/allowed:
        # a) left or right token is a punctuation (e.g. three dots)
        next if any { $_ =~ /^[,:;.?!-]/ } @lemmas[ $i, $i + 1 ];

        # b) left or right token is a conjunction
        #    (Commas in front of conjunctions are solved in Add_coord_punct.)
        #next if any { $_ eq 'Coord' } @afuns[$i, $i + 1]; #!!! tohle by bylo lepsi reseni, ale na afuny zatim neni spoleh
        next if any { $_ =~ /^(a|ale|nebo|buď)$/ } @lemmas[ $i, $i + 1 ];    # deleted "i" because of "i kdyz"

        # c) left token is an opening quote
        next if $lemmas[$i] eq '„';

        # d) right token is an closing quote followed by period (end of sentence)
        next if $lemmas[ $i + 1 ] eq '“' && $lemmas[ $i + 2 ] eq '.';

        # e) left token is a closing quote preceeded by a comma (inserted in the last iteration)
        next if $lemmas[$i] eq '“' && $i && $anodes[$i]->get_prev_node->lemma eq ',';

        # Comma's parent should be the highest of left/right clause roots
        my $left_clause_root  = $anodes[$i]->get_clause_root();
        my $right_clause_root = $anodes[ $i + 1 ]->get_clause_root();
        my $the_higher_clause_root =
            $left_clause_root->get_depth() > $right_clause_root->get_depth()
            ? $left_clause_root : $right_clause_root;

        my $comma = $the_higher_clause_root->create_child(
            {   attributes => {
                    'form'          => ',',
                    'lemma'         => ',',
                    'afun'          => 'AuxX',
                    'morphcat/pos'  => 'Z',
                    'clause_number' => 0,

                    }
            }
        );

        $comma->shift_after_node( $anodes[$i] );

        # left token is a closing quote
        # A special typographic rule says the comma should go before quotes,
        # if the quoted text is a whole clause. For example:
        # „Nechci,“ řekl Karel.
        # Bydleli jsme v hotelu „Hilton“, který spadl.
        # Actually, it is even more complicated.
        # According to ÚJČ (http://prirucka.ujc.cas.cz/?id=162):
        # Pepa říkal: „Pavel je kanón.“
        # Můj děd říkával, že „konec všechno napraví“.

        # However, most reference translations do not follow ÚJČ.
        #if ( $forms[$i] eq '“' ) {
        #    for my $j ( 1 .. $i ) {
        #        last if $forms[ $i - $j ] eq '„';
        #        if ( $anodes[ $i - $j ]->get_attr('morphcat/pos') eq 'V' ) {
        #            $comma->shift_before_node( $anodes[$i] );
        #            last;
        #        }
        #    }
        #}
    }

    # moving commas in 'clausal' pronominal expletives such as ',pote co' -> 'pote, co';
    @anodes = $aroot->get_descendants( { ordered => 1 } );
    foreach my $i ( 0 .. $#anodes - 2 ) {
        if ($anodes[ $i + 1 ]->lemma eq 'poté'
            and $anodes[$i]->lemma   eq ','
            )
        {

            #            print $anodes[$i]->get_fposition."\n";
            $anodes[$i]->shift_after_node( $anodes[ $i + 1 ], { without_children => 1 } );
        }
    }

    return;
}

1;

__END__

=over

=item Treex::Block::T2A::CS::AddSubordClausePunct

Add a-nodes corresponding to commas on clause boundaries
(boundaries of relative clauses as well as
of clauses introduced with subordination conjunction).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
