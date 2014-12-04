package Treex::Block::Print::VectorsForTM;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';
use Treex::Tool::TranslationModel::Features::Standard;
use Treex::Tool::Triggers::Features;
use Treex::Tool::Coreference::ContentWordFilter;
binmode STDOUT, ':utf8';

has 'trg_lang' => (
    is => 'ro',
    isa => 'Treex::Type::LangCode',
    default => sub { my $self = shift; return $self->language; },
    lazy => 1,
    documentation => 'The target language for a translation model. 
        Parameter "language" should be always set to a language that alignment links in the data come from',
);

has target_features => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print also features from the target language parent node',
);

has czeng_domain => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print also CzEng domain (eu, fiction, subtitles, paraweb, techdoc, news, navajo)',
);

has trigger_features => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Print trigger features',
);

has esa_features => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Print ESA features',
);

has '_content_word_filter' => (
    isa => 'Treex::Tool::Coreference::ContentWordFilter',
    is => 'ro',
    required => 1,
    builder => '_build_content_word_getter',

);
has '_feature_extractor' => (
    isa => 'Treex::Tool::Triggers::Features',
    is => 'ro',
    required => 1,
    builder => '_build_feature_extractor',
);

sub _build_content_word_getter {
    my ($self) = @_;
    return Treex::Tool::Coreference::ContentWordFilter->new();
}
sub _build_feature_extractor {
    my ($self) = @_;
    return Treex::Tool::Triggers::Features->new({
        prev_sents_num => 2,
    });
}

sub process_tnode {
    my ( $self, $ali_src_tnode ) = @_;
    my ($ali_trg_tnodes_rf, $ali_types_rf) = $ali_src_tnode->get_aligned_nodes();
    for my $i (0 .. $#{$ali_trg_tnodes_rf}) {
        my $types = $ali_types_rf->[$i];
        if ($types =~ /int|tali/){
            if ($self->language eq $self->trg_lang) {
                $self->print_tnode_features($ali_trg_tnodes_rf->[$i], $ali_src_tnode, $types);
            }
            else {
                $self->print_tnode_features($ali_src_tnode, $ali_trg_tnodes_rf->[$i], $types);
            }
        }
    }
    return;
}

sub print_tnode_features {
    my ( $self, $src_tnode, $trg_tnode, $ali_types ) = @_;
    my $trg_anode = $trg_tnode->get_lex_anode or return;

    #return if $src_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $src_tlemma = $src_tnode->t_lemma // '';
    my $trg_tlemma = $trg_tnode->t_lemma // '';
    return if $src_tlemma !~ /\p{IsL}/ || $trg_tlemma !~ /\p{IsL}/;
    
    #return if (!$self->_content_word_filter->is_candidate($src_tnode));

    my $features_rf =
        Treex::Tool::TranslationModel::Features::Standard::features_from_src_tnode( $src_tnode, { encode => 1 } ) or return;
    
    # TODO the tag is language dependent
    # Czech uses the first position of the tag
    # other languages use the Interset tag
    my $trg_mlayer_pos;
    if ($self->language eq 'cs') {
        ($trg_mlayer_pos) = ( $trg_anode->tag =~ /^(.)/ );
    } else {
        $trg_mlayer_pos = $trg_anode->iset->pos // "";
    }

    my @add_features = ();

    # target-language features
    if ( $self->target_features ) {
        my ($trg_parent) = $trg_tnode->get_eparents( { or_topological => 1 } );
        my ($src_parent) = $src_tnode->get_eparents( { or_topological => 1 } );
        my ($src_parent2) = $trg_parent->get_aligned_nodes_of_type('int');
        my $edge_aligned = ( $trg_parent->is_root() && $src_parent->is_root() )
            || ( $src_parent2 && $src_parent2 == $src_parent );

        if ( $edge_aligned && $trg_parent->is_root() ) {
            @add_features = qw(TRG_parent_lemma=_ROOT TRG_parent_formeme=_ROOT);
        }
        elsif ($edge_aligned) {
            push @add_features, 'TRG_parent_lemma=' . $trg_parent->t_lemma;
            push @add_features, 'TRG_parent_formeme=' . $trg_parent->formeme;
        }
    }

    # alignment features
    my @gdfa_nodes = $trg_tnode->get_aligned_nodes_of_type('gdfa');
    if (@gdfa_nodes == 1){
        push @add_features, 'ali_int-gdfa=1';
    }
    foreach my $type (split /\./, $ali_types){
        if ($type =~ /int|tali/){
            push @add_features, "ali_$type=1";
        }
    }

    # domain feature
    if ( $self->czeng_domain ) {
        if ( my $domain = $trg_tnode->get_bundle()->attr('czeng/domain') ) {
            push @add_features, "domain=$domain";
        }
    }

    # triggers
    if ($self->trigger_features && $self->_content_word_filter->is_candidate($src_tnode)) {
        my $trig_feats_hash = $self->_feature_extractor->create_lemma_instance($src_tnode);
        unshift @add_features, keys %$trig_feats_hash;
    }
    
    # ESA
    if ($self->esa_features && $self->_content_word_filter->is_candidate($src_tnode)) {
        my $esa_feats_hash = $self->_feature_extractor->create_esa_instance($src_tnode);
        unshift @add_features, keys %$esa_feats_hash;
    }

    say { $self->_file_handle } join "\t", (
        lc($src_tlemma),
        $trg_tlemma . "#" . $trg_mlayer_pos,
        $src_tnode->formeme,
        $trg_tnode->formeme,
        join ' ', @add_features, map {"$_=$features_rf->{$_}"} keys %{$features_rf}
    );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::VectorsForTM - print features for training translation models

=head1 DESCRIPTION

For each node, one line is printed
TODO

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
