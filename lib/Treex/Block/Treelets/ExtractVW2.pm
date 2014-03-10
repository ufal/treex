package Treex::Block::Treelets::ExtractVW2;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use TranslationModel::Static::Model;
use Treex::Block::Treelets::SrcFeatures2;

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has static_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tlemma_czeng09.static.pls.slurp.gz',
);

has max_variants => (
    is            => 'ro',
    isa           => 'Int',
    default       => 50,
    documentation => 'Maximal number of translation options for each lemma'
);


my $static;
my $src_feature_extractor;

sub load_model {
    my ( $self, $model, $filename ) = @_;
    my $path = $self->model_dir . '/' . $filename;
    $model->load( Treex::Core::Resource::require_file_from_share($path) );
    return $model;
}

sub process_start {
    my ($self) = @_;
    $self->SUPER::process_start();
    $static = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model );
    $src_feature_extractor = Treex::Block::Treelets::SrcFeatures2->new();
    $src_feature_extractor->_set_static($static);
    return;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    my ($en_tnodes_rf, $ali_types_rf) = $cs_tnode->get_aligned_nodes();
    for my $i (0 .. $#{$en_tnodes_rf}) {
        my $types = $ali_types_rf->[$i];
        if ($types =~ /int|tali/){
            $self->print_tnode_features($cs_tnode, $en_tnodes_rf->[$i], $types);
        }
    }
    return;
}

sub print_tnode_features {
    my ( $self, $cs_tnode, $en_tnode, $ali_types ) = @_;
    my $en_tlemma = lemma($en_tnode);
    my $en_formeme = $en_tnode->formeme;
    my $cs_tlemma = lemmapos($cs_tnode);
    return if $en_tlemma !~ /\p{IsL}/;

    # VW format does not allow ":", "|" and spaces in feature names
    $en_tlemma  =~ tr/:| /;!_/;
    $en_formeme =~ tr/:| /;!_/;
    $cs_tlemma  =~ tr/:| /;!_/;
    
    # Do not train on instances where the correct translation is not listed in the TwoNode model
    my $variants = $en_tnode->wild->{lscore};

    # VW loss should be comparable over experiments
    if (!$variants || !$variants->{$cs_tlemma}){

        # If tag starts with "save", VW will save the regressor (model).
        # To switch this feature off, we prefix all tags with "_".
        my $tag = $variants ? "$en_tlemma^$cs_tlemma" : $en_tlemma;
        # Words that should not be translated should be considered as plus points (cost=0).
        # $cs_tlemma has an extra #mlayer_pos info, so let's use regex.
        my $cost = $cs_tlemma =~ /^\Q$en_tlemma\E#.$/ ? 0 : 1;
        print  { $self->_file_handle() } "1:$cost _$tag| nochance\n\n";
        return;
    }
    
    # Features from the local tree (and word-order) context this node
    my $src_context_feats = $src_feature_extractor->features_of_tnode($en_tnode);


    my @translations = map {$_->[0]} sort {$b->[1] <=> $a->[1]} map {[$_, $self->prescore($variants->{$_})]} keys %{$variants};
    splice @translations, $self->max_variants if @translations > $self->max_variants;
    
    # VW LDF (label-dependent features) format output
    print { $self->_file_handle() } "shared |S $src_context_feats\n";
    my ($i);
    #while ( my ($variant, $variant_static_score) = each %{$submodel}){
    for my $variant (@translations) {
        $i++;
        $variant =~ tr/:| /;!_/;
        my $cost = $variant eq $cs_tlemma ? 0 : 1;

        # Target-partial features
        # Default for t_lemma="#PersPron" (dropped)
        my $variant_pos = ($variant =~ /#(.)$/) ? $1 : 'X';
        # Todo: add verbal aspect

        print { $self->_file_handle() } "$i:$cost _$variant|T $en_tlemma^$variant |P $en_tlemma^$en_formeme^$variant_pos\n";
    }
    print { $self->_file_handle() } "\n";
    return;
}

sub prescore {
    my ($self, $scores) = @_;
    # TODO: use different weights for L,F,Lf,Lf,Lfl,...
    my $sum = 0;
    for my $score (values %{$scores}){
        $sum += $score;
    }
    return $sum
}

# Hack to include coarse-grained PoS tag for Czech lemma.
# $tnode->get_attr('mlayer_pos') is not filled in CzEng
sub lemmapos {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    my $anode = $tnode->get_lex_anode or return $lemma;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    return $lemma if !defined $pos;
    return "$lemma#$pos";
}

# For English
sub lemma {
    my ($tnode) = @_;
    my $lemma = $tnode->t_lemma // ''; #/
    $lemma =~ s/ /&#32;/g;
    return $lemma;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::ExtractVW2 - extract translation training vectors for VW

=head1 DESCRIPTION

Extract translation training vectors for Vowbal Wabbit in the csoaa_ldf=mc format.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
