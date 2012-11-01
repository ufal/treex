package Treex::Block::W2A::TagStanford;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::Stanford;
extends 'Treex::Block::W2A::Tag';

has model => ( is => 'ro', isa => 'Str', required => 1 );

sub _build_tagger{
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    return Treex::Tool::Tagger::Stanford->new($self->_args);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagStanford

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::Stanford> (a wrapper for the Stanford tagger) with 
the given C<model>,  feeds it with all the input tokenized sentences, and fills the C<tag> 
parameter of all a-nodes with the tagger output. 

=head1 PARAMETERS

=over

=item C<model>

The path to the tagger model within the shared directory. This parameter is required.

=back

=head1 SEE ALSO

L<Treex::Block::W2A::EN::TagStanford>, L<Treex::Block::W2A::DE::TagStanford>, L<Treex::Block::W2A::FR::TagStanford>

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
