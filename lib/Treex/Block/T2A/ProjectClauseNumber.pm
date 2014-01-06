package Treex::Block::T2A::ProjectClauseNumber;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $clause_number = $t_node->clause_number;
    my $parent_clause_number = $t_node->get_parent->clause_number // $clause_number;

    if ( defined $clause_number ) {
        foreach my $a_node ( $t_node->get_anodes ) {

            # check if AddSubconjs has marked this node as an expletive
            # to be moved to the parent clause.
            if ( $a_node->wild->{upper_clause} ) {
                $a_node->set_clause_number($parent_clause_number);
            }
            else {
                $a_node->set_clause_number($clause_number);
            }
        }
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ProjectClauseNumber

=head1 DESCRIPTION

Number coindexing of finite verb clauses is projected from t-tree to a-tree.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
