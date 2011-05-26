package Treex::Block::W2A::TagTreeTagger;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tools::Tagger::TreeTagger;

has model => ( isa => 'Str', is => 'ro', lazy_build => 1 );
has _tagger => ( is => 'ro', lazy_build => 1 );
sub build_language { log_fatal "Language is required"; }

sub _build_model {
    my ($self) = @_;
    my $model = 'data/models/tagger/tree_tagger/' . $self->language . '.par';
    $self->require_files_from_share($model);
    return "$ENV{TMT_ROOT}/share/$model";
}

sub _build__tagger {
    my ($self) = @_;
    return Treex::Tools::Tagger::TreeTagger->new( { model => $self->model } );
}

sub BUILD {
    my ($self) = @_;
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms = map { $_->form } $atree->get_descendants();
    my ( $tags, $lemmas ) = @{ $self->_tagger->analyze( \@forms ) };

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
  bg.par  Bulagarian  utf8
  nl.par  Dutch       latin1
  en.par  English     latin1
  fr.par  French      utf8
  el.par  Greek       utf8
  it.par  Italian     utf8
  es.par  Spanish     utf8
  et.par  Estonian    utf8
  sw.par  Swahili     latin1
  la.par  Latin       latin1
  ru.par  Russian     ?

=cut

# Copyright 2010-2011 David Marecek, Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
