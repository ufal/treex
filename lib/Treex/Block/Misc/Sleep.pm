package Treex::Block::Misc::Sleep;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'start'     => ( is => 'ro', isa => 'Int', default  => 10 );
has 'document'     => ( is => 'ro', isa => 'Int', default  => 10 );

sub BUILD {
  my ($self) = @_;
  return;
}

sub process_start {

    my $self = shift;

    my $sleep_time = int(rand($self->{start}));
    log_warn("process_start - sleeping for $sleep_time - begin");
    sleep($sleep_time);
    log_info("process_start - sleeping for $sleep_time - end");

    $self->SUPER::process_start();

    return;
}


sub process_document{
  my ($self, $document ) = @_;

    my $sleep_time = int(rand($self->{document}));
    log_warn("process_document - sleeping for $sleep_time - begin");
    sleep($sleep_time);
    log_info("process_document - sleeping for $sleep_time - end");

  return;

}

1;

=head1 NAME

Treex::Block::Misc::Sleep;

=head1 DESCRIPTION

This block sleeps random time in functions process_start and process_document.

=head1 PARAMETERS

=over

=item C<start>

The maximum amount of time spent in process_start.

=item C<document>

The maximum amount of time spent in process_document.

=head1 AUTHOR

Martin Majlis <majlis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
