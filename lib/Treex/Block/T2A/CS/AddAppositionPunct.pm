package Treex::Block::T2A::CS::AddAppositionPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS::PersonalRoles;
use Treex::Tool::Lexicon::CS::NamedEntityLabels;

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent();
    return if $parent->is_root();

    if ($tnode->formeme eq 'n:attr'
        and $parent->precedes($tnode) and !$parent->is_root
        and $parent->formeme =~ /^n/
        and ( $tnode->gram_sempos || '' ) eq 'n.denot'    # not numerals etc.
        and (
            Treex::Tool::Lexicon::CS::PersonalRoles::is_personal_role( $tnode->t_lemma )
            || Treex::Tool::Lexicon::CS::NamedEntityLabels::is_label( $tnode->t_lemma )
        )
        )
    {

        my $anode = $tnode->get_lex_anode;

        # first comma separating the two apposited members
        my $left_comma = add_comma_node( $anode->get_parent );
        $left_comma->shift_before_subtree($anode);

        # another comma added after the second apposited member only
        # if there is no other punctuation around
        if ( defined $anode ) {

            my $rightmost_descendant = $anode->get_descendants( { last_only => 1, add_self => 1 } );
            my $after_rightmost = $rightmost_descendant->get_next_node;

            if ( defined $after_rightmost ) {    # not the end of the sentence
                if ( !grep { $_->get_attr('morphcat/pos') eq 'Z' } ( $rightmost_descendant, $after_rightmost ) ) {
                    my $right_comma = add_comma_node( $anode->get_parent );
                    $right_comma->shift_after_subtree($anode);
                }
            }
        }
    }
    return;
}

sub add_comma_node {
    my ($parent) = @_;
    return $parent->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
}

1;

=over

=item Treex::Block::T2A::CS::AddAppositionPunct

Add commas in apposition constructions such as
'John, my best friend, ...'


=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
