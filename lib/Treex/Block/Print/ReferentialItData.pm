package Treex::Block::Print::CorefData;

use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;
use Treex::Tool::ReferentialIt::Utils;

# TODO this should be written against an interface (not an implementation)
has '_feat_extractor' => (
    is => 'ro',
    isa => 'Treex::Tool::ReferentialIt::Features',
    lazy => 1,
    builder => '_build_feat_extractor',
);

has 'feature_sep' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => "\t",
);

has 'exo_as_pleo' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
    documentation => "Treat non-anaphoric (e.g. exophoric) 'it' as pleonastic",
);

has 'ref_np_only' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
    documentation => "If enabled, 'it' is considere referential only if its antecedent is a semantic noun, otherwise all antecedents are permitted",
);


sub _print_instance {
    my ($self, $class, $instance, $feat_names) = @_;

    my @feat_values = map {$instance->{$_}} @{$feat_names};
    
    print STDOUT join $self->feature_sep, ($class, @feat_values);
    print STDOUT "\n";
}

# TODO this has to be solved in an easier way
sub _get_ref_tnode {
    my ($self, $t_node_src) = @_;
    my @aligned = $t_node_src->get_referencing_nodes('alignment');
    my ($ref_tnode) = grep {any {$_ == $t_node_src} $_->get_aligned_nodes_of_type('monolingual')} @aligned;
    return $ref_tnode;
}

sub _get_true_class {
    my ($self, $t_node) = @_;
    my $ref_tnode = $self->_get_ref_tnode( $t_node );
    my $it_type = Treex::Tool::ReferentialIt::Utils::get_it_type( $ref_tnode, $self->ref_np_only );
    my $class = Treex::Tool::ReferentialIt::Utils::get_class_for_it_type( $it_type, $self->exo_as_pleo );
    return $class;
}

sub process_tnode {
    my ($self, $t_node) = @_;
    
    if (Treex::Tool::ReferentialIt::Utils::is_it($t_node)) {
        my $instance = $self->_feat_extractor->create_instance( $t_node );
        my $class = $self->_get_true_class( $t_node );

        $self->_print_instance( $class, $instance, $self->_feat_extractor->feature_names );
    }
}

1;
