package Treex::Block::Print::ReferentialItData;

use Moose;
use Treex::Core::Common;

use List::MoreUtils qw/any/;
use Treex::Tool::ReferentialIt::Utils;
use Treex::Tool::ReferentialIt::Features;

extends 'Treex::Core::Block';

# TODO this should be written against an interface (not an implementation)
has '_feat_extractor' => (
    is => 'ro',
    isa => 'Treex::Tool::ReferentialIt::Features',
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

sub _build_feat_extractor {
    my ($self) = @_;
    return Treex::Tool::ReferentialIt::Features->new();
}


sub _print_instance {
    my ($self, $class, $instance, $feat_names) = @_;

    my @feat_values = map {$instance->{$_}} @{$feat_names};
    
    print STDOUT join $self->feature_sep, ($class, @feat_values);
    print STDOUT "\n";
}

sub _get_referencing_aligned_node {
    my ($node, $type) = @_;
    my @aligned = $node->get_referencing_nodes('alignment');
    my @ref_nodes = grep {any {$_ == $node} $_->get_aligned_nodes_of_type($type)} @aligned;
    return @ref_nodes;
}

# TODO this has to be solved in an easier way
sub _get_ref_tnode {
    my ($self, $src_tnode) = @_;
    
    # try alignment on t-layer
    my ($ref_tnode) = _get_referencing_aligned_node( $src_tnode, 'monolingual' );

    if (!defined $ref_tnode) {
        my $src_anode = $src_tnode->get_lex_anode;
        if (defined $src_anode) {
            my ($ref_anode) = _get_referencing_aligned_node( $src_anode, 'monolingual' );
            ($ref_tnode) = grep {defined $_} 
                map { $ref_anode->get_referencing_nodes($_) } ('a/lex.rf', 'a/aux.rf');
        }
    }
    
    return $ref_tnode;
}

sub _get_true_class {
    my ($self, $t_node) = @_;
    my $ref_tnode = $self->_get_ref_tnode( $t_node );
    if (!defined $ref_tnode) {
        print STDERR "TNODE: " . $t_node->id;
        print STDERR ", " . $t_node->get_document->full_filename . "\n";
    }
    my $it_type = Treex::Tool::ReferentialIt::Utils::get_it_type( $ref_tnode, $self->ref_np_only );
    my $class = Treex::Tool::ReferentialIt::Utils::get_class_for_it_type( $it_type, $self->exo_as_pleo );
    return $class;
}

before 'process_zone' => sub {
    my ($self, $zone) = @_;
    
    $self->_feat_extractor->init_zone_features( $zone );
};

sub process_tnode {
    my ($self, $t_node) = @_;
    
    if (Treex::Tool::ReferentialIt::Utils::is_it($t_node)) {
        my $instance = $self->_feat_extractor->create_instance( $t_node );
        my $class = $self->_get_true_class( $t_node );


#    use Data::Dumper;
#    print STDERR Dumper($self->_feat_extractor->feature_names, $instance);
        $self->_print_instance( $class, $instance, $self->_feat_extractor->feature_names );
    }
}

1;
