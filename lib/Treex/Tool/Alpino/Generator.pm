package Treex::Tool::FormsGenerator::Alpino;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;

use Treex::Block::Write::ADTXML;

with 'Treex::Tool::Alpino::Run';

has '_adtxml' => ( is => 'rw', builder => '_build_adtxml', lazy_build => 1 );

sub BUILD {

    my $self = shift;

    $self->_start_alpino( 'user_max=90000', 'end_hook=print_generated_sentence', '-generate' );

    return;
}

sub _build_adtxml {
    return Treex::Block::Write::ADTXML->new( { prettyprint => 0 } );
}

sub _generate_from_adtxml {
    my ( $self, $xml ) = @_;

    my $writer = $self->_alpino_writehandle;
    my $reader = $self->_alpino_readhandle;

    print $writer $xml;
    my $line      = <$reader>;
    my $last_line = '';
    my $sent      = '';

    while ( !$sent ) {
        chomp $line;
        log_info 'ALPINO: ' . $line;

        # this indicates that generation has finished
        if ( $line =~ /^G#undefined\|/ ) {
            $sent = $last_line;
            last;
        }

        # this means that an error has occurred
        elsif ( $line =~ /^K#undefined\|/ ) {
            log_warn( 'Alpino returned K-undef, last line: ' . $last_line );
            last;
        }

        $last_line = $line;
        $line      = <$reader>;
    }
    return $sent;
}

# Try to inflect a single word
sub generate_form {
    my ( $self, $anode ) = @_;

    my $xml = $self->_adtxml->_process_node($anode);
    my $res = $self->_generate_from_adtxml($xml);
    $res =~ s/ \.$//;
    return $res;
}

# Try to generate a whole sentence
sub generate_sentence {
    my ( $self, $atree ) = @_;

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
