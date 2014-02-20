package Treex::Block::Depfix::CollectMonolingual;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has '+extension' => (default => '.tsv');
has '+stem_suffix' => (default => '_stats');
has '+compress' => (default => '1');

#has config_file => ( is => 'rw', isa => 'Str', default => '' );

#has fields => ( is => 'rw', isa => 'Str', default =>
#    'child_form,parent_form,edge_direction,child_lchildno,child_rchildno'
#);

#has fields_ar => ( is => 'rw', lazy => 1, builder => '_build_fields_ar' );
#
#sub _build_fields_ar {
#    my ($self) = @_;
#
#    if ( $self->config_file ne '' ) {
#        use YAML::Tiny;
#        my $config = YAML::Tiny->new;
#        $config = YAML::Tiny->read( $self->config_file );
#        return $config->[0]->{fields};
#    } else {
#        my @arr = split /,/, $self->fields;
#        return \@arr;
#    }
#}
#
#use Treex::Tool::Depfix::NodeInfoGetter;
#
#has node_info_getter => ( is => 'rw', builder => '_build_node_info_getter' );
#
#sub _build_node_info_getter {
#    return Treex::Tool::Depfix::NodeInfoGetter->new();
#}
#
#has include_unchanged => ( is => 'rw', isa => 'Bool', default => 1 );

# I need the root as well, therefore the override of process_atree()
sub process_atree {
    my ($self, $root) = @_;

    my @nodes = $root->get_descendants({add_self=>1});
    foreach my $node (@nodes) {
        $self->process_anode($node);
    }

    return;
}

sub process_anode {
    my ($self, $parent) = @_;

    my $parent_form = $parent->get_attr('form') // '';
    my @lchild_forms = map { $_->form } $parent->get_children({preceding_only=>1});
    $self->print_forms('/', $parent_form, @lchild_forms);
    my @rchild_forms = map { $_->form } $parent->get_children({following_only=>1});
    $self->print_forms('\\', $parent_form, @rchild_forms);
}

sub print_forms {
    my $self = shift;
    my $edge_direction = shift;
    my $parent_form = shift;
    my @forms = @_;
    push @forms, '';

    my $last_form = '';
    foreach my $form (@forms) {
        print { $self->_file_handle() } (join "\t",
            ($edge_direction, $parent_form, $last_form, $form)
        ) . "\n";
        $last_form = $form;
    }

    return ;
}

1;

=head1 NAME

Treex::Block::Depfix::CollectMonolingual

=head1 DESCRIPTION

Collects and prints a list of fields for each child node in the tree.

The fields to be captured can be configured either with a comma delimited list
in C<fields>, or by a config file in C<config_file> (which has priority).
See C<sample_config.yaml> in the C<Treex::Block::Depfix> directory for a sample.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

