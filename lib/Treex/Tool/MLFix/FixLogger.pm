package Treex::Tool::MLFix::FixLogger;
use Moose;
use Treex::Core::Common;
use utf8;

my $fix_zone   = undef;
my $fix_msg    = '';
my $fix_node   = '';
my $fix_before = '';
my $fix_after  = '';

#has fix_msg => ( 
#    is  => 'rw',
#    isa => 'Str',
#    default => ''
#);

sub logfix1 {
    my ( $self, $child, $msg ) = @_;

    $fix_zone = $child->get_bundle->get_or_create_zone(
        $child->language, 'FIXLOG' );
    $fix_msg = $msg;
    $child->id =~ /-s([0-9]+)-n([0-9]+)$/;
    $fix_node = "sentence $1 node $2";
    $fix_before = $self->_get_edge_info($child);

    return;
}

sub logfix2 {
    my ( $self, $child ) = @_;

    $fix_after = $self->_get_edge_info($child);
    if ($fix_before ne $fix_after) {
        $fix_zone->set_sentence(
            ($fix_zone->sentence // '')
            . "{$fix_msg: $fix_before -> $fix_after} "
        );
        log_info("FIXLOG: $fix_msg on $fix_node: $fix_before -> $fix_after");
    }

    return;
}

sub _get_edge_info() {
    my ( $self, $child ) = @_;

    if (!defined $child || !blessed $child
        || $child->isa('Treex::Core::Node::Deleted')
    ) {
        return '(removal)';
    } else {
        my ($parent) = $child->get_eparents({
            or_topological => 1,
            ignore_incorrect_tree_structure => 1
        });
        if ( $parent->is_root ) {
            return $self->_get_node_info($child);
        } elsif ( $parent->precedes($child) ) {
            return $self->_get_node_info($parent) . ' '
                . $self->_get_node_info($child);
        } else {
            return $self->_get_node_info($child) . ' '
                . $self->_get_node_info($parent);
        }
    }
}

sub _get_node_info {
    my ($self, $node) = @_;

    #return $node->form . '[' . $node->tag . ']' . $node->afun;
    return $node->form . '[' . $node->tag . ']';
}

1;

=head1 NAME

Treex::Tool::MLFix::FixLogger -- a role that provides logging for MLFix

=head1 METHODS

=over

=item $self->fixlog1($child, $msg)

=item $self->fixlog2($child)

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
