package Treex::Tool::IXAPipe::ES::TagAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use File::Temp qw/ tempdir /;
use Treex::Tool::ProcessUtils;
use IPC::Open3;
use autodie;

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

has 'tagger_model' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/models/spa/CoNLL2009-ST-Spanish-ALL.anna-3.3.morphtagger.model',
);


# ixa-pipe tagger main JAR
has 'parser_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/IXA-EHU-srl-1.0.jar',
    writer  => '_set_parser_jar'
    );

# Memory allowed to the tagger
has 'parser_memory' => ( is => 'ro', isa => 'Str', default => '2000m' );

# TODO: IXA-EHU-srl-1.0.jar has the following model name somewhere hardcoded
#       so changing this parameter won't change the model used
has 'parser_model' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/models/spa/CoNLL2009-ST-Spanish-ALL.anna-3.3.parser.model',
);

# tagger slave application controls (bipipe handles, application PID)
has '_read_handle'    => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle'   => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'       => ( is => 'rw', isa => 'Int' );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    
    log_info( "Loading " . $self->tagger_jar);
    $self->_set_tagger_jar( Treex::Core::Resource::require_file_from_share( $self->tagger_jar ) );
    Treex::Core::Resource::require_file_from_share( $self->tagger_model );
    log_info( "Loading " . $self->parser_jar);
    $self->_set_parser_jar( Treex::Core::Resource::require_file_from_share( $self->parser_jar ) );
    Treex::Core::Resource::require_file_from_share( $self->parser_model );
    
    # Unfortunatelly, IXA-EHU-srl needs to be executed again for each document
    # (which takes about 43 seconds for loading the models), because it does not support streaming.
    # We could pre-load the models now with
    # $self->launch();
    # but it is more straightforward to run launch() always from parse_document().
    return;
}

sub launch {
    my ($self) = @_;
    my $tagger  = $self->tagger_jar;
    my $parser  = $self->parser_jar;
    my $command = 'java -Xmx' . $self->tagger_memory
        . " -jar $tagger tag 2>/dev/null" # suppress the rather verbose tagger output
        . ' | java -Xmx' . $self->parser_memory
        . " -jar $parser -l es -o only-deps"
        # IXA-EHU-srl always outputs NAF XML to stdout.
        # Let's discard this XML output, and redirect the CoNLL to stdout (via /dev/fd/3)
        . ' --conll /dev/fd/3 3>&1 1>/dev/null';
    log_info "Running $command";

    $SIG{PIPE} = 'IGNORE';     # don't die if tagger gets killed
    #my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::verbose_bipipe($command);
    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);

    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);
    return;
}


sub scape_xml {
    my ($self, $text) = @_;

    $text =~ s/&/&amp;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&apos;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;

    return $text;
}

sub parse_document {
    my ( $self, $sentences_rf ) = @_;
    my @sentences = @$sentences_rf;

    $self->launch();
    
    print { $self->_write_handle } "<NAF xml:lang='es' version='2.0'><text>\n";
    my $sent=1;
    my $tid=1;
    foreach my $s (@sentences) {
        my @tokens = split(/ /, $s);
        foreach my $t (@tokens) {
            print  { $self->_write_handle } "<wf id='$tid' sent='$sent'>" . $self->scape_xml($t) . "</wf>\n";
            $tid++;
        }
        $sent++;
    }
    print { $self->_write_handle } "</text></NAF>\n";
    close $self->_write_handle; # This is needed, so IXA starts parsing
    
    # read the result
    my @output;
    my $read = $self->_read_handle;
    while (<$read>) {
        push @output, $_;
    }
    close $self->_read_handle;
    Treex::Tool::ProcessUtils::safewaitpid( $self->_java_pid );
    
    return join '', @output;
}

1;

__END__

=head1 NAME

Treex::Tool::IXAPipe::ES::TagAndParse

=head1 SYNOPSIS

=head1 DESCRIPTION

ixa-pipe Java PoS tagger and dependency parser wrapper.

=head1 PARAMETERS

=over

=item parser_memory

Amount of memory for the Java VM running the ixa-pipe tagger executable (default: 512m).

=item parser_memory

Amount of memory for the Java VM running the ixa-pipe parser executable (default: 2000m).

=back

=head1 METHODS

=over

=item $tags_rf = $tagger->tag_document(\@sentences);

Returns a list of tags for tokenized input.

=back

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.es>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA group, University of the Basque Country (UPV/EHU)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
