package Treex::Block::Coref::PrettyPrint::LabelKey;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '_id_to_entity_id' => (is => 'rw', isa => 'HashRef');
has '_entity_id_to_mentions' => (is => 'rw', isa => 'HashRef');

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my %entity_id_to_mentions = ();
    my %id_to_entity_id = ();

    my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    foreach my $ttree (@ttrees) {
        foreach my $tnode ($ttree->get_descendants) {
            my $entity_id = $tnode->wild->{gold_coref_entity};
            if (defined $entity_id) {
                $entity_id =~ s/\?$//;
                $id_to_entity_id{$tnode->id} = $entity_id;
                if (defined $entity_id_to_mentions{$entity_id}) {
                    push @{$entity_id_to_mentions{$entity_id}}, $tnode;
                }
                else {
                    $entity_id_to_mentions{$entity_id} = [ $tnode ];
                }
            }
        }
    }
    $self->_set_id_to_entity_id(\%id_to_entity_id);
    $self->_set_entity_id_to_mentions(\%entity_id_to_mentions);
};

sub process_tnode {
    my ($self, $tnode) = @_;
    $tnode->wild->{coref_diag}{removed_or_merged} = 1 if (($tnode->wild->{gold_coref_entity} // "") =~ /\?$/);
    my $entity_id = $self->_id_to_entity_id->{$tnode->id};
    return if (!defined $entity_id);
    my $entity = $self->_entity_id_to_mentions->{$entity_id};
    $_->wild->{coref_diag}{key_ante_for}{$tnode->id} = 1 foreach (@$entity);
}

1;

=head1 NAME

Treex::Block::Coref::PrettyPrint::LabelKey

=head1 DESCRIPTION

An auxiliary block for pretty printing of corefence
resolution results.
The block sets for every coreferential node all key mentions 
belonging to the same entity into a wild attribute.

This block must be run before Coref::PrettyPrint.
The Coref::ProjectCorefEntities block must berun before this block.

=head1 SYNOPSIS

    treex -L$lang -Ssrc
        Read::Treex from=sample.streex
        Coref::PrettyPrint::LabelSys node_types="$category"
        Coref::ProjectCorefEntities selector=ref to_selector=src to_language=$lang
        Coref::PrettyPrint::LabelKey
        Coref::PrettyPrint

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
