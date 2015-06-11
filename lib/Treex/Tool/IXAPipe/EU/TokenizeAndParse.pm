package Treex::Tool::IXAPipe::EU::TokenizeAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
#use File::Java;
use File::Temp qw/ tempdir /;
use Treex::Tool::ProcessUtils;
use IPC::Open3;
use autodie;

Readonly my $INST_DIR => 'installed_tools';

# Handle all kinds of Unicode spaces (non-breaking etc.)
Readonly my $SPACE => '[\s\N{U+00A0}\N{U+200b}\N{U+2007}\N{U+202F}\N{U+2060}\N{U+FEFF}]';

# ixa-pipe tagger main JAR
has 'tagger' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/eustagger/bin/eustagger_lite',
    writer  => '_set_tagger'
);

# ixa-pipe parser main JAR
has 'parser_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/ixa-pipe/EU/ixa-pipe-dep-basque-1.0.jar',
    writer  => '_set_parser_jar'
    );

# Memory allowed to the parser
has 'parser_memory' => ( is => 'ro', isa => 'Str', default => '2000m' );

has 'on_whitespaces' => ( is => 'ro', isa => 'Int' , default => 0, writer => "set_onWhitespaces");

has 'tagger_model' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/eustagger/var/eustagger_lite',
);

# TODO: ixa-pipe-dep-basque-1.0.jar has the following model name somewhere hardcoded
#       so changing this parameter won't change the model used
has 'parser_model' => (
    is      => 'ro',
    isa     => 'Str',
    default => $INST_DIR . '/ixa-pipe/EU/Resources',
);

# tagger slave application controls (bipipe handles, application PID)
has '_read_handle'    => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle'   => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'       => ( is => 'rw', isa => 'Int' );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    
    log_info( "Loading " . $self->tagger);
    $self->_set_tagger( Treex::Core::Resource::require_file_from_share( $self->tagger ) );
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
    my $parser  = $self->parser_jar;
    #my $command = $self->tagger . ' -f naf -m 4 -'
    my $command = $self->tagger;
    $command .= " -z" if ($self->on_whitespaces);
    $command .= ' -f naf -m 4 - 2>/dev/null'
    #$command .= ' -h -f naf -m 4 - 2>/dev/null' ## Multiwords? modifies the number of tokens in the output...
              . ' | java -Xmx' . $self->parser_memory
              . " -jar $parser -out /dev/fd/3 3>&1 1> /dev/null";

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

    foreach my $s (@sentences) {
	print  { $self->_write_handle } "$s\n";
    }
    close $self->_write_handle; # This is needed, so IXA starts parsing
    
    # read the result
    my @output;
    my $read = $self->_read_handle;
    while (<$read>) {
        push @output, $_;
    }
    close $self->_read_handle;
    Treex::Tool::ProcessUtils::safewaitpid( $self->_java_pid );
    
    #log_warn(join('', @output));
    return join '', @output;
}

1;

__END__

=head1 NAME

Treex::Tool::IXAPipe::EU::TokenizeAndParse

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
