package Treex::Block::Treelets::TrOneNodeNeedsCopyTtree;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::TwoNode;
#use Treex::Core::Resource;
extends 'Treex::Core::Block';

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has model_name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'two-node-pokus.gz',
);

has model => (is => 'rw');


sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    return;
}


sub process_tnode {
    my ( $self, $node ) = @_;

    # Skip nodes that were already translated by rules
    return if $node->t_lemma_origin ne 'clone';
    my $src_node = $node->src_tnode;
    return if !$src_node;
      
    my $src_lemma   = $src_node->t_lemma;
    my $src_formeme = $src_node->formeme;
    my $trans = $self->model->model->{$src_lemma.'|'.$src_formeme}{_NO};
    if ($trans){
        my $first_label = $trans->[0];
        my ($lemma, $formeme) = split /\|/, $first_label;
        $node->set_attr('mlayer_pos', $1) if $lemma =~ s/#(.)$//;
        $node->set_t_lemma($lemma);
        $node->set_t_lemma_origin('one-node-LF');
        $node->set_formeme($formeme);
        $node->set_formeme_origin('one-node-LF');
    } else {
        $trans = $self->model->model->{$src_lemma.'|*'}{_NO};
        if ($trans){
            my $first_label = $trans->[0];
            my ($lemma, $formeme) = split /\|/, $first_label;
            $node->set_attr('mlayer_pos', $1) if $lemma =~ s/#(.)$//;
            $node->set_t_lemma($lemma);
            $node->set_t_lemma_origin('one-node');
        }
        $trans = $self->model->model->{'*|'.$src_formeme}{_NO};
        if ($trans){
            my $first_label = $trans->[0];
            my ($lemma, $formeme) = split /\|/, $first_label;
            $node->set_formeme($formeme);
            $node->set_formeme_origin('one-node');
        }
    }
    
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Treelets::TrOneNodeNeedsCopyTtree - translate lemmas and formemes using "OneNode" model

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
