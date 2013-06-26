package Treex::Block::Treelets::TrInterpol;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::TwoNode;
use List::Pairwise qw(mapp);
use ProbUtils::Normalize;
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

has [qw(wL wF wLF wxFL wLFL wxFLF wLFLF)] => (is=>'rw', default=>1);
my ($wL, $wF,$wLf,  $wlF, $wxFl, $wxfL, $wLfl,  $wlFl,  $wlfL, $wxFlf, $wxfLf, $wxflF, $wLflf,  $wlFlf,  $wlfLf, $wlflF);

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    return;
}

my ($LSCORE, $FSCORE, $LSUM, $FSUM, $LNOTE, $FNOTE) = (0..5);
my %scores;

sub process_ttree {
    my ( $self, $tree ) = @_;
    
    $wL = $self->wL;
    $wF = $self->wF;
    ($wLf,  $wlF)  = ($self->wLF)x2;
    ($wxFl, $wxfL) = ($self->wxFL)x2;
    ($wLfl,  $wlFl,  $wlfL)  = ($self->wLFL)x3;
    ($wxFlf, $wxfLf, $wxflF) = ($self->wxFLF)x3;
    ($wLflf,  $wlFlf,  $wlfLf, $wlflF)  = ($self->wLFLF)x4;
    
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
    #my $src_lemma   = $src_node->t_lemma;
    #my $src_formeme = $src_node->formeme;
    my $src_lemma   = $node->t_lemma;
    my $src_formeme = $node->formeme;
    
    # L
    $trans = $self->model->model->{$src_lemma.' *'}{'* *'};
    $scores{$node}[$LSUM] += $wL;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $wL*$b;
            $scores{$node}[$LSCORE]{$lemma}{L} += $b;
        } @$trans;
    }
    
    # F
    $trans = $self->model->model->{'* '.$src_formeme}{'* *'};
    $scores{$node}[$FSUM] += $wF;
    if ($trans){
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wF*$b;
            $scores{$node}[$FSCORE]{$formeme}{F} += $b;
        } @$trans;
    }

    # LF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{'* *'};
    $scores{$node}[$LSUM] += $wLf;
    $scores{$node}[$FSUM] += $wlF;
    if ($trans){
        my $first_label = $trans->[0];
        my ($lemma, $formeme) = split / /, $first_label;
        mapp {
            my ($lemma, $formeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $wLf*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lf} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wlF*$b;
            $scores{$node}[$FSCORE]{$formeme}{lF} += $b;
        } @$trans;
    }

    my $parent         = $node->get_parent();
    my $src_parent     = $src_node->get_parent();
    #my $parent_lemma   = $src_parent->t_lemma // '_ROOT'; #/
    #my $parent_formeme = $src_parent->formeme // '_ROOT'; #/
    my $parent_lemma   = $parent->t_lemma // '_ROOT'; #/
    my $parent_formeme = $parent->formeme // '_ROOT'; #/

    # *FL
    $trans = $self->model->model->{'* '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$FSUM] += $wxFl;
    $scores{$parent}[$LSUM] += $wxfL;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wxFl*$b;
            $scores{$node}[$FSCORE]{$formeme}{'*Fl'} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $wxfL*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"*fL($src_formeme)"} += $b;
        } @$trans;
    }

    # LFL
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$parent_lemma.' *'};
    $scores{$node}[$LSUM] += $wLfl;
    $scores{$node}[$FSUM] += $wlFl;
    $scores{$parent}[$LSUM] += $wlfL;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $wLfl*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lfl} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wlFl*$b;
            $scores{$node}[$FSCORE]{$formeme}{lFl} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $wlfL*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"lfL($src_lemma,$src_formeme)"} += $b;
        } @$trans;
    }

    # *FLF
    $trans = $self->model->model->{'* '.$src_formeme}{$parent_lemma.' '.$parent_formeme};
    $scores{$node}[$FSUM] += $wxFlf;
    $scores{$parent}[$LSUM] += $wxfLf;
    $scores{$parent}[$FSUM] += $wxflF;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wxFlf*$b;
            $scores{$node}[$FSCORE]{$formeme}{'*Flf'} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $wxfLf*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"*fLf($src_formeme)"} += $b;
            $scores{$parent}[$FSCORE]{$pformeme}{_} += $wxflF*$b;
            $scores{$parent}[$FSCORE]{$pformeme}{"*flF($src_formeme)"} += $b;
        } @$trans;
    }

    # LFLF
    $trans = $self->model->model->{$src_lemma.' '.$src_formeme}{$parent_lemma.' '.$parent_formeme};
    $scores{$node}[$LSUM] += $wLflf;
    $scores{$node}[$FSUM] += $wlFlf;
    $scores{$parent}[$LSUM] += $wlfLf;
    $scores{$parent}[$FSUM] += $wlflF;
    if ($trans){
        mapp {
            my ($lemma, $formeme, $plemma, $pformeme) = split / /, $a;
            $scores{$node}[$LSCORE]{$lemma}{_} += $wLflf*$b;
            $scores{$node}[$LSCORE]{$lemma}{Lflf} += $b;
            $scores{$node}[$FSCORE]{$formeme}{_} += $wlFlf*$b;
            $scores{$node}[$FSCORE]{$formeme}{lFlf} += $b;
            $scores{$parent}[$LSCORE]{$plemma}{_} += $wlfLf*$b;
            $scores{$parent}[$LSCORE]{$plemma}{"lfLf($src_lemma,$src_formeme)"} += $b;
            $scores{$parent}[$FSCORE]{$pformeme}{_} += $wlflF*$b;
            $scores{$parent}[$FSCORE]{$pformeme}{"lflF($src_lemma,$src_formeme)"} += $b;
        } @$trans;
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Treelets::TrInterpol - translate lemmas and formemes using interpolation of "TwoNode" models

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
