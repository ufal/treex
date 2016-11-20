package Treex::Block::T2T::CS2CS::MarkClauseHeads;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkClauseHeads';

override 'is_clause_head' => sub {
    my ( $self, $t_node ) = @_;
    return 1 if ( $t_node->formeme =~ /^v:(.*\+)?(fin|rc)$/ );
    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2CS::MarkClauseHeads

=head1 DESCRIPTION

T-nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

This implementation uses formemes to find finite verb forms.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

