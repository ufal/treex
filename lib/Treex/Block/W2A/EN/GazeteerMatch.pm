package Treex::Block::W2A::EN::GazeteerMatch;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Gazetteer::Features;
use Treex::Tool::ML::VowpalWabbit::Classifier;

extends 'Treex::Block::W2A::GazeteerMatch';

has 'model_path' => ( is => 'ro', isa => 'Str', default => 'data/models/gazeteer/entity_recognition/en.en_cs.v1.model');
# TODO should implement the Treex::Tool::ML::Classifier interface
has '_model' => ( is => 'ro', isa => 'Treex::Tool::ML::VowpalWabbit::Classifier', builder => '_build_model', lazy => 1 );

my %PHRASE_LIST_PATHS = (
    #'cs' => 'data/models/gazeteer/cs_en/toy.cs_en.en.gaz.gz',
    'cs' => 'data/models/gazeteer/cs_en/20150821_005.IT.cs_en.en.gaz.gz',
    'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.en.gaz.gz',
    'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.en.gaz.gz',
    'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.en.gaz.gz',
    'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.en.gaz.gz',
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->phrase_list_path && defined $self->trg_lang) {
        $self->{phrase_list_path} = $PHRASE_LIST_PATHS{$self->trg_lang};
    }
    return;
}

sub _build_model {
    my ($self) = @_;
    log_info "Loading a model for gazetteer entity recognition from " . $self->model_path . "...";
    return Treex::Tool::ML::VowpalWabbit::Classifier->new({ model_path => $self->model_path });
}

override 'process_start' => sub {
    my ($self) = @_;
    super();
    $self->_model;
};

override 'get_entity_replacement_form' => sub {
    my ($self) = @_;
    return 'item';
};

#override 'score_match' => sub {
#    my ($self, $match) = @_;
#
#    my $feats = Treex::Tool::Gazetteer::Features::extract_feats($match);
#    my $class = $self->_model->predict($feats);
#
#    #print STDERR "GazEntRec: " . $match->[1] . " => " . $class . "\n";
#
#    # 1 = entity / 2 = no entity
#    return $class == 1 ? 1 : 0;
#};

around 'score_match' => sub {
    my ($orig, $self, $match) = @_;

    my $score = $self->$orig($match);

    my @anodes = @{$match->[2]};
    my @forms = map {$_->form} @anodes;

    my $last_menu = ($forms[$#forms] eq "menu") ? -50 : 0;
    $score += $last_menu * (scalar @anodes);
    
    return $score;
};

1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::W2A::EN::GazeteerMatch

=head1 DESCRIPTION

Matching phrases from gazetteers in English.

=head1 PARAMETERS

=head2 trg_lang

Even though this block should be used at the start of the
analysis stage, so far the identifier of the phrase depends
on both the English and the target language. If specified,
a default English phrase list for the given language pair
is loaded.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
