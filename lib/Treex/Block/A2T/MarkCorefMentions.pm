package Treex::Block::A2T::MarkCorefMentions;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => enum([qw/a t/]), default => 'a' );
has 'only_heads' => ( is => 'ro', isa => 'Bool', default => 1 );

has '_entities' => ( is => 'rw', isa => 'HashRef[Int]', default => sub {{}} );

# project only nodes that are not anaphors of grammatical coreference
#sub _is_coref_text_mention {
#    my ($tnode) = @_;
#    my @is_ante = ($tnode->get_referencing_nodes('coref_gram.rf'), $tnode->get_referencing_nodes('coref_text.rf'));
#    my @is_text_anaph = $tnode->get_coref_text_nodes();
#    my @is_gram_anaph = $tnode->get_coref_gram_nodes();
#    return ((@is_ante || @is_text_anaph) && !@is_gram_anaph);
#}

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(@ttrees);
    my $entity_idx = 1;
    foreach my $chain (@chains) {
        foreach my $node (@$chain) {
            $self->_entities->{$node->id} = $entity_idx;
        }
        $entity_idx++;
    }
};

sub process_tnode {
    my ($self, $tnode) = @_;

#    return if (!_is_coref_text_mention($tnode));
    my $entity_idx = $self->_entities->{$tnode->id};
    return if (!defined $entity_idx);

    
    my @mention_nodes;
# TODO what about discarding relative clauses
    if ($self->layer eq 'a') {
        my $alex = $tnode->get_lex_anode();
        if ($self->only_heads) {
            @mention_nodes = ( $alex );
        }
        else {
            @mention_nodes = $alex ? $alex->get_descendants({ordered => 1, add_self => 1}) : ();
        }
    }
    else {
        if ($self->only_heads) {
            @mention_nodes = ( $tnode );
        }
        else {
            @mention_nodes = $tnode->get_descendants({ordered => 1, add_self => 1});
        }
    }
    return if (!@mention_nodes);
    
    # the beginning of the mention
    push @{$mention_nodes[0]->wild->{coref_mention_start}}, $entity_idx;
    # the end of the mention
    push @{$mention_nodes[-1]->wild->{coref_mention_end}}, $entity_idx;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MarkCorefMentions

=head1 DESCRIPTION

This block determines the coreference mentions by setting the wild attributes
"coref_mention_start" and "coref_mention_end".

This block usually precedes Treex::Block::Write::SemEval2010, which prints out
the data in the format consumed by CoNLL coreference resolution scorer.

=head1 PARAMETERS

=over

=item C<layer>

Which layer is taken as a basis (default "a").

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
