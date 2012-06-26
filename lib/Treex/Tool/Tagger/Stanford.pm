package Treex::Tool::Tagger::Stanford;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use File::Java;
use ProcessUtils;

Readonly my $INST_DIR => 'installed_tools/tagger/stanford/';

# Stanford tagger main JAR
has 'stanford_tagger_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . 'stanford-postagger.jar',
    writer  => '_set_stanford_tagger_jar'
);

# Path to the model data file
has 'model' => ( is => 'ro', isa => 'Str', required => 1, writer => '_set_model' );

# Memory allowed to the tagger
has 'memory' => ( is => 'ro', isa => 'Str', default => '512m' );

# Stanford tagger slave application controls (bipipe handles, application PID)
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'     => ( is => 'rw', isa => 'Int' );

sub BUILD {

    my ( $self, $params ) = @_;

    $self->_set_stanford_tagger_jar( Treex::Core::Resource::require_file_from_share( $self->stanford_tagger_jar ) );
    $self->_set_model( Treex::Core::Resource::require_file_from_share( $self->model ) );

    my $tagger  = File::Java->path_arg( $self->stanford_tagger_jar );
    my $command = 'java ' . ' -Xmx' . $self->memory
        . ' -cp ' . $tagger . ' edu.stanford.nlp.tagger.maxent.MaxentTagger '
        . ' -model ' . $self->model
        . ' -textFile  STDIN '
        . ' -tokenize false '
        . ' 2> /dev/null ';    # suppress the rather verbose Stanford tagger output

    log_info( "Running " . $command );

    $SIG{PIPE} = 'IGNORE';     # don't die if tagger gets killed
    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);

    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);

    # Send testing sentence (works as waiting for loading)
    print $write "A\n";
    my $status = <$read>;
    log_fatal('Stanford tagger not loaded correctly') if ( ( $status || '' ) !~ /^A/ );
    $status = <$read>;         # read empty line left by Stanford tagger

    return;
}

sub DEMOLISH {

    my ($self) = @_;

    # Close the tagger application
    close( $self->_write_handle );
    close( $self->_read_handle );
    ProcessUtils::safewaitpid( $self->_java_pid );
    return;
}

sub tag_sentence {
    my ( $self, @tokens ) = @_;

    # write the tokens to be tagged
    print { $self->_write_handle } join( " ", @tokens ), "\n";

    # read the result
    my $read = $self->_read_handle;

    my @tagged;
    # unfortunately, if Stanford tagger reads from STDIN (which it does, in our case), it tries to
    # detect sentence boundaries even if the input is tokenized and splits the output into multiple
    # lines according to these sentence boundaries
    while ( @tagged < @tokens ) {
        my $result = <$read>;
        $result =~ s/\r?\n$//;    # read tagged data line
        push @tagged, split( /\s+/, $result );
        $result = <$read>;        # read empty line left by Stanford tagger
    }

    # extract tags
    log_fatal( 'Invalid result: ' . scalar(@tokens) . ' sent, ' . scalar(@tagged) . ' received.' ) if ( @tagged != @tokens );

    for ( my $i = 0; $i < @tokens; ++$i ) {
        $tagged[$i] = substr( $tagged[$i], length( $tokens[$i] ) + 1 );
    }

    return @tagged;
}

1;

=head1 NAME

Treex::Tool::Tagger::Stanford

=head1 SYNOPSIS

 

=head1 DESCRIPTION

Stanford Java POS tagger wrapper.

=head1 PARAMETERS

=over

=item memory

Amount of memory for the Java VM running the Stanford tagger executable (default: 512m).

=item model

Path to the packed model file.

=back

=head1 METHODS

=over

=item @tags = $tagger->tag(@tokens);


=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

