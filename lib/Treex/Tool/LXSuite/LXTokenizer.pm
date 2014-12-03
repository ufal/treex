package Treex::Tool::LXSuite::LXTokenizer;
use Moose;
extends 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (
    isa => 'Str', is => 'ro',
    default => 'plain:tokenizer:plain'
);
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub tokenize_sentence {
    my ( $self, $sentence ) = @_;
    print STDERR "LXTokenizer in: ".$sentence."\n" if $self->debug;
    print {$self->_writer} $sentence."\n\n";
    my $reader = $self->_reader;
    my $tokenized = <$reader>;
    while ($tokenized =~ /^\s*$/) { # discard empty lines
        $tokenized = <$reader>;
    }

    die "Failed to read from LX-Suite tokenizer, better to kill oneself." if !defined $tokenized;
    print STDERR "LXTokenizer out: ".$tokenized."\n" if $self->debug;
    return $tokenized;
}

1;

__END__

=head1 NAME 

Treex::Tool::Tagger::LXTokenizer

=head1 SYNOPSIS

my $tokenizer = Treex::Tool::LXSuite::LXTokenizer->new();
my $tokens = $tagger->tokenize_sentence($sentence);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
