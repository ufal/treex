package Treex::Tool::Parser::LXParser;
use Moose;
extends 'Treex::Tool::LXSuite::Client';
with 'Treex::Tool::Parser::Role';

has '+lxsuite_mode' => (
    isa => 'Str', is => 'ro',
    default => 'conll.pos:parser:conll.usd'
);

sub parse {
    return 
}

sub parse_sentence {
    my ( $self, $forms, $lemmas, $pos, $subpos, $features ) = @_;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    my $cnt = scalar @$forms;

    # write input
    for ( my $i = 0; $i < $cnt; $i++ ) {
        my $form = $$forms[$i];
        print $writer ($i+1) . "\t$form\t$$lemmas[$i]\t$$pos[$i]\t$$subpos[$i]\t$$features[$i]\t_\t_\t_\t_\n";
    }
    print $writer "\n";

    # read output
    my @parents = ();
    my @afuns = ();

    my $line = <$reader>;
    die "LXParser has died" if !defined $line;
    chomp $line;
    while ($line eq "") { # skip blanks
        $line = <$reader>;
        die "LXParser has died" if !defined $line;
        chomp $line;
    }

    while ( $cnt > 0 ) {
        my @items = split( /\t/, $line );
        push @parents, $items[6];
        push @afuns, $items[7];
        $line = <$reader>; # read blank line
        die "LXParser has died" if !defined $line;
        chomp $line;
        $cnt--;
    }

    return ( \@parents, \@afuns );
}

1;

__END__


=head1 NAME

Treex::Tools::Parser::LXParser

=head1 SYNOPSIS

  my $parser = Parser::LXParser->new();
  my ( $parent_indices, $afuns ) = $parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
