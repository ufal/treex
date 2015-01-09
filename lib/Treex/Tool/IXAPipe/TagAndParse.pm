package Treex::Tool::IXAPipe::TagAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use File::Java;
use File::Temp qw/ tempdir /;
use IO::Handle;
use ProcessUtils;

Readonly my $INST_DIR => 'installed_tools/ixa-pipe';

# Handle all kinds of Unicode spaces (non-breaking etc.)
Readonly my $SPACE => '[\s\N{U+00A0}\N{U+200b}\N{U+2007}\N{U+202F}\N{U+2060}\N{U+FEFF}]';

# ixa-pipe tagger main JAR
has 'tagger_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/ixa-pipe-pos-1.2.0.jar',
    writer  => '_set_tagger_jar'
    );

# Memory allowed to the tagger
has 'tagger_memory' => ( is => 'ro', isa => 'Str', default => '512m' );

# ixa-pipe tagger main JAR
has 'parser_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/IXA-EHU-srl-1.0.jar',
    writer  => '_set_parser_jar'
    );

# Memory allowed to the tagger
has 'parser_memory' => ( is => 'ro', isa => 'Str', default => '2500m' );

# tagger slave application controls (bipipe handles, application PID)
has '_conll_filename' => ( is => 'rw', isa => 'Str' );
has '_read_handle'    => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle'   => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'       => ( is => 'rw', isa => 'Int' );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    
    log_info( "Loading " . $self->tagger_jar);
    $self->_set_tagger_jar( Treex::Core::Resource::require_file_from_share( $self->tagger_jar ) );
    log_info( "Loading " . $self->parser_jar);
    $self->_set_parser_jar( Treex::Core::Resource::require_file_from_share( $self->parser_jar ) );

    my ($fh, $filename) = File::Temp::tempfile(OPEN => 0);

    my $tagger  = File::Java->path_arg( $self->tagger_jar );
    my $parser  = File::Java->path_arg( $self->parser_jar );
    my $command = 'java' . ' -Xmx' . $self->tagger_memory
        . ' -jar ' . $tagger . ' tag 2> /dev/null'
        . ' | java ' . ' -Xmx' . $self->parser_memory
    	. ' -jar ' . $parser . ' -l es -o only-deps --conll ' . $filename
        . ' 2> /dev/null ';    # suppress the rather verbose tagger output
    # my $command = 'java' . ' -Xmx' . $self->tagger_memory
    #     . ' -jar ' . $tagger . ' tag'
    #     . ' | java ' . ' -Xmx' . $self->parser_memory
    # 	. ' -jar ' . $parser . ' -l es -o only-deps --conll ' . $filename;

    log_info( "Running " . $command );

    $SIG{PIPE} = 'IGNORE';     # don't die if tagger gets killed
    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);

    $self->_set_conll_filename($filename);
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);

    return;
}

sub launch {
    my $self = shift;
    
    close( $self->_write_handle ) if $self->_write_handle;
    close( $self->_read_handle ) if $self->_read_handle;
    ProcessUtils::safewaitpid( $self->_java_pid );

    my $filename = $self->_conll_filename;
    my $tagger  = File::Java->path_arg( $self->tagger_jar );
    my $parser  = File::Java->path_arg( $self->parser_jar );
    my $command = 'java' . ' -Xmx' . $self->tagger_memory
        . ' -jar ' . $tagger . ' tag 2> /dev/null'
        . ' | java ' . ' -Xmx' . $self->parser_memory
    	. ' -jar ' . $parser . ' -l es -o only-deps --conll ' . $filename
        . ' 2> /dev/null ';    # suppress the rather verbose tagger output
    # my $command = 'java' . ' -Xmx' . $self->tagger_memory
    #     . ' -jar ' . $tagger . ' tag'
    #     . ' | java ' . ' -Xmx' . $self->parser_memory
    # 	. ' -jar ' . $parser . ' -l es -o only-deps --conll ' . $filename;
    log_info( "Running " . $command );

    $SIG{PIPE} = 'IGNORE';     # don't die if tagger gets killed
    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);

    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);

    return;
}

sub conll_handle {
    my $self = shift;

    my $fh;
    open ($fh, $self->_conll_filename);
    my $tmp_reader = new IO::Handle;
    $tmp_reader->fdopen($fh, 'r');
    $tmp_reader->autoflush(1);
    binmode($tmp_reader, ":utf8");

    return $tmp_reader;
}

sub scape_xml {
    my $self=shift;
    my $text=shift;

    $text =~ s/&/&amp;/;
    $text =~ s/"/&quot;/;
    $text =~ s/'/&apos;/;
    $text =~ s/</&lt;/;
    $text =~ s/>/&gt;/;

    return $text;
}

sub DEMOLISH {
    my ($self) = @_;
    
    # Close the tagger application
    close( $self->_write_handle ) if $self->_write_handle;
    close( $self->_read_handle ) if $self->_read_handle;
    ProcessUtils::safewaitpid( $self->_java_pid );

    unlink ($self->_conll_filename);

    return;
}

sub parse_document {
    my ( $self, $sentences_rf ) = @_;
    my @sentences = @$sentences_rf;

    print { $self->_write_handle } "<NAF xml:lang='es' version='2.0'><text>\n";
    #print STDERR "<NAF xml:lang='es' version='2.0'><text>\n";
    my $sent=1;
    my $tid=1;
    foreach my $s (@sentences) {
    	my @tokens = split(/ /, $s);
    	foreach my $t (@tokens) {
    	    print  { $self->_write_handle } "<wf id='$tid' sent='$sent'>" . $self->scape_xml($t) . "</wf>\n";
    	    #print  STDERR "<wf id='$tid' sent='$sent'>" . $self->scape_xml($t) . "</wf>\n";
    	    $tid++;
    	}
    	$sent++;
    }
    print { $self->_write_handle } "</text></NAF>\n";
    #print STDERR "</text></NAF>\n";
    close ( $self->_write_handle );

    # read the result
    my $read = $self->_read_handle;
    while (<$read>) {
	#print STDERR $_;
    }

    my @output;
    $read = $self->conll_handle();
    while (<$read>) {
	push @output, $_;
    }

    close ( $read );

    return join ( "", @output );
}

1;

__END__

=head1 NAME

Treex::Tool::IXAPipe::TagAndParse

=head1 SYNOPSIS

=head1 DESCRIPTION

ixa-pipe Java PoS tagger and dependency parser wrapper.

=head1 PARAMETERS

=over

=item parser_memory

Amount of memory for the Java VM running the ixa-pipe tagger executable (default: 512m).

=item parser_memory

Amount of memory for the Java VM running the ixa-pipe parser executable (default: 2500m).

=back

=head1 METHODS

=over

=item $tags_rf = $tagger->tag_document(\@sentences);

Returns a list of tags for tokenized input.

=back

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.es>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA group, University of the Basque Country (UPV/EHU)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
