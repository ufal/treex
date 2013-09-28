package Treex::Block::Misc::Crash;

use Moose;
use Treex::Core::Common;
use Moose::Util::TypeConstraints;

extends 'Treex::Core::Block';

subtype 'Prob',
      as 'Num',
      where { $_ >= 0 && $_ <= 1 },
      message { "The number you provided, $_, was not between 0 and 1." };


has 'build_undef'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'build_die'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'build_fatal'     => ( is => 'ro', isa => 'Prob', default  => 0 );

has 'start_undef'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'start_die'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'start_fatal'     => ( is => 'ro', isa => 'Prob', default  => 0 );

has 'document_undef'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'document_die'     => ( is => 'ro', isa => 'Prob', default  => 0 );
has 'document_fatal'     => ( is => 'ro', isa => 'Prob', default  => 0 );


sub BUILD {
    my ($self) = @_;
    $self->crash("build");
    return;
}

sub process_start {

    my $self = shift;

    $self->crash("start");

    return;
}

sub process_document{
    my ($self, $document ) = @_;

    $self->crash("document");

    return;
}

sub crash {
    my ($self, $label) = @_;
    my $prob = rand();

    if ( rand() < $self->{$label."_undef"} ) {
        crash_block_unknown_missing_function();
    } elsif ( rand() < $self->{$label."_die"} ) {
        die("CrashBlock :)");
    }  elsif ( rand() < $self->{$label."_fatal"} ) {
        log_fatal("CrashBlock :)");
    }

    return;
}


1;

=head1 NAME

Treex::Block::Misc::Sleep;

=head1 DESCRIPTION

This block crashes randomly during BUILD, process_stard, and process_document.

=head1 PARAMETERS

=over

=item C<build_undef>

Probability of crash inside BUILD function caused by calling undefined function.

=item C<build_die>

Probability of crash inside BUILD function caused by calling die.

=item C<build_fatal>

Probability of crash inside BUILD function caused by calling log_fatal.

=item C<start_undef>

Probability of crash inside process_start function caused by calling undefined function.

=item C<start_die>

Probability of crash inside process_start function caused by calling die.

=item C<start_fatal>

Probability of crash inside process_start function caused by calling log_fatal.

=item C<document_undef>

Probability of crash inside process_document function caused by calling undefined function.

=item C<document_die>

Probability of crash inside process_document function caused by calling die.

=item C<document_fatal>

Probability of crash inside process_document function caused by calling log_fatal.

=back

=head1 AUTHOR

Martin Majlis <majlis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
