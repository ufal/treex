package Treex::Tool::FormsGenerator::Alpino;

use Moose;
use Treex::Core::Common;
use ProcessUtils;

use Treex::Block::Write::ADTXML; 

has '_twig'               => ( is => 'rw' );
has '_alpino_readhandle'  => ( is => 'rw' );
has '_alpino_writehandle' => ( is => 'rw' );
has '_alpino_pid'         => ( is => 'rw' );

has '_adtxml' => ( is => 'rw', builder => '_build_adtxml', lazy_build => 1 );

sub BUILD {

    my $self      = shift;
    my $tool_path = 'installed_tools/parser/Alpino';
    my $exe_path  = require_file_from_share("$tool_path/bin/Alpino");
    
    $tool_path = $exe_path; # get real tool path (not relative to Treex share)
    $tool_path =~ s/\/bin\/.*//;
    $ENV{ALPINO_HOME} = $tool_path; # set it as an environment variable to be passed to Alpino

    #TODO this should be done better
    my $redirect = Treex::Core::Log::get_error_level() eq 'DEBUG' ? '' : '2>/dev/null';

    # Force line-buffering of Alpino's output (otherwise it will hang)
    my @command = ( 'stdbuf', '-oL', $exe_path, 'end_hook=print_generated_sentence', '-generate' );

    $SIG{PIPE} = 'IGNORE';    # don't die if parser gets killed
    my ( $reader, $writer, $pid ) = ProcessUtils::bipipe_noshell( ":encoding(utf-8)", @command );
    
    $self->_set_alpino_readhandle($reader);
    $self->_set_alpino_writehandle($writer);
    $self->_set_alpino_pid($pid);

    return;
}

sub _build_adtxml {
    return Treex::Block::Write::ADTXML->new();
}

sub _generate_from_adtxml {
    my ( $self, $xml ) = @_;

    my $writer = $self->_alpino_writehandle;
    my $reader = $self->_alpino_readhandle;

    $xml =~ s/[\t\n]//g;
    print STDERR $xml . "\n";
    print $writer $xml, "\n";
    my $line = <$reader>;
    chomp $line;
    return $line;
}

# Try to inflect a single word
sub generate_form {
    my ($self, $anode) = @_;
    
    my $xml = $self->_adtxml->_process_node($anode);
    my $res = $self->_generate_from_adtxml($xml);
    $res =~ s/ \.$//;
    return $res;
}

# Try to generate a whole sentence
sub generate_sentence {
    my ($self, $atree) = @_;
    
    my $xml = $self->_adtxml->_process_tree($atree);    
    return $self->_generate_from_adtxml($xml);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::FormsGenerator::Alpino

=head1 DESCRIPTION

A Treex bipipe wrapper for the Dutch Alpino generator. Uses L<Treex::Block::Write::ADTXML>
to prepare input.

=head1 NOTES

Probably works on Linux only (due to the usage of the C<stdbuf> command to prevent buffering
of Alpino's output). No checks or automatic downloads are done for the rest of the Alpino 
distribution, just for the main executable.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
