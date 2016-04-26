package Treex::Block::Coref::PrettyPrint::LabelKey;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has '_id_to_entity_id' => (is => 'rw', isa => 'HashRef');
has '_entity_id_to_mentions' => (is => 'rw', isa => 'HashRef');

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    my @entities = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees);
    my %entity_id_to_mentions = ();
    my %id_to_entity_id = ();
    my $i = 1;
    foreach my $entity (@entities) {
        $entity_id_to_mentions{$i} = $entity;
        foreach my $mention (@$entity) {
            $id_to_entity_id{$mention->id} = $i;
        }
        $i++;
    }
    $self->_set_id_to_entity_id(\%id_to_entity_id);
    $self->_set_entity_id_to_mentions(\%entity_id_to_mentions);
};

sub process_tnode {
    my ($self, $tnode) = @_;
    my $entity_id = $self->_id_to_entity_id->{$tnode->id};
    return if (!defined $entity_id);
    my $entity = $self->_entity_id_to_mentions->{$entity_id};
    $_->wild->{coref_diag}{key_ante_for}{$tnode->id} = 1 foreach (@$entity);
}

1;
