package Treex::Block::A2A::CS::FixGenitive;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( $g->{'pos'} eq 'N' &&
        $d->{'pos'} eq 'N' && $d->{'case'} eq '2' &&
        $dep->precedes($gov) &&
        # do not fix if too far apart
        $gov->ord - $dep->ord < 3 &&
        # podle Petra Kuchaře -> podle Kuchaře Petra: don't fix!
        !$self->isName($gov)
        # TODO:
        # maybe also use: form ne lc(form) && ord != 1
    ) {
        $self->switch_nodes($dep, $gov, "Genitive move" );
    }

}

# TODO move this method into FixAgreement
# Rossuma robot -> robot Rossuma
sub switch_nodes {
    my ($self, $left_node, $right_node) = @_;

    $self->logfix1( $left_node );
    $left_node->set_parent($right_node);

    # do not move nonprojective nodes
    my @nonprojdescs = grep {$_->is_nonprojective} $left_node->get_descendants();
    foreach my $desc (@nonprojdescs) {
        $desc->set_parent($left_node->parent);
    }

    # TODO with children? is this the default?
    $self->shift_subtree_after_node(
        $left_node, $right_node
    );
    $self->logfix2($left_node);

    return ;
}



1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixGenitive

=head1 DESCRIPTION

the genitive (possessor) is moved after the parent noun (possessee)
("Rossuma robot" -> "robot Rossuma")

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
