package Treex::Block::Print::WordOrderStats;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my @labels = map { $self->label_of($_) } $anode->get_children( { add_self => 1, ordered => 1 } );
    print $self->label_of($anode) . ":\t" . join(' ', @labels) . "\n";
    return;
}

sub label_of {
    my ($self, $node) = @_;
    return 'V' if $node->tag =~ /^V/; 
    return $node->afun || $node->conll_deprel || 'NO';
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::WordOrderStats - relative ordering of children and its parent

=head1 DESCRIPTION

For each node, one line is printed
which contains the node's label, tab and labels of its children and the node.
The label is "V" for verbs and C<afun> or C<conll/deprel> otherwise. 


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
