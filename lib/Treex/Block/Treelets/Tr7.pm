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
        foreach my $lemma (sort {$sc->[$LSCORE]{$b} <=> $sc->[$LSCORE]{$a}} keys %{$sc->[$LSCORE]}){
            my $l = $lemma;
            $l =~ s/#(.)$//;
            push @lvar, {
                't_lemma' => $l,
                'pos'     => $1,
                'origin'  => $sc->[$LNOTE]{$lemma},
                'logprob' => ProbUtils::Normalize::prob2binlog($sc->[$LSCORE]{$lemma} / $lsum),
            };
        }
        if (@lvar){
            $node->set_attr('translation_model/t_lemma_variants', \@lvar);
            $node->set_t_lemma($lvar[0]{t_lemma});
            $node->set_t_lemma_origin($lvar[0]{origin});
            $node->set_attr('mlayer_pos', $lvar[0]{'pos'});
        }
        foreach my $formeme (sort {$sc->[$FSCORE]{$b} <=> $sc->[$FSCORE]{$a}} keys %{$sc->[$FSCORE]}){
            push @fvar, {
                'formeme' => $formeme,
                'origin'  => $sc->[$FNOTE]{$formeme},
                'logprob' => ProbUtils::Normalize::prob2binlog($sc->[$FSCORE]{$formeme} / $fsum),
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
      
    my $src_lemma   = $src_node->t_lemma;
    my $src_formeme = $src_node->formeme;
    
    my (%transL, %transF, $trans);
   
    # L
    $trans = $self->model->model->{$src_lemma.' *'}{'* *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma} += $WEIGHT*$b;
            $scores{$node}[$LNOTE]{$lemma} .= "L=$b ";
        } @$trans;
    }
    
    # F
    $trans = $self->model->model->{'* '.$src_formeme}{'* *'};
    $scores{$node}[$FSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "F=$b ";
        } @$trans;
    }

    return;
}

1;

__END__

    # LF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{'* *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    $scores{$node}[$FSUM] += $WEIGHT;
    if ($trans){
        my $first_label = $trans->[0];
        my ($lemma, $formeme) = split / /, $first_label;
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma} += $WEIGHT*$b;
            $scores{$node}[$LNOTE]{$lemma} .= "Lf=$b ";
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "lF=$b ";
        } @$trans;
    }

    my $parent         = $node->get_parent();
    my $src_parent     = $src_node->get_parent();
    my $parent_lemma   = $src_parent->t_lemma // '_ROOT'; #/
    my $parent_formeme = $src_parent->formeme // '_ROOT'; #/
    
    # LFL*
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$LSUM] += $WEIGHT;
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma} += $WEIGHT*$b;
            $scores{$node}[$LNOTE]{$lemma} .= "Lfl=$b ";
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "lFl=$b ";
            $scores{$parent}[$LSCORE]{$plemma} += $WEIGHT*$b;
            $scores{$parent}[$LNOTE]{$plemma} .= "lfL=$b ";
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
            $scores{$node}[$LSCORE]{$lemma} += $WEIGHT*$b;
            $scores{$node}[$LNOTE]{$lemma} .= "Lflf=$b ";
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "lFlf=$b ";
            $scores{$parent}[$LSCORE]{$plemma} += $WEIGHT*$b;
            $scores{$parent}[$LNOTE]{$plemma} .= "lfLf=$b ";
            $scores{$parent}[$FSCORE]{$pformeme} += $WEIGHT*$b;
            $scores{$parent}[$FNOTE]{$pformeme} .= "lflF=$b ";
        } @$trans;
    }

    # *FL*
    $trans = $self->model->model->{'* '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$FSUM] += $WEIGHT;
    $scores{$parent}[$LSUM] += $WEIGHT;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "*Fl*=$b ";
            $scores{$parent}[$LSCORE]{$plemma} += $WEIGHT*$b;
            $scores{$parent}[$LNOTE]{$plemma} .= "*fL*=$b ";
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
            $scores{$node}[$FSCORE]{$formeme} += $WEIGHT*$b;
            $scores{$node}[$FNOTE]{$formeme} .= "*Flf=$b ";
            $scores{$parent}[$LSCORE]{$plemma} += $WEIGHT*$b;
            $scores{$parent}[$LNOTE]{$plemma} .= "*fLf=$b ";
            $scores{$parent}[$FSCORE]{$pformeme} += $WEIGHT*$b;
            $scores{$parent}[$FNOTE]{$pformeme} .= "*flF=$b ";
        } @$trans;
    }


=encoding utf-8

=head1 NAME

Treex::Block::Treelets::TrOneNodeNeedsCopyTtree - translate lemmas and formemes using "OneNode" model

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
