package Treex::Block::W2A::TagTreeTagger;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Tagger::TreeTagger;

has model => ( isa => 'Str', is => 'ro', lazy_build => 1 );
has _tagger => ( is => 'ro', lazy_build => 1 );
sub build_language { log_fatal "Language is required"; }

sub _build_model {
    my ($self) = @_;
    my $model = 'data/models/tagger/tree_tagger/' . $self->language . '.par';
    my ($filename) = $self->require_files_from_share($model);
    return $filename;
}

sub _build__tagger {
    my ($self) = @_;
    return Treex::Tool::Tagger::TreeTagger->new( { model => $self->model } );
}

sub BUILD {
    my ($self) = @_;
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms = map { $_->form } $atree->get_descendants();
    my ( $tags, $lemmas );

    # Turns out that the TreeTagger feels uneasy about a sentence of 53,000 tokens...
    my $max_sentence_size = 1000;
    my $sentence_size = scalar(@forms);
    my @tags;
    my @lemmas;
    if ( $sentence_size > $max_sentence_size ) {
        log_info("Sentence contains $sentence_size tokens, applying the TreeTagger per partes.");
        my $n_parts = $sentence_size / $max_sentence_size + 1;
        for ( my $i = 0; $i < $n_parts; $i++ ) {
            my $j0 = $i * $max_sentence_size;
            my $j1 = ($i + 1) * $max_sentence_size - 1;
            $j1 = $#forms if($j1>$#forms);
            my @forms_part = @forms[$j0..$j1];
            my ( $tags_part, $lemmas_part ) = @{ $self->_tagger->analyze( \@forms_part ) };
            push( @tags, @{$tags_part} ) if(defined($tags_part));
            push( @lemmas, @{$lemmas_part} ) if(defined($lemmas_part));
        }
        $tags = \@tags;
        $lemmas = \@lemmas;
    }
    else {
        ( $tags, $lemmas ) = @{ $self->_tagger->analyze( \@forms ) };
    }

    # fill tags and lemmas
    foreach my $a_node ( $atree->get_descendants() ) {
        $a_node->set_tag( shift @$tags );
        $a_node->set_lemma( shift @$lemmas );
    }

    return 1;
}

1;

__END__

=head1 NAME Treex::Block::W2A::TagTreeTageer

=head1 Available pre-trained models

  Model   Language    Encoding
  ------------------------
  bg.par  Bulgarian   utf8
  nl.par  Dutch       latin1
  en.par  English     latin1
  fr.par  French      utf8
  de.par  German      utf8
  el.par  Greek       utf8
  it.par  Italian     utf8
  es.par  Spanish     utf8
  et.par  Estonian    utf8
  sw.par  Swahili     latin1
  la.par  Latin       latin1
  ru.par  Russian     ?

=cut

# Copyright 2010-2011 David Mareček, Martin Popel, Dan Zeman
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
