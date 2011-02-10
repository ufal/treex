package Treex::Block::A2T::EN::RestoreUppercase;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




use Extensions::Node;
use Extensions::Node::A;
use Extensions::Node::T;

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {

        my $t_root = $bundle->get_tree('SEnglishT');

        # restoration based on a-layer lemmas
        my @bag = grep { defined $_->a } $t_root->get_descendants;

        # collection of unusable (first in sentence) nodes
        my %is_first_in_sentence = ();
        my @s_roots = grep { $_->sentmod || $_->is_functor('PRED') } @bag;
        foreach my $s_root (@s_roots) {

            my $first_one = $s_root->a->get_leftmost_descendant;
            next unless $first_one;

            #Report::info("First one is: " . $first_one->form);
            $is_first_in_sentence{$first_one} = 1;
        }

        foreach my $tnode (@bag) {

            my $anode = $tnode->a;
            next if $is_first_in_sentence{$anode} and not $tnode->get_attr('is_name');
            my $a_lemma = $anode->form;
            next unless defined $a_lemma;

            #Report::info("processing " . $tnode->t_lemma);
            # some uppercase at a-level but no other change between t- and a-levels
            if ( $a_lemma ne lc($a_lemma) && lc($a_lemma) eq $tnode->t_lemma ) {

                $tnode->set_t_lemma($a_lemma);
            }

        }

    }

}

1;

=over

=item Treex::Block::A2T::EN::RestoreUppercase

PEDT tectogramatical data are all in lowercase. This block restores the casing from
the analytical layer where we are sure it is appropriate
ie. where there is only difference in casing and it is not the begining of a sentence. 

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
