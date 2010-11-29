package Treex::Tools::Tagger::TreeTagger;

use Moose;
use MooseX::FollowPBP;

use ProcessUtils;

has model => (isa => 'Str', is => 'rw', required => 1);

sub BUILD {

    my ($self) = @_;

    #to be changed
    my $bindir = "$ENV{TMT_ROOT}/share/installed_tools/tree_tagger/bin";
    die "Missing $bindir\n" if !-d $bindir;

    my $command = "$bindir/tree-tagger -token -lemma -no-unknown ".$self->{model};
    
    # start TreeTagger and load the model
    my ( $reader, $writer, $pid ) = ProcessUtils::bipipe( $command, ":encoding(utf-8)" );
    $self->{ttreader} = $reader;
    $self->{ttwriter} = $writer;
    $self->{ttpid}    = $pid;

    #bless $self;

    # writes to the input three technical tokens as a sentence separator
    print $writer ".\n.\n.\n";

    return;# $self;
}

sub analyze {
    my $self = shift;
    my $toks = shift;
    return [] if scalar @$toks == 0;

    my $ttwr = $self->{ttwriter};
    my $ttrd = $self->{ttreader};

    # tokens to force end of sentence
    my $cnt = 0;

    # input tokens
    foreach my $tok ( @$toks ) {
        print $ttwr $tok . "\n";
        $cnt++;
    }

    # input sentence separator
    print $ttwr ".\n.\n.\n";

    my @tags = ();
    my @lemmas = ();

    # skip sentence separator
    for (my $i = 0; $i < 3; $i++) {
        my $got = <$ttrd>;
    }

    # read output
    while ( $cnt > 0 ) {
        my $got = <$ttrd>;
        chomp $got;
        my @items = split( /\t/, $got );
        $cnt--;
        push @tags, $items[1];
        push @lemmas, $items[2];
    }

    my @output = (\@tags, \@lemmas);
    return \@output;
}

1;

__END__


=head1 NAME

Tagger::TreeTagger

TreeTagger. Reads list of tokens and returns list of tags
and list of lemmas.

=head1 SYNOPSIS

  my $tagger = Tagger::TreeTagger->new();
  my ($tags, $lemmas) = @{ $tagger->analyze(["How","are","you","?"]) };
  print join(" ", @$tags);
  print join(" ", @$lemmas);

=cut

# Copyright 2009 David Marecek
