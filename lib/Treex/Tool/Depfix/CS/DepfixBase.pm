package Treex::Block::;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

use Treex::Tool::Depfix::CS::DiacriticsStripper;
use Treex::Tool::Depfix::CS::FixLogger;

has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'rw', isa => 'Str', default  => '' );

my $fixLogger;

sub process_start {
    my $self = shift;
    
    $fixLogger = Treex::Tool::Depfix::CS::FixLogger->new({
        language => $self->language,
    });

    return;
}



1;

=head1 NAME 

Treex::

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

