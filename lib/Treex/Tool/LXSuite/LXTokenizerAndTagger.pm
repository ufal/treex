package Treex::Tool::LXSuite::LXTokenizerAndTagger;
use Treex::Core::Log;
use Moose;
extends 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (default => 'plain:tokenizer_tagger:conll.pos');

sub tokenize_and_tag {
    my ( $self, $sentence ) = @_;

    my $forms    = [];
    my $lemmas   = [];
    my $postags  = [];
    my $cpostags = [];
    my $feats    = [];

    if ( $sentence !~ /^\s*$/ ) { # if sentence has non-space characters
        $self->write($sentence);
        $self->write();
        # Create a-nodes and detect the no_space_after attribute.
        my $line = $self->read();
        while ($line ne '') {
            my ($id, $form, $lemma, $postag, $cpostag, $feat) = split(/\t/, $line);
             push @$forms,    $form;
             push @$lemmas,   $lemma;
             push @$postags,  $postag;
             push @$cpostags, $cpostag;
             push @$feats,    $feat;
             $line = $self->read();
        }
    }
    return ($forms, $lemmas, $postags, $cpostags, $feats);
}

1;

__END__

=head1 NAME

Treex::Tool::LXSuite::LXTokenizerAndTagger

=head1 SYNOPSIS

my $tt = Treex::Tool::Tagger::LXTokenizerAndTagger->new();
my ( $forms, $lemmas, $postags, $cpostags, $feats ) = $tt->tokenize_and_tag_sentence($sentence);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
