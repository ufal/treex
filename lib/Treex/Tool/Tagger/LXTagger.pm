package Treex::Tool::Tagger::LXTagger;
use Moose;
use Treex::Core::Log;
extends 'Treex::Tool::LXSuite::Client';
with 'Treex::Tool::Tagger::Role';

has '+lxsuite_mode' => (
    isa => 'Str', is => 'ro',
    default => 'plain:tokenizer_tagger:conll.pos'
);
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub tag_sentence {
    my $self = shift;
    my $toks = shift;
    my $ntoks = @$toks;
    my $to_tag = join(" ", @$toks);
    print STDERR "LXTagger in     : $to_tag\n" if $self->debug;

    return [], [] if $ntoks == 0;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    my $postags = [];
    my $lemmas  = [];

    print $writer "$to_tag\n\n";
    my $line = <$reader>;
    while ( $ntoks > 0 ) {
        die "LXTagger has died" if !defined $line;
        chomp $line;
        print STDERR "From LXTagger: $line\n";
        log_fatal 'unexpected empty line' if $line =~ /^\s*$/;
        my ($tokid, $form, $lemma, $postag, $cpostag, $feat) = split( /\t/, $line );
        $ntoks--;
        $postag .= "#$feat" unless $feat eq '';
        push @$postags, $postag;
        push @$lemmas, $lemma;
        $line = <$reader>;
    }

    if ($self->debug) {
        print STDERR "LXTagger tags   : ".join(" ", @$postags)."\n";
        print STDERR "LXTagger lemmas : ".join(" ", @$lemmas)."\n\n";
    }
    return ($postags, $lemmas);
}

1;

__END__

=head1 NAME 

Treex::Tool::Tagger::LXTagger

=head1 SYNOPSIS

my $tagger = Treex::Tool::Tagger::LXTagger->new();
my ( $tags_rf, $lemmas_rf ) = $tagger->tag_sentence($forms_rf);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
