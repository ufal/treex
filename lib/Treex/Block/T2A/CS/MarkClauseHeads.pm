package Treex::Block::T2A::CS::MarkClauseHeads;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # designed to work with and without diathesis/relative clauses in formemes
    if ( $t_node->formeme =~ m/^v:.*(fin|act|[ar]pass|rc)$/ ) {
        $t_node->set_is_clause_head(1);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::MarkClauseHeads

=head1 DESCRIPTION

Mark the heads of finite verb clauses, recognizing them according to their formeme value (which must
correspond to a finite verb).

This is needed for the golden PDT trees only, as the automatic analysis would have already marked the clause heads.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
