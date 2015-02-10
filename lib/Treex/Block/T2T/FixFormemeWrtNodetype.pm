package Treex::Block::T2T::FixFormemeWrtNodetype;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;

    if ( $node->nodetype !~ /q?complex/) {
#	print $node->t_lemma."\t".$node->nodetype."\t".$node->formeme."\n";
	$node->set_formeme("x");
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::FixFormemeWrtNodetype - 'x' formeme assigned to all non-complex nodes

=head1 DESCRIPTION

Formemes other than "x" make sense only with complex nodes. However, the statistical formeme transfer
often assignes formemes such as "n:attr" e.g. to coordination/apposition nodes (nodetype="coap").
This block assigns the "x" formeme to all non-complex nodes.

TODO: what's the status of qcomplex (quasi complex, such as #Cor) nodes with respect to formemes?


=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
