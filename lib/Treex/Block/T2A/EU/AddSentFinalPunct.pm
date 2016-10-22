package Treex::Block::T2A::EU::AddSentFinalPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSentFinalPunct';

override '_ends_with_clause_in_quotes' => sub {
    my ( $self, $last_token ) = @_;
    my ( $open_punct, $close_punct ) = ( $self->open_punct, $self->close_punct );
    
    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddSentFinalPunct

=head1 DESCRIPTION

Override '_ends_with_clause_in_quotes'

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
