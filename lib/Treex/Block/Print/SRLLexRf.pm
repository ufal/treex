package Treex::Block::Print::SRLLexRf;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $t_node_lexrf = $t_node->get_attr('a/lex.rf');
    return if not defined $t_node_lexrf;
    my $a_node = $t_node->get_lex_anode() or return;
    
    foreach my $child ($t_node->get_children) {
        my $child_lexrf = $child->get_attr('a/lex.rf');
        next if not defined $child_lexrf;
        my $child_a_node = $child->get_lex_anode() or next;
        print "$t_node_lexrf $child_lexrf ". $a_node->tag . " " . $child_a_node->tag . " " . $child->functor . "\n";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::SRLLexRf

=head1 DESCRIPTION

Prints semantic relations in the t-layer, one relation per line, in the format
"parent_lex_rf child_lex_rf parent_tag child_tag functor".

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
