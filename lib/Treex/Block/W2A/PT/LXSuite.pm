package Treex::Block::W2A::PT::LXSuite;
use Moose;
use File::Basename;
use Frontier::Client;
use Encode;

extends 'Treex::Core::Block';

sub _get_config {
    open FILE, $ENV{"HOME"}."/.lxsuite2";
    my @lines = <FILE>;
    close FILE;
    my %config;
    for my $line (@lines) {
        if ($line =~ /^\s*(.*)\s*=\s*([^ \n]*)\s*$/) {
            $config{lc $1} = $2;
        }
    }
    if (defined $ENV{'LXSUITE2_KEY'}) {
        $config{"key"} = $ENV{'LXSUITE2_KEY'};
    }
    if (defined $ENV{'LXSUITE2_SERVER'}) {
        $config{"url"} = 'http://'.$ENV{'LXSUITE2_SERVER'};
    } else {
        $config{"url"} = 'http://'.($config{"host"} // "localhost").
                                ":".($config{"port"} // "10000");
    }
    return %config;
    say STDERR, %config;
}

my %config = _get_config;

has server => ( isa => 'Frontier::Client',
    is => 'ro', required => 1, builder => '_build_server', lazy => 0 );

sub _build_server {
    my $self = @_;
    my $url = $config{"url"};
    print STDERR "LXSuite server is $url\n";
    return Frontier::Client->new(url => $url, debug => 0);
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $utf8_sentence = encode('UTF-8', $zone->sentence, Encode::FB_CROAK);
    my $tokens = $self->server->call("analyse", $config{"key"}, $utf8_sentence);

    my $a_root = $zone->create_atree();
    # create nodes
    my $i = 1;
    my @a_nodes = map { $a_root->create_child({
        "form"         => $_->{"form"},
        "ord"          => $i++,
        "lemma"        => ($_->{"lemma"} // uc $_->{"form"}),
        "conll/pos"    => $_->{"pos"},
        "conll/cpos"   => $_->{"pos"},
        "conll/feat"   => $_->{"infl"} // '',
        "conll/deprel" => $_->{"udeprel"},
    }); } @$tokens;

    # build tree
    my @roots = ();
    while (my ($i, $token) = each @$tokens) {
        if ($token->{"form"} =~ /^\pP$/) {
            if ($i > 0 and ($token->{"space"} // "") !~ "L") {
                $a_nodes[$i-1]->set_no_space_after(1);
            }
            $a_nodes[$i]->set_no_space_after(($token->{"space"} // "") !~ "R");
        } elsif ($token->{"form"} =~ /_$/) {
            $a_nodes[$i]->set_no_space_after(1);
        }
        if ($token->{"parent"} && (int $token->{"parent"}) <= scalar @a_nodes) {
            $a_nodes[$i]->set_parent(@a_nodes[(int $token->{"parent"})-1]);
        } else {
            push @roots, $a_nodes[$i];
        }
    }

    return @roots;
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
