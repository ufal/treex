package Treex::Block::A2T::EN::MarkReferentialIt;

use Moose;
use Treex::Tool::Coreference::NADA;

extends 'Treex::Core::Block';

has '_resolver' => (
    is => 'ro',
    isa => 'Treex::Tool::Coreference::NADA',
    required => 1,
    builder => '_build_resolver',
);

sub _build_resolver {
    my ($self) = @_;
    return Treex::Tool::Coreference::NADA->new();
}

sub process_zone {
    my ($self, $zone) = @_;

    my $atree = $zone->get_atree;
    my @ids = map {$_->id} $atree->get_descendants({ordered => 1});
    my @words = map {$_->form} $atree->get_descendants({ordered => 1});

    
    my $result = $self->_resolver->process_sentence(@words);
    my %it_ref_probs = map {$ids[$_] => $result->{$_}} keys %$result;

    my $ttree = $zone->get_ttree;
    foreach my $t_node ($ttree->get_descendants) {
        my @anode_ids = map {$_->id} $t_node->get_anodes;
        my ($it_id) = grep {defined $it_ref_probs{$_}} @anode_ids;
        if (defined $it_id) {
#            print STDERR "IT_ID: $it_id " . $it_ref_probs{$it_id} . "\n";
            $t_node->wild->{'referential'} = $it_ref_probs{$it_id} > 0.5 ? 1 : 0;
        }
    }
}

1;

# TODO POD
