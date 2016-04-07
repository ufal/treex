package Treex::Tool::LXSuite;
use Moose;
use File::Basename;
use Frontier::Client;
use Encode;

has server => (
    isa => 'Frontier::Client',
    is => 'ro',
    required => 1,
    builder => '_build_server',
    lazy => 0
);

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


sub _build_server {
    my $self = @_;
    my $url = $config{"url"};
    # print STDERR "LXSuite server is $url\n";
    return Frontier::Client->new(url => $url, debug => 0);
}

sub analyse {
    my ($self, $sentence) = @_;
    my $utf8_sentence = encode('UTF-8', $sentence, Encode::FB_CROAK);
    return $self->server->call("analyse", $config{"key"}, $utf8_sentence);
}

sub conjugate {
    my ($self, $lemma, $form, $person, $number) = @_;
    my $utf8_lemma = encode('UTF-8', $lemma, Encode::FB_CROAK);
    # print STDERR "\nconjugate $utf8_lemma $form $person $number \n";
    return $self->server->call("conjugate", $config{"key"}, $utf8_lemma, $form, $person, $number);
}

sub inflect {
    my ($self, $lemma, $postag, $gender, $number, $superlative, $diminutive) = @_;
    my $utf8_lemma = encode('UTF-8', $lemma, Encode::FB_CROAK);
    # print STDERR "\ninflect $utf8_lemma $postag $gender $number $superlative $diminutive \n";
    return $self->server->call("inflect", $config{"key"}, $utf8_lemma, $postag, $gender, $number, $superlative, $diminutive);
}

sub feat {
    my ($self, $lemma, $postag) = @_;
    my $utf8_lemma = encode('UTF-8', $lemma, Encode::FB_CROAK);
    # print STDERR "\nfeat  $utf8_lemma $postag \n";
    return $self->server->call("feat", $config{"key"}, $utf8_lemma, $postag,  $utf8_lemma);
}


1;

__END__


=head1 NAME

Treex::Tool::LXSuite

=head1 SYNOPSIS

XML-RPC client for LXSuite service.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
