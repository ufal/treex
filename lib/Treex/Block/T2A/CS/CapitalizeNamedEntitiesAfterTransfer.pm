package Treex::Block::T2A::CS::CapitalizeNamedEntitiesAfterTransfer;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

# One-word named entities should have their t-lemma capitalized,
# so also the form should be already capitalized.
# The problem is in the translation dictionary where we have now, for example:
# america -> amerika
# but no America -> Amerika
# Therefore, temporarily also one-word N.E. are processed here.
# In some rare cases this leads to errors
# e.g. "Al-Káida" instead of "al-Káida" ("al" is an article).

# Person names also should have their lemmas capitalized,
# but its possible that morphology (TCzechT_to_TCzechA::Generate_wordforms)
# interprets the name wrong and generates lowercased form.

my $MAC_RE = qr/Ma?c|D[ei]/;

sub process_zone {
    my ( $self, $zone ) = @_;
    my %to_process;    # mapping: entity   -> number of t-nodes of this entity
    my %ent_map;       # mapping: anode_id -> entity

    # STEP 1: gather named entities
    my $t_root = $zone->get_ttree();
    foreach my $t_node ( $t_root->get_descendants() ) {
        my $src_t_node = $t_node->src_tnode        or next;
        my $src_n_node = $src_t_node->get_n_node() or next;
        my $e_type = $src_n_node->get_attr('ne_type');
        if ( defined $e_type && $e_type =~ /^[ipg]/ ) {
            while ( !$src_n_node->get_parent()->is_root() ) {
                $src_n_node = $src_n_node->get_parent();
            }
            $to_process{$src_n_node}++;
            my $a_id = $t_node->get_attr('a/lex.rf');
            $ent_map{$a_id} = $src_n_node if defined $a_id;
        }
    }

    # STEP 2: Capitalize first lexical a-nodes in named entities
    my $a_root = $zone->get_atree();
    A_NODE:
    foreach my $a_node ( $a_root->get_descendants( { ordered => 1 } ) ) {
        my ( $form, $pos, $lemma ) = $a_node->get_attrs(qw(form morphcat/pos lemma));

        #HACK: rus je druh švába
        if ( $lemma eq 'rus' ) {
            $a_node->set_form( ucfirst $form );
            next A_NODE;
        }

        my $n_node = $ent_map{ $a_node->id };
        next A_NODE if !defined $n_node || !$to_process{$n_node};

        # In Czech we don't capitalize adjectives
        # which are not part of more-word named entity
        next A_NODE if $to_process{$n_node} == 1 && $pos eq 'A';

        next A_NODE if $lemma =~ /^(pan|paní|slečna)$/;

        # Uppercase the first letter
        $form = ucfirst $form;

        # Mccarthy -> McCarthy (but don't change Mackie -> MacKie)
        if ( $n_node->get_attr('normalized_name') =~ /$MAC_RE\p{IsUpper}/ ) {
            $form =~ s/^($MAC_RE)(.)/$1.uc $2/e;
        }
        $a_node->set_form($form);

        # For all NE (except persons) capitalize only the first word
        if ( $n_node->get_attr('ne_type') =~ /^[^pP]/ ) {
            $to_process{$n_node} = 0;
        }
    }
    return;
}

1;

__END__

=over

=item Treex::Block::T2A::CS::CapitalizeNamedEntitiesAfterTransfer

Capitalize first word in named entities of type C<organization> and C<location>,
and all words with type C<person>.
This block expects presence of source language n-trees.

=back

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
