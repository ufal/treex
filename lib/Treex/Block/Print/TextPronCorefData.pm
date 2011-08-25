package Treex::Block::Print::TextPronCorefData;
use Treex::Core::Common;
use MooseX::SemiAffordanceAccessor;

# TODO this is weird, they should rather have a common ancestor class or role
extends 'Treex::Block::A2T::CS::MarkTextPronCoref';

has 'y_feat_name' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 'class',
);

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    builder     => '_build_feature_names',
);

sub _build_feature_names {
    my ($self) = @_;

    # TODO fill feature names
    my @names = qw//;
    return \@names;
}

sub _create_instances_strings {
    my ($self, $instances, $y_value) = @_;
    
    my @lines;
    foreach my $id (keys %{$instances}) {
        my $line = $self->y_feat_name . "=$y_value\t";
        my @cols = map {$_ . "=" . $instances->{$id}->{$_}} @{$self->feature_names};
        $line .= join "\t", @cols;
        push @lines, $line;
    }

    return @lines;
}

sub print_bundle {
    my ($self, $pos_instances, $neg_instances) = @_;

    my @pos_lines = $self->_create_instances_strings($pos_instances, 1);
    my @neg_lines = $self->_create_instances_strings($neg_instances, 0);
    
    print join "\n", ( @pos_lines, @neg_lines );
    print "\n";
}

override 'process_tnode' => sub {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    if ( _is_anaphoric($t_node) ) {

        # retrieve positive and negatve antecedent candidates separated from
        # each other
        my $acs = $self->_ante_cands_selector;
        my ($pos_cands, $neg_cands, $pos_ords, $neg_ords) 
            = $acs->get_pos_neg_candidates( $t_node );

        # instances is a reference to a hash in the form { id => instance }
        my $pos_instances 
            = $self->_create_instances( $t_node, $pos_cands, $pos_ords );
        my $neg_instances 
            = $self->_create_instances( $t_node, $neg_cands, $neg_ords );

        $self->print_bundle($pos_instances, $neg_instances);
    }
};
