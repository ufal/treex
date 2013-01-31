package Treex::Block::T2T::TrTwoNode;
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

has target_language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has target_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    return;
}

sub process_ttree {
    my ( $self, $src_root ) = @_;
    my $trg_zone = $src_root->get_bundle()->get_or_create_zone( $self->target_language, $self->target_selector );
    my $trg_root = $trg_zone->create_ttree( { overwrite => 1 } );
    $trg_root->set_attr( 'atree.rf', undef );
    my %aligned = ($src_root=>$trg_root);
    
    my @queue = ($src_root);
    while(@queue){
        my $src_node = shift @queue;
        my @src_children = $src_node->get_children();
        next if !@src_children;
        my $trg_node = $aligned{$src_node};
        foreach my $src_child (@src_children){
            my $trg_child = $trg_node->create_child({ord=>$src_child->ord});
            $self->translate_node($src_child, $trg_child);
            $aligned{$src_child} = $trg_child;
            $src_child->add_aligned_node($trg_child, 'int');
            $trg_child->set_src_tnode($src_child);
            push @queue, $src_child;
        }
    }
    
    return;
}


sub translate_node {
    my ( $self, $src_node, $node ) = @_;
    my $src_lemma   = $src_node->t_lemma;
    my $src_formeme = $src_node->formeme;
    my $trans = $self->model->model->{$src_lemma.'|'.$src_formeme}{_NO};
    if ($trans){
        my $first_label = $trans->[0];
        my ($lemma, $formeme) = split /\|/, $first_label;
        $node->set_t_lemma($lemma);
        $node->set_t_lemma_origin('two-node-LF');
        $node->set_formeme($formeme);
        $node->set_formeme_origin('two-node-LF');
    } else {
    
        # lemma
        $trans = $self->model->model->{$src_lemma.'|*'}{_NO};
        if ($trans){
            my $first_label = $trans->[0];
            my ($lemma, $formeme) = split /\|/, $first_label;
            $node->set_t_lemma($lemma);
            $node->set_t_lemma_origin('two-node');
        } else {
            $node->set_t_lemma($src_node->t_lemma);
            $node->set_t_lemma_origin('clone');
        }
        
        # formeme
        $trans = $self->model->model->{'*|'.$src_formeme}{_NO};
        if ($trans){
            my $first_label = $trans->[0];
            my ($lemma, $formeme) = split /\|/, $first_label;
            $node->set_formeme($formeme);
            $node->set_formeme_origin('two-node');
        } else {
            $node->set_formeme($src_node->formeme);
            $node->set_formeme_origin('clone');
        }
    }
    
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrTwoNode - translate lemmas and formemes using "TwoNode" model

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
