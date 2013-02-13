package Treex::Block::Treelets::Tr7;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::TwoNode;
use List::Pairwise qw(mapp);
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
    default => 'two-node35k.gz',
);

has model => (is => 'rw');


sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    return;
}

use ProbUtils::Normalize;
my $WEIGHT = 1;
my ($LSCORE, $FSCORE, $LSUM, $FSUM, $LNOTE, $FNOTE) = (0..5);
my %scores;

sub process_ttree {
    my ( $self, $tree ) = @_;
    %scores = ();
    my @nodes = $tree->get_descendants();
    foreach my $node (@nodes){
        $self->process_tnode($node);
    }

    
    foreach my $node (@nodes){
        my $sc = $scores{$node};
        my $lsum = $sc->[$LSUM];
        my $fsum = $sc->[$FSUM];
        my (@lvar, @fvar);
        foreach my $lemma (sort {$sc->[$LSCORE]{$b}{_} <=> $sc->[$LSCORE]{$a}{_}} keys %{$sc->[$LSCORE]}){
            my $entry = $sc->[$LSCORE]{$lemma};
            my $score = delete $entry->{_};
            my $l = $lemma;
            $l =~ s/#(.)$//;
            my $origin = join ' ', map {$_.'='.$entry->{$_}} sort {$entry->{$b} <=> $entry->{$a}} keys %{$entry};
            push @lvar, {
                't_lemma' => $l,
                'pos'     => $1,
                'origin'  => $origin,
                'logprob' => ProbUtils::Normalize::prob2binlog($score / $lsum),
            };
        }
        if (@lvar){
            $node->set_attr('translation_model/t_lemma_variants', \@lvar);
            $node->set_t_lemma($lvar[0]{t_lemma});
            $node->set_t_lemma_origin($lvar[0]{origin});
            $node->set_attr('mlayer_pos', $lvar[0]{'pos'});
        }
        foreach my $formeme (sort {$sc->[$FSCORE]{$b}{_} <=> $sc->[$FSCORE]{$a}{_}} keys %{$sc->[$FSCORE]}){
            my $entry = $sc->[$FSCORE]{$formeme};
            my $score = delete $entry->{_};
            my $origin = join ' ', map {$_.'='.$entry->{$_}} sort {$entry->{$b} <=> $entry->{$a}} keys %{$entry};
            push @fvar, {
                'formeme' => $formeme,
                'origin'  => $origin,
                'logprob' => ProbUtils::Normalize::prob2binlog($score / $fsum),
            };
        }
        if (@fvar){
            $node->set_attr('translation_model/formeme_variants', \@fvar);
            $node->set_formeme($fvar[0]{formeme});
            $node->set_formeme_origin($fvar[0]{origin});
        }                
    }
    return;
}




sub process_tnode {
    my ( $self, $node ) = @_;

    # Skip nodes that were already translated by rules
    return if $node->t_lemma_origin ne 'clone';
    my $src_node = $node->src_tnode;
    return if !$src_node;
    
    my $trans;
    my $src_lemma   = $src_node->t_lemma;
    my $src_formeme = $src_node->formeme;
    
    # L
    $trans = $self->model->model->{$src_lemma.' *'}{'* *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $WEIGHT*$b;
            $scores{$node}[$LSCORE]{$lemma}{L} += $b;
        } @$trans;
    }
    
    # F
    $trans = $self->model->model->{'* '.$src_formeme}{'* *'};
    $scores{$node}[$FSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{F} += $b;
        } @$trans;
    }

    # LF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{'* *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    $scores{$node}[$FSUM] += $WEIGHT;
    if ($trans){
        my $first_label = $trans->[0];
        my ($lemma, $formeme) = split / /, $first_label;
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $WEIGHT*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lf} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{lF} += $b;
        } @$trans;
    }

    my $parent         = $node->get_parent();
    my $src_parent     = $src_node->get_parent();
    my $parent_lemma   = $src_parent->t_lemma // '_ROOT'; #/
    my $parent_formeme = $src_parent->formeme // '_ROOT'; #/

    # *FL
    $trans = $self->model->model->{'* '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{'*Fl'} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $WEIGHT*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"*fL($src_formeme)"} += $b;
        } @$trans;
    }

    # LFL
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $WEIGHT*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lfl} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{lFl} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $WEIGHT*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"lfL($src_lemma,$src_formeme)"} += $b;
        } @$trans;
    }

    # *FLF
    $trans = $self->model->model->{'* '.$src_formeme}{$parent_lemma.' '.$parent_formeme};
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    $scores{$parent}[$FSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{'*Flf'} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $WEIGHT*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"*fLf($src_formeme)"} += $b;
            $scores{$parent}[$FSCORE]{$pformeme}{_} += $WEIGHT*$b;
            $scores{$parent}[$FSCORE]{$pformeme}{"*flF($src_formeme)"} += $b;
        } @$trans;
    }

    # LFLF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$parent_lemma.' '.$parent_formeme};
    $scores{$node}[$LSUM] += $WEIGHT;
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    $scores{$parent}[$FSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $WEIGHT*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lflf} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $WEIGHT*$b;
            $scores{$node}[$FSCORE]{$formeme}{lFlf} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $WEIGHT*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"lfLf($src_lemma,$src_formeme)"} += $b;
            $scores{$parent}[$FSCORE]{$pformeme}{_} += $WEIGHT*$b;
            $scores{$parent}[$FSCORE]{$pformeme}{"lflF($src_lemma,$src_formeme)"} += $b;
        } @$trans;
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
