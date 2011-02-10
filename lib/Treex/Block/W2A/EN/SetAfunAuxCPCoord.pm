package Treex::Block::W2A::EN::SetAfunAuxCPCoord;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => (default => 'en');

use Readonly;

sub process_atree {
    my ( $self, $a_root ) = @_;

    # 0) Get all nodes with empty afun (so leave already filled values intact)
    my @all_nodes = grep { !$_->afun } $a_root->get_descendants();

    # 1) Fill Coord (coordinating conjunctions).
    foreach my $node (@all_nodes) {
        if ( is_coord($node) ) { $node->set_afun( 'Coord' ); }
    }

    # Now we can use effective children (without diving), since Coord is filled.
    # 2) Fill AuxC (subord. conjunctions) and AuxP (prepositions).
    foreach my $node ( grep { !$_->afun } @all_nodes ) {
        my $auxCP_afun = get_AuxCP_afun($node) or next;
        $node->set_afun( $auxCP_afun );

        # "No Aux[CP] node can have is_memeber -> delegate it to the child"
        # - This is PDT style of is_member with its pros and cons,
        #   but we choose to not adopt this style in TectoMT.
        #if ( $node->get_attr('is_member') ) {
        #    $node->set_attr( 'is_member', 0 );
        #    my @children = $node->get_children();
        #    foreach my $child (@children) {
        #        $child->set_attr( 'is_member', 1 );
        #    }
        #}
    }

    return 1;
}

sub is_coord {
    my ($node) = @_;
    return any { $_->is_member } $node->get_children();
}

my $NOUN_REGEX = qr/^(NN|PRP|CD$|WP$|WDT$|DT$)/;

sub get_AuxCP_afun {
    my ($node) = @_;

    # Postposition "ago" has usually tag=RB (adverb), not IN.
    # So let's handle it separately.
    return 'AuxP' if $node->lemma eq 'ago';

    my @echildren      = $node->get_echildren();
    my $tag            = $node->tag;
    my $has_verb_child = any { $_->tag =~ /^V/ } @echildren;
    my $has_noun_child = any { $_->tag =~ $NOUN_REGEX } @echildren;

    # "to" can be either a preposition(AuxP) or an infinitive marker(AuxV)
    # AuxP are usually above nouns, AuxV under verbs.
    # However, multiword preps: "down to(tag=TO, parent=down) 20(parent=down)"
    if ( $tag eq 'TO' ) {
        my ($eparent) = $node->get_eparents();
        my $ep_tag = $eparent->tag || '_root';
        if ( !@echildren ) {
            return 'AuxV' if $ep_tag =~ /^V/;
            return 'AuxP' if $ep_tag =~ /^IN/;
            return 'AuxP';
        }
        return 'AuxP' if $has_noun_child;
        return 'AuxP';
    }
    if ( $tag eq 'IN' ) {
        return 'AuxC' if $has_verb_child;    # IN + verb e.g. "I see it as.AuxC holding steady."
        return 'AuxP' if $has_noun_child;    # IN + noun e.g. "in.AuxP a car"
        return 'AuxC' if !@echildren;        # e.g. "I said that.AuxC it's enough."
        ## "The difference between(tag=IN) expensive(tag=JJ, parent=between) and cheap is ..."
        return 'AuxP';                       # just a guess TODO try a list of lemmas
    }

    return 'AuxC' if $has_verb_child and $node->lemma eq "when";

    return;
}

1;

__END__

=over

=item Treex::Block::W2A::EN::SetAfunAuxCPCoord

Fill those afun attributes that are needed for using effective children
and effective parents.
I.e. C<Coord> (coordinating conjunction), C<AuxC> (subordination conjunction)
and C<AuxP> (preposition). Also C<AuxV> is used for word "to"
serving as an infinitive marker.

Only primary prepositions are marked in this block,
for multiword prepositions (secondary) you can use
L<SEnglishM_to_SEnglishA::Fix_multiword_prep_and_conj>. 
This block doesn't change already filled afun values.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
