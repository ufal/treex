package Treex::Block::Treelets::AddTwonodeScores;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::TwoNode;
use List::Pairwise qw(mapp);
use Treex::Tool::ML::NormalizeProb;
extends 'Treex::Core::Block';

has model_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has twonode_model => (
    is      => 'ro',
    isa     => 'Str',
    default => 'two-node35k.gz',
);

# has applied_on_src => (
#     is            => 'ro',
#     isa           => 'Bool',
#     default       => 1,
#     documentation => 'In training/extraction scores should be saved to the source (English) t-nodes. In decoding, to the target (Czech) nodes based on src_tnode links.',
# );


has model => (is => 'rw');

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->twonode_model);
    $self->set_model($model);
    return;
}

sub process_tnode {
    my ( $self, $src_node ) = @_;  
    my $trans;
    my $src_lemma      = $src_node->t_lemma;
    my $src_formeme    = $src_node->formeme;
    my $src_parent     = $src_node->get_parent();
    my $src_n_children = $src_parent->get_children();
    my $src_plemma     = $src_parent->t_lemma // '_ROOT'; #/
    my $src_pformeme   = $src_parent->formeme // '_ROOT'; #/

    # L
    $trans = $self->model->model->{$src_lemma.' *'}{'* *'};
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $src_node->wild->{lscore}{$lemma}{L} += $b;
        } @$trans;
    }
    
    # F
    $trans = $self->model->model->{'* '.$src_formeme}{'* *'};
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $src_node->wild->{fscore}{$formeme}{F} += $b;
        } @$trans;
    }

    # LF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{'* *'};
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $src_node->wild->{lscore}{$lemma}{Lf} += $b;
            $src_node->wild->{fscore}{$formeme}{lF} += $b;
        } @$trans;
    }

    # *FL
    $trans = $self->model->model->{'* '.$src_formeme}{$src_plemma.' *'};
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $src_node->wild->{fscore}{$formeme}{xFl} += $b;
            $src_parent->wild->{lscore}{$plemma}{xfL} += $b / $src_n_children;
        } @$trans;
    }

    # LFL
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$src_plemma.' *'};
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $src_node->wild->{lscore}{$lemma}{Lfl} += $b;
            $src_node->wild->{fscore}{$formeme}{lFl} += $b;
            $src_parent->wild->{lscore}{$plemma}{lfL} += $b / $src_n_children;
        } @$trans;
    }

    # *FLF
    $trans = $self->model->model->{'* '.$src_formeme}{$src_plemma.' '.$src_pformeme};
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $src_node->wild->{fscore}{$formeme}{xFlf} += $b;
            $src_parent->wild->{lscore}{$plemma}{xfLf} += $b / $src_n_children;
            $src_parent->wild->{fscore}{$pformeme}{xflF} += $b / $src_n_children;
        } @$trans;
    }

    # LFLF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$src_plemma.' '.$src_pformeme};
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $src_node->wild->{lscore}{$lemma}{Lflf} += $b;
            $src_node->wild->{fscore}{$formeme}{lFlf} += $b;
            $src_parent->wild->{lscore}{$plemma}{lfLf} += $b / $src_n_children;
            $src_parent->wild->{fscore}{$pformeme}{lflF} += $b / $src_n_children;
        } @$trans;
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Treelets::AddTwonodeScores - add lemma&formeme translation scores based on "TwoNode" models

=head1 DESCRIPTION

Possible translations are added to the B<SOURCE> t-nodes, to the wild attributes C<lscore> and C<fscore>.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
