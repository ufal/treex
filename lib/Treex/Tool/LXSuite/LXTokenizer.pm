package Treex::Tool::LXSuite::LXTokenizer;
use Moose;
extends 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (default => 'plain:tokenizer:plain');

sub tokenize {
    my ( $self, $sentence ) = @_;
    $sentence =~ s/^\s+$//;
    return '' if $sentence eq '';

    $self->write("$sentence\n\n");
    my $tokenized = $self->read();
    while ($tokenized =~ /^\s*$/) { # discard empty lines
        $tokenized = $self->read();
    }
    return $tokenized;
}

1;

__END__

=head1 NAME 

Treex::Tool::Tagger::LXTokenizer

=head1 SYNOPSIS

my $tokenizer = Treex::Tool::LXSuite::LXTokenizer->new();
my $tokens = $tagger->tokenize($sentence);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
