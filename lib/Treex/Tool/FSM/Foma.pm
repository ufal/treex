package Treex::Tool::FSM::Foma;

use Moose;
use Treex::Tool::ProcessUtils;
use Treex::Core::Common;

# Foma main executable
has 'foma_bin' => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/share/installed_tools/foma/foma" );

# Working directory (if required for grammar and additional files)
has 'work_dir' => ( is => 'ro', isa => 'Str', default => '.' );

# Main grammar file to be loaded on startup
has 'grammar' => ( is => 'ro', isa => 'Str' );

# Write pipe handle
has '_write' => ( is => 'rw', isa => 'FileHandle' );

# Read pipe handle
has '_read' => ( is => 'rw', isa => 'FileHandle' );

# PID number of the Foma process
has '_pid' => ( is => 'rw', isa => 'Int' );

# Run the Foma executable with the startup grammar file.
sub BUILD {
    my ($self) = @_;

    die 'The specified working directory' . $self->work_dir . "does not exist.\n" if !( -d $self->work_dir );

    # create the startup command
    my $command = "cd " . $self->work_dir . "; " . $self->foma_bin . " -p ";
    if ( $self->grammar ) {
        $command .= " -l " . $self->grammar . "";
    }

    # start Foma
    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);

    $self->_set_write($write);
    $self->_set_read($read);
    $self->_set_pid($pid);

    log_info("Waiting for Foma ...");
    $self->command("echo INIT");    # Read and suppress any output from the startup grammar
    log_info("Done.");

    return;
}

sub up {
    my ( $self, $text ) = @_;

    $text =~ s/^/apply up /g;
    return $self->command($text);
}

sub down {
    my ( $self, $text ) = @_;

    $text =~ s/^/apply down /g;
    return $self->command($text);
}

sub command {
    my ( $self, $cmd ) = @_;
    my $output = '';

    $cmd =~ s/\n+/\n/;
    $cmd =~ s/\n$//;

    foreach my $line ( split /\n/, $cmd ) {

        print { $self->_write } $line . "\n\n";

        my $fh = $self->_read;
        while (<$fh>) {
            $_ =~ s/\r?\n$//;
            $output .= $_ if !( $_ eq $line );
            last if $_ =~ m/^\r?\n?$/;
        }
    }

    return $output;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::FSM::Foma

=head1 DESCRIPTION

Perl wrapper for the L<Foma|http://foma.sourceforge.net/> finite state library, which provides finite-state transducers
with XFST (Xerox Finite-State Tools)-compatible grammars.

=head1 PARAMETERS

=over

=item C<foma_bin>

Path to the Foma executable (required).

=item C<work_dir>

Working directory (useful for loading external files from within Foma). Defaults to current directory.

=item C<grammar>

Foma script file (regular grammar) to be loaded on startup.

=back 

=head1 METHODS

=over

=item C<command>

Execute any Foma command and return its output.

=item C<up>

Execute the Foma C<apply up> command on the given input and return the output.

=item C<down>

Execute the Foma C<apply down> command on the given input and return the output.

=back 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
