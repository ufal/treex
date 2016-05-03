package Treex::Block::W2A::HideGazeteerItems;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Treex::Tool::Gazetteer::Engine;

extends 'Treex::Core::Block';

has 'trg_lang' => ( is => 'ro', isa => 'Str' );

has 'phrase_list_path' => ( is => 'ro', isa => 'Str' );
# idx removed: libreoffice_16090, libreoffice_16123, libreoffice_73656
has '_gazeteer_hash' => ( is => 'ro', isa => 'Treex::Tool::Gazetteer::Engine', builder => '_build_gazeteer_hash', lazy => 1 );

my %OTHERLANG_PHRASE_LIST_PATHS = (
    #'cs' => 'data/models/gazeteer/cs_en/toy.cs_en.cs.gaz.gz',
    'cs' => 'data/models/gazeteer/cs_en/20151009_007.IT.cs_en.cs.gaz.gz',
    'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.es.gaz.gz',
    'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.eu.gaz.gz',
    'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.nl.gaz.gz',
    'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.pt.gaz.gz',
);
my %EN_PHRASE_LIST_PATHS = (
    'cs' => 'data/models/gazeteer/cs_en/20151009_007.IT.cs_en.en.gaz.gz',
    'es' => 'data/models/gazeteer/es_en/20150821_002.IT.es_en.en.gaz.gz',
    'eu' => 'data/models/gazeteer/eu_en/20150821_002.IT.eu_en.en.gaz.gz',
    'nl' => 'data/models/gazeteer/nl_en/20150821_004.IT.nl_en.en.gaz.gz',
    'pt' => 'data/models/gazeteer/pt_en/20150821_002.IT.pt_en.en.gaz.gz',
);

my @alphabet = ("aa".."zz");

sub BUILD {
    my ($self) = @_;
    if (!defined $self->phrase_list_path && defined $self->trg_lang) {
        if ($self->trg_lang eq "en") {
            $self->{phrase_list_path} = $EN_PHRASE_LIST_PATHS{$self->language};
        }
        else {
            $self->{phrase_list_path} = $OTHERLANG_PHRASE_LIST_PATHS{$self->trg_lang};
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

sub process_atree {
    my ($self, $a_root) = @_;

    my @anodes = grep { defined $_->wild->{gazeteer_entity_id} } $a_root->get_descendants();
    my %gazeteer_translations;
    for (my $i = 0; $i < @anodes; $i++) {
        my $key = 'xxx' . 'item' . $alphabet[$i] . 'xxx';
        $gazeteer_translations{$key} = $self->hide_gazeteer($anodes[$i], $key);
    }
    $a_root->get_bundle()->wild->{gazeteer_translations} = \%gazeteer_translations;

    return;
}

sub hide_gazeteer {
    my ($self, $anode, $key) = @_;

    my $id_list = $anode->wild->{gazeteer_entity_id};
    my $phrase_list = $anode->wild->{matched_item};

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
    
    my $translation = join " ", @translated_phrases;
    $anode->wild->{gazeteer_translation} = $translation;
    $anode->set_form($key);
    $anode->set_lemma($key);
    $anode->set_no_space_after(0);
    my $prev_node = $anode->get_prev_node();
    if (defined $prev_node) {
        $prev_node->set_no_space_after(0);
    }
    return $translation;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::HideGazeteerItems

=head1 DESCRIPTION

Based on L<Treex::Block::T2T::HideGazeteerItems> but operating on a-layer, not t-layer.

Translation of gazeteer items. Load the gazeteer for the target language and look up the translation by its id.

The original form is hidden by a placeholder such as C<xxxitemaaxxx>, and the translation is stored into a wild attribute called C<gazeteer_translation>.
Also, all of the translations are stored in a hash in a bundle wild attribute called C<gazeteer_translations>; the keys are the placeholders.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
