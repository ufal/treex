package Treex::Block::Project::CoreferenceToALayer;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has '_entities' => ( is => 'rw', isa => 'HashRef[Int]', default => sub {{}} );

# project only nodes that are not anaphors of grammatical coreference
sub _is_coref_text_mention {
    my ($tnode) = @_;
    my @is_ante = ($tnode->get_referencing_nodes('coref_gram.rf'), $tnode->get_referencing_nodes('coref_text.rf'));
    my @is_text_anaph = $tnode->get_coref_text_nodes();
    my @is_gram_anaph = $tnode->get_coref_gram_nodes();
    return ((@is_ante || @is_text_anaph) && !@is_gram_anaph);
}

# this could be parametrized to discard relative clauses from mentions
sub _get_mention_anodes {
    my ($tnode) = @_;

    my $alex = $tnode->get_lex_anode();
    return () if (!defined $alex);

    my @mention_anodes = $alex->get_descendants({ordered => 1, add_self => 1});
    return @mention_anodes;
}

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

    return if (!_is_coref_text_mention($tnode));

    my @mention_anodes = _get_mention_anodes($tnode);
    return if (!@mention_anodes);
    
    my $entity_idx = $self->_entities->{$tnode->id};

    # the beginning of the mention
    push @{$mention_anodes[0]->wild->{coref_mention_start}}, $entity_idx;
    # the end of the mention
    push @{$mention_anodes[-1]->wild->{coref_mention_end}}, $entity_idx;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Project::CoreferenceToALayer

=head1 DESCRIPTION

Project coreference links from the t-layer onto the a-layer to get the 'mention' representation traditionally used in English CR.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
