package Treex::Block::W2A::PT::Tokenize;

use File::Basename;
use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;

extends 'Treex::Core::Block';
# I didn't extend Treex::Block::W2A::TokenizeOnWhitespace and instead
#  adapted sub process_zone because LX-Tokenizer modifies punct tokens
#  in a way that TokenizeOnWhitespace would fail when trying to determine
#  the no_space_after attribute of a-tree nodes.

has debug => ( isa => 'Bool', is => 'ro', required => 0, default => 1 );
has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has num_tokenized_sents => ( isa => 'Int', is => 'rw', required => 0, default => 0 );
has [qw( _reader _writer _pid )] => ( is => 'rw' );


sub tokenize_sentence {
    my ( $self, $sentence ) = @_;
    my $sentence_num = $self->num_tokenized_sents + 1;
    print STDERR "PT::Tokenize in [$sentence_num]: ".$sentence."\n"
        if $self->debug;
    print {$self->_writer} $sentence."\n\n";
    my $reader = $self->_reader;
    my $tokenized = <$reader>;
    while (!$tokenized) { # discard empty lines
        $tokenized = <$reader>;
    }

    die "Failed to read from LX-Suite tokenizer, better to kill oneself."
        if !defined $tokenized;
    print STDERR "PT::Tokenize out[$sentence_num]: ".$tokenized."\n"
        if $self->debug;
    $self->set_num_tokenized_sents($sentence_num);
    return $tokenized;
};

sub process_zone {
    my ( $self, $zone ) = @_;
    
    # create a-tree
    my $a_root = $zone->create_atree();

    # get the source sentence and tokenize
    my $sentence = $zone->sentence;
    $sentence =~ s/^\s+//;
    log_fatal("No sentence to tokenize!") if !defined $sentence;
    my @tokens = split( /\s/, $self->tokenize_sentence($sentence) );

    # Create a-nodes and detect the no_space_after attribute.
    foreach my $i ( ( 0 .. $#tokens ) ) {
        my $token = $tokens[$i];
        # create new a-node
        $a_root->create_child(
            form           => $token,
            no_space_after => 0,
            ord            => $i + 1,
        );
    }
    return 1;
}


sub BUILD {
    my $self = shift;
    my $client = require_file_from_share(
        "installed_tools/lxsuite_client.sh",
        ref( $self ),
    );
    my $key = $self->lxsuite_key;
    my $cmd = "$client $key plain:tokenizer:plain";
    my ( $reader, $writer, $pid ) =
        Treex::Tool::ProcessUtils::bipipe($cmd, ':encoding(utf-8)');
    $self->_set_reader( $reader );
    $self->_set_writer( $writer );
    $self->_set_pid( $pid );
}

sub DEMOLISH {
    my $self = shift;
    close( $self->_writer );
    close( $self->_reader );
    Treex::Tool::ProcessUtils::safewaitpid( $self->_pid );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::PT::Tokenize

=head1 DESCRIPTION

Uses LX-Suite tokenizer to split a sentence into a sequence of tokens.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
