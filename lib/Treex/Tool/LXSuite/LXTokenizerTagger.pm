package Treex::Tool::Tagger::LXTagger;
use Treex::Core::Log;
use Moose;
extends 'Treex::Core::Block';
with 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (
    isa => 'Str', is => 'ro',
    default => 'plain:tokenizer_tagger:conll.pos'
);
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub process_zone {
    my ( $self, $zone ) = @_;
    
    my $a_root = $zone->create_atree();

    my $sentence = $zone->sentence;
    log_fatal("No sentence to tokenize!") if !defined $sentence;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    my $forms   = [];
    my $postags = [];
    my $lemmas  = [];

    print $writer "$sentence\n\n";
    log_debug ">| $sentence\n\n";

    my $prev_node = undef;
    # Create a-nodes and detect the no_space_after attribute.
    my $line = <$reader>;
    chomp $line;

    $i = 1;
    while ($line ne '') {
        log_debug "<| $line\n";
        my ($tokid, $token, $lemma, $postag, $cpostag, $feat) = split(/\t/, $line);
        my $no_space_after = 0;
        my ($left, $form, $right) = $token =~ /^(\\\*)?(.+)(\*\/)?$/;
        # Maybe rework this ^^^

        
        if ($form =~ /^\pP$/) {
            $prev_node->set_no_space_after(1) if defined $prev_node and !defined $left;
            $no_space_after = 1 if !defined $right;
        } elsif ($form =~ /_$/) {
            $no_space_after = 1;
        }
        $prev_node = $a_root->create_child(
            form           => $form,
            no_space_after => $no_space_after,
            ord            => $i++,
        );
    }
    return 1;
}

sub tokenize_tag_sentence {
    my $self = shift;
    my $toks = shift;
    my $ntoks = @$toks;
    my $to_tag = join(" ", @$toks);
    log_debug "LXTokenizerTagger in     : $to_tag\n" if $self->debug;

    return [], [] if $ntoks == 0;


    my $line = <$reader>;
    while ( $ntoks > 0 ) {
        die "LXTokenizerTagger has died" if !defined $line;
        chomp $line;
        $postag .= "#$feat" unless $feat eq '';
        push @$forms,   $form; 
        push @$postags, $postag;
        push @$lemmas,  $lemma;
        push @$feats
        $line = <$reader>;
    }

    if ($self->debug) {
        print STDERR "LXTokenizerTagger forms  : ".join(" ", @$forms)."\n";
        print STDERR "LXTokenizerTagger tags   : ".join(" ", @$postags)."\n";
        print STDERR "LXTokenizerTagger lemmas : ".join(" ", @$lemmas)."\n\n";
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
