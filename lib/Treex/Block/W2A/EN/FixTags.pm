package Treex::Block::W2A::EN::FixTags;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    my $old_tag = $anode->tag;
    my $new_tag = $self->_get_tag($anode);
    if ( $new_tag && $new_tag ne $old_tag ) {
        $anode->set_tag($new_tag);
        $anode->set_attr( 'gloss', 'tag_origin=Fix_tags' );
    }

    return 1;
}

sub _get_tag {
    my ( $self, $node ) = @_;
    my ( $form, $tag ) = $node->get_attrs( 'form', 'tag' );

    #my ( $form, $tag, $id ) = $node->get_attrs( 'form', 'tag', 'id' );
    # Abbreviations like MPs, CDs or DVDs should be tagged as plural proper noun
    return 'NNPS' if $tag =~ /^NN/ && $form =~ /^\p{IsUpper}{2,}s$/;

    # All other rules are case insensitive
    $form = lc $form;

    # "sooner" and "later" should be comparative (RBR or JJR)
    # This goes against Penn Treebank Tagging Guidelines:
    #  ``Should be tagged as a simple adverb (RB) rather than as a comparative
    #    adverb (RBR), unless its meaning is clearly comparative.
    #    EXAMPLES: I'll get it around sooner/RB or later/RB.
    #              We'll arrive (even) later/RBR than your mother.
    #  ''
    # However, this particular guideline doesn't match our (MT) purposes.
    # The distinction can be seen on t-layer: gram/degcmp = comp vs. acomp.
    return 'RBR' if $form =~ /^(lat|soon|earli)er/ && $tag eq 'RB';

    # According to PTB Guidelines "e. g." is FW
    return 'FW' if $form eq 'e. g.';

    # Morce can tag "2008" as VBP, but this rule may help also some dict. base taggers
    return 'CD' if $form =~ /^\d+$/;

    # 1990s
    return 'CD' if $form =~ /^\d\d\d0s$/;

    # Iraqis = inhabitants of Iraq (The American Heritage Dictionary), Morce puts NNP
    return 'NNPS' if $form eq 'iraqis';

    # Morce has "burnt = VBD|VBN" in some dictionaries, but doesn't use it
    return 'VBD' if $form eq 'burnt' && $tag !~ /VB[DN]/;

    # '£' should have the same tag as '$' has
    return '$' if $form eq '£';

    # In "There!" it is not an existential there, but simple adverb.
    # Otherwise, we would get an empty t-tree for such sentences.
    return 'RB' if $tag eq 'EX'
            && join( '', map { $_->form } $node->get_root->get_descendants( { ordered => 1 } ) ) =~ /^There.?$/;


    # the enities found by a gazeteer list considered being proper nouns
    return 'NNP' if (defined $node->wild->{gazeteer_entity_id});

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::FixTags - Fixes tags for TectoMT purposes.

=head1 DESCRIPTION

=over 4

=item sooner

"sooner" and "later" are always tagged as C<RBR> (comparative adverb)
Beware that this goes against Penn Treebank Tagging Guidelines.

=item "e. g." -> FW (according to PTB Guidelines)

=item numbers

All numbers (C</^\d+$/>) get tag CD.

=item plural abbreviations

Abbreviations like I<MPs, CDs or DVDs> are tagged as plural proper noun (C<NNPS>).

=back

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_anode

=back

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

