package Treex::Tool::Tagger::MElt;
use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;
with 'Treex::Tool::Tagger::Role';

# Handle all kinds of Unicode spaces (non-breaking etc.)
Readonly my $SPACE => '[\s\N{U+00A0}\N{U+200b}\N{U+2007}\N{U+202F}\N{U+2060}\N{U+FEFF}]';

# Stanford tagger slave application controls (bipipe handles, application PID)
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'     => ( is => 'rw', isa => 'Int' );

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    
    my $command = 'export BONSAI=/a/LRC_TMP/mnovak/tools/french_tagging_parsing/bonsai_v3.2; $BONSAI/bin//bonsai_preproc_for_malt_or_mst.sh -n';

    log_info( "Running " . $command );

    $SIG{PIPE} = 'IGNORE';     # don't die if tagger gets killed
    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);

    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);

    # Send testing sentence (works as waiting for loading)
    print $write "A\n";
    my $status = <$read>;
    print STDERR $status;
    log_fatal('MElt tagger not loaded correctly') if ( ( $status || '' ) !~ /^1\tA/ );
    #read a following empty line
    $status = <$read>;

    return;
}

sub DEMOLISH {
    my ($self) = @_;
        
    # Close the tagger application
    close( $self->_write_handle ) if $self->_write_handle;
    close( $self->_read_handle ) if $self->_read_handle;
    Treex::Tool::ProcessUtils::safewaitpid( $self->_java_pid );
    return;
}

sub tag_sentence {
    my ( $self, $tokens_rf ) = @_;
    my @tokens = @$tokens_rf;
    
    # write the tokens to be tagged (trim tokens first)
    print { $self->_write_handle } join( " ", map { s/^$SPACE+//; s/$SPACE+$//; $_ } @tokens ), "\n";

    # read the result
    my $read = $self->_read_handle;

    my @tags;
    my @lemmas;

    # unfortunately, if Stanford tagger reads from STDIN (which it does, in our case), it tries to
    # detect sentence boundaries even if the input is tokenized and splits the output into multiple
    # lines according to these sentence boundaries
    while ( @tags < @tokens ) {
        
        my $result = <$read>;
        log_fatal( 'Premature EOF: needed ' . scalar(@tokens) . ', got ' . scalar(@tags) . '. Tagger died?' ) if ( !$result );

        my ($ord, $form, $lemma, $cpos, $fpos, $feats, @rest) = split /\t/, $result;

        push @tags, (join " ",  ($cpos, $fpos, $feats));
        push @lemmas, $lemma;
    }
    # empty line 
    <$read>;

    return (\@tags, \@lemmas);
}

1;

=head1 NAME

Treex::Tool::Tagger::MElt

=head1 SYNOPSIS

 

=head1 DESCRIPTION

MElt POS tagger for French wrapper.

=head1 PARAMETERS

=over

=item memory

Amount of memory for the Java VM running the Stanford tagger executable (default: 512m).

=item model

Path to the packed model file.

=back

=head1 METHODS

=over

=item $tags_rf = $tagger->tag_sentence(\@tokens);

Returns a list of tags for tokenized input.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

