package Treex::Block::W2A::LabelMIRA;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::W2A::AnalysisWithAlignedTrees';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Labeller;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Node;

use Treex::Core::Resource qw(require_file_from_share);

# Look for model under "model_dir/model_name.model"
# and its config "model_dir/model_name.config".
# Absolute path is needed if not a model from share.
has 'model_from_share' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '1',
);

has 'model_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'conll_2007',
);

has 'model_dir' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'data/models/mst_perl_parser/en',
);

has labeller => (
    is       => 'ro',
    isa      => 'Treex::Tool::Parser::MSTperl::Labeller',
    init_arg => undef,
    builder  => '_build_labeller',
    lazy     => 1,
);

sub _build_labeller {
    my ($self) = @_;

    my $base_name = $self->model_dir . '/' . $self->model_name;

    my $config_file = (
        $self->model_from_share
        ?
            require_file_from_share( "$base_name.config", ref($self) )
        :
            "$base_name.config"
    );
    my $config = Treex::Tool::Parser::MSTperl::Config->new(
        config_file => $config_file,
        training    => 0,
        DEBUG       => 0,
    );

    my $labeller = Treex::Tool::Parser::MSTperl::Labeller->new(
        config => $config,
    );
    my $model_file = (
        $self->model_from_share
        ?
            require_file_from_share( "$base_name.lmodel", ref($self) )
        :
            "$base_name.lmodel"
    );
    $labeller->load_model($model_file);

    return $labeller;
}

# TODO process_start
sub BUILD {
    my $self = shift;

    # enforce labeller initialization
    $self->labeller;

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $a_root = $zone->get_atree;

    # get alignment mapping
    my $alignment_hash = $self->_get_alignment_hash( $zone->get_bundle() );

    # convert from treex data structures to labeller data structures
    my $sentence = $self->_get_sentence( $alignment_hash, $a_root );

    # run the labeller
    my @node_labels = @{ $self->labeller->label_sentence($sentence) };

    # set nodes' labels
    foreach my $a_node ( $a_root->get_descendants( { ordered => 1 } ) ) {
        my $label = shift @node_labels;
        $a_node->set_attr( 'afun', $label );
        # $a_node->set_is_member(0);
    }

    return;
}

# convert from treex data structures to labeller data structures
sub _get_sentence {
    my ( $self, $alignment_hash, $a_root ) = @_;

    # create objects of class Treex::Tool::Parser::MSTperl::Node
    my @nodes;
    foreach my $a_node ( $a_root->get_descendants( { ordered => 1 } ) ) {

        # get field values
        my @field_values;
        foreach my $field_name ( @{ $self->labeller->config->field_names } ) {
            my $field_value = $self->_get_field_value(
                $a_node, $field_name, $alignment_hash
            );
            if ( defined $field_value ) {
                push @field_values, $field_value;
            } else {
                push @field_values, '';
            }
        }

        # create Node object
        my $node = Treex::Tool::Parser::MSTperl::Node->new(
            fields => \@field_values,
            config => $self->labeller->config
        );

        # store the Node object
        push @nodes, $node;
    }

    # create object of class Treex::Tool::Parser::MSTperl::Sentence
    my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new(
        nodes  => \@nodes,
        config => $self->labeller->config
    );

    return $sentence;
}

sub get_coarse_grained_tag {
    log_warn 'get_coarse_grained_tag should be implemented in derived classes';
    my ( $self, $tag ) = @_;

    return substr( $tag, 0, 1 );
}
1;

__END__

=head1 NAME

Treex::Block::W2A::LabelMIRA

=head1 DECRIPTION

MIRA Labeller is an implementation of a dependency tree labeller
created mainly as a second stage to the MST Perl Parser
described by R. McDonald
(see L<Treex::Block::W2A::ParseMSTperl>),
but it can be used with any analytical trees.
It takes an analytical tree as input and assigns labels (afuns)
to its nodes.

Settings are provided via a config file accompanying the model file.
The script loads the model C<model_dir/model_name.lmodel>
and its config <model_dir/model_name.config>.
The default is the English model
C<share/data/models/labeller_mira/en/conll_2007.lmodel>
(and C<conll_2007.config> in the same directory).

TODO train an English model once the labeller is more or less finished.

It is not sensible to change the config file unless you decide to train
your own model.
However if you B<do> decide to train your own model, then see
L<Treex::Tool::Parser::MSTperl::Config>.

TODO: provide a treex interface for the trainer?

=head1 SEE ALSO

L<Treex::Block::W2A::ParseMSTperl> the MST Perl Parser

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
