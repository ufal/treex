package SEnglishA_to_SEnglishT::Mark_auxiliary_nodes;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub aux_to_parent {
    my ($a_node) = shift;
    my $tag      = $a_node->tag;
    my $afun     = $a_node->afun;
    my $lemma    = $a_node->lemma;
    my $document = $a_node->get_document();
    my @nonterminals = ( $a_node->get_attr('p/nonterminals.rf') ) ? ( grep {$_} map { $document->get_node_by_id($_) } @{ $a_node->get_attr('p/nonterminals.rf') } ) : ();
    no warnings qw(uninitialized);
    return (
        $lemma =~ /^(an?|the)$/
            or

            #	  ($tag =~ /^(RP|EX|POS|-NONE-|\.|\,|''|``|-LRB-|-RRB-)$/ and (not defined $afun or $afun!~/Apos|Coord/)) or

            # pokus s ponechanim uvozovek jako t-uzlu:
            ( $tag =~ /^(RP|EX|POS|-NONE-|\.|\,|-LRB-|-RRB-)$/ and ( not defined $afun or $afun !~ /Apos|Coord/ ) ) or

            # dirty: verb which is other verb's left child is likely to be auxiliary (unless it is an independent sentence S or SBAR)
            (
            $tag =~ /^(V|MD)/
            and (
                $a_node->get_parent->tag =~ /^V/
                or
                $a_node->get_parent->tag eq "CC" and not $a_node->is_member
            )    # !!! koordinace zatim nahackovana
            and $a_node->get_attr('ord') < $a_node->get_parent->get_attr('ord')
            and
            ( not grep { $_->get_attr('phrase') =~ /^S/ } @nonterminals )
            and ( not grep { $_->get_attr('ord') < $a_node->get_attr('ord') } $a_node->get_children )    # tohle by melo pomoct, kdyz neni k dispozici SEnglishP
            ) or

            ( $lemma =~ /^(more|most)/ and $a_node->get_parent->tag =~ /^JJ|RB/ )                        # nahradit efektivnim rodicem!
            or
            ( grep { $_->get_attr('phrase') eq "PRT" } @nonterminals )                                   # particles (look_up)
                                                                                                         #	  or ($tag eq "IN" and $a_node->get_parent->tag eq "IN")  # kvuli because_of # nyni reseno jinak - pomoci AuxC
                                                                                                         #	  or ($lemma eq "as" and $a_node->get_parent->form eq "well") # kvuli as_well_as
            or ( $a_node->afun eq 'AuxC' and $a_node->get_parent->afun =~ /AuxC|Coord/ )
            or ( $a_node->conll_deprel eq 'VMOD' and $tag eq 'IN' and $a_node->get_parent->tag =~ /^V/ )    # Since, until apod.
    );
}

sub aux_to_child {
    my ($a_node) = shift;
    my $tag = $a_node->tag;

    #  my $relative_that; # pro pripad, ze bylo vztazne zajmeno 'that' chybne tagovane jako spojka
    #  if ($a_node->form eq "that") {
    #    my $document = $a_node->get_document;
    #    my @nonterminals = ($a_node->get_attr('p/nonterminals.rf'))?(grep {$_} map {$document->get_node_by_id($_)} @{$a_node->get_attr('p/nonterminals.rf')}):();
    #    $relative_that = grep {$_->get_attr('phrase') =~ /^WH/} @nonterminals;
    #  }
    my @to_children = grep { $_->form eq "to" } $a_node->get_children;
    return (
        $tag eq "TO"
            or
            ( $tag          eq "IN" )  or
            ( $a_node->form eq "ago" ) or
            ( ( $a_node->afun || "" ) eq "AuxC" ) or
            ( lc( $a_node->form ) eq "according" and @to_children )

            #                    or                ($a_node->lemma eq "have" and @to_children and grep {$_->tag eq "VB"} $to_children[0]->get_children) #oznacit "HAVE to infinitiv" jako aux_to_child
    );
}

sub parent_is_aux {
    my ($a_node) = @_;
    my $a_parent = $a_node->get_parent();
    return 0 if !$a_parent || $a_parent->is_root();

    my $parent_lemma = $a_parent->lemma;
    my $tag          = $a_node->tag;
    my $after_parent = $a_parent->precedes($a_node);

    return 1 if $parent_lemma eq 'be' && $tag eq 'VBN' && $after_parent;

    return 1 if $tag =~ /^V/ && $after_parent &&
            $parent_lemma =~ /^(can|cannot|must|may|might|should|would|could|do|will|shall)$/;

    return 1 if $tag eq 'TO' && $parent_lemma eq 'have';
    return 0;
}

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $a_aux_root = $bundle->get_tree('SEnglishA');
        my ($a_root) = $a_aux_root->get_children();    # there should be always only one child (??? final punctuation?)

        next if !defined $a_root;    # gracefully handle bad data

        foreach my $a_node ( $a_root, $a_root->get_descendants ) {
            $a_node->set_attr( 'is_aux_to_child',  ( aux_to_child($a_node)  ? "1" : undef ) );
            $a_node->set_attr( 'is_aux_to_parent', ( aux_to_parent($a_node) ? "1" : undef ) );
            $a_node->set_attr( 'parent_is_aux',    ( parent_is_aux($a_node) ? "1" : undef ) );
            if ( $a_node->get_attr('is_aux_to_child') and $a_node->get_attr('is_aux_to_parent') ) {
                $a_node->set_attr( 'is_aux_to_child', undef );    # kvuli as well as
            }
        }
    }

}

1;

__END__

=over

=item SEnglishA_to_SEnglishT::Mark_auxiliary_nodes;

In SEnglishA trees it mark nodes which are auxiliary
by filling node attributes aux_to_parent (for nodes which are to be merged
with their autosemantic parents during the conversion to t-layer)
and aux_to_child (for nodes which go to their autsemantic children).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
