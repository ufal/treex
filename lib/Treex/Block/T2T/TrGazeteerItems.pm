package Treex::Block::T2T::TrGazeteerItems;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Treex::Tool::Gazetteer::Engine;

extends 'Treex::Core::Block';

has 'src_lang' => ( is => 'ro', isa => 'Str' );

has 'phrase_list_path' => ( is => 'ro', isa => 'Str' );
# idx removed: libreoffice_16090, libreoffice_16123, libreoffice_73656
has '_gazeteer_hash' => ( is => 'ro', isa => 'Treex::Tool::Gazetteer::Engine', builder => '_build_gazeteer_hash', lazy => 1 );

my %OTHERLANG_PHRASE_LIST_PATHS = (
    #'cs' => 'data/models/gazeteer/cs_en/toy.cs_en.cs.gaz.gz',
    'cs' => 'data/models/gazeteer/cs_en/20150926_006.IT.cs_en.cs.gaz.gz',
    'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.es.gaz.gz',
    'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.eu.gaz.gz',
    'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.nl.gaz.gz',
    'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.pt.gaz.gz',
);
my %EN_PHRASE_LIST_PATHS = (
    'cs' => 'data/models/gazeteer/cs_en/20150926_006.IT.cs_en.en.gaz.gz',
    'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.en.gaz.gz',
    'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.en.gaz.gz',
    'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.en.gaz.gz',
    'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.en.gaz.gz',
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->phrase_list_path && defined $self->src_lang) {
        if ($self->src_lang eq "en") {
            $self->{phrase_list_path} = $OTHERLANG_PHRASE_LIST_PATHS{$self->language};
        }
        else {
            $self->{phrase_list_path} = $EN_PHRASE_LIST_PATHS{$self->src_lang};
        }
    }
}

sub _build_gazeteer_hash {
    my ($self) = @_;
    my $hash = Treex::Tool::Gazetteer::Engine->new({ is_src => 0, path => $self->phrase_list_path });
    return $hash;
}

sub process_start {
    my ($self) = @_;
    $self->_gazeteer_hash;
}

sub process_tnode {
    my ($self, $tnode) = @_;

    my $src_tnode = $tnode->src_tnode;

    my $id_list = $src_tnode->wild->{gazeteer_entity_id};
    my $phrase_list = $src_tnode->wild->{matched_item};
    return if (!defined $id_list);

    my @translated_phrases = ();

    for (my $i = 0; $i < @$id_list; $i++) {
        my $id = $id_list->[$i];
        my $phrase = $phrase_list->[$i]; 
        my $translated_phrase;
        if ($id eq "__PUNCT__") {
            $translated_phrase = $phrase;
        }
        else {
            $translated_phrase = $self->_gazeteer_hash->get_phrase_by_id($id);
        }
        if (!defined $translated_phrase) {
            # this should not happen
            log_warn "Gazetteer in " . $self->phrase_list_path . " does not contain the following id: " . $id;
        }
        push @translated_phrases, $translated_phrase;
    }
    
    $tnode->wild->{gazeteer_entity_id} = $id_list;
    $tnode->wild->{matched_item} = \@translated_phrases;
    $tnode->set_t_lemma(join " ", @translated_phrases);
    $tnode->set_t_lemma_origin('lookup-TrGazeteerItems');
}

1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::T2T::TrGazeteerItems

=head1 DESCRIPTION

Translation of gazeteer items. Load the gazeteer for the target language and look up the translation by its id.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
