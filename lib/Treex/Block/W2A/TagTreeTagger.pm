package Treex::Block::W2A::TagTreeTagger;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::TreeTagger;

extends 'Treex::Block::W2A::Tag';

has model => ( isa => 'Str', is => 'ro', lazy_build => 1 );

sub _build_model {
    my ($self) = @_;
    log_fatal "W2A::TagTreeTagger requires parameter model (or at least language)" if !$self->language || $self->language eq 'all';
    my $model = 'data/models/tagger/tree_tagger/' . $self->language . '.par';
    my ($filename) = $self->require_files_from_share($model);
    return $filename;
}

sub _build_tagger{
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    return Treex::Tool::Tagger::TreeTagger->new($self->_args);
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
  ru.par  Russian     utf8
# TODO: Russian tagger seems to have problems if "ё" is replaced by "е" (noticed only on pronouns: "свое" and "ее")

=cut

# Copyright 2010-2011 David Mareček, Martin Popel, Dan Zeman
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
