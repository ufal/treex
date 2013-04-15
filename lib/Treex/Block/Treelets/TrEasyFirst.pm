package Treex::Block::Treelets::TrEasyFirst;
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
    #default => 'two-node10k.gz',
);

has model => (is => 'rw');

my @WMASKS = (
    [1,2,3] => 0.6, # L***
    [0,2,3] => 1, # *F**
    [2,3],  => 1, # LF**
    [0,3],  => 2, # *FL*
    [3],    => 5, # LFL*
    [0],    => 1.6, # *FLF
    #[],     => 0, # LFLF
);

my @STARS = ('*') x 3;

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::TwoNode->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    return;
}

sub process_ttree {
    my ( $self, $tree ) = @_;
    my @rules;
    my @nodes = $tree->get_descendants();
    foreach my $node (@nodes){
        push @rules, $self->get_rules($node);
    }
    @rules = sort {$b->[0] <=> $a->[0]} @rules;
    
    while (@rules){
        my $rule = shift @rules;
        $self->apply_rule($rule);
    }
    
    return;
}

sub apply_rule {
    my ($self, $rule) = @_;
    my ($score, $node, $trg_string, $src_string) = @$rule;
    my $parent = $node->get_parent();
    my ($tnL, $tnF, $tpL, $tpF) = map {defined($_) ? $_ : '*'} split / /, $trg_string;
    my ($nLo, $nFo) = map {defined($_) ? $_ : ''} ($node->t_lemma_origin, $node->formeme_origin);
    my ($pLo, $pFo) = map {defined($_) ? $_ : ''} ($parent->t_lemma_origin, $parent->formeme_origin);
    my $origin = "$src_string -> $trg_string = $score";
    return 0 if $tnL ne '*' && $nLo ne 'clone' && $node->t_lemma ne $tnL;
    return 0 if $tnF ne '*' && $nFo ne 'clone' && $node->formeme ne $tnF;
    if ($parent->is_root){
        return 0 if $tpL ne '_ROOT' && $tpL ne '*';
        return 0 if $tpF ne '_ROOT' && $tpF ne '*';
    } else {
        return 0 if $tpL ne '*' && $pLo ne 'clone' && $parent->t_lemma ne $tpL;
        return 0 if $tpF ne '*' && $pFo ne 'clone' && $parent->formeme ne $tpF;
    }
    
    if ($tnL ne '*'){
        $node->set_t_lemma($tnL);
        $node->set_t_lemma_origin($nLo eq 'clone' ? $origin : "$nLo\n$origin");
    }
    if ($tnF ne '*'){
        $node->set_formeme($tnF);
        $node->set_formeme_origin($nFo eq 'clone' ? $origin : "$nFo\n$origin");
    }
    if ($tpL ne '*'){
        $parent->set_t_lemma($tpL);
        $parent->set_t_lemma_origin($pLo eq 'clone' ? $origin : "$pLo\n$origin");
    }
    if ($tpF ne '*'){
        $parent->set_formeme($tpF);
        $parent->set_formeme_origin($pFo eq 'clone' ? $origin : "$pFo\n$origin");
    }
    return 1;
}


sub get_rules {
    my ($self, $node) = @_;

    # Skip nodes that were already translated by rules
    return if $node->t_lemma_origin ne 'clone';
    my $src_node = $node->src_tnode;
    return if !$src_node;
    
    my $src_lemma      = $src_node->t_lemma;
    my $src_formeme    = $src_node->formeme;
    my $src_parent     = $src_node->get_parent();
    my $parent_lemma   = $src_parent->t_lemma // '_ROOT'; #/
    my $parent_formeme = $src_parent->formeme // '_ROOT'; #/
    my @src = ($src_lemma, $src_formeme, $parent_lemma, $parent_formeme);
    my @rules;
    
    mapp {
        my ($mask, $weight) = ($a, $b);
        my @s = @src;
        @s[@$mask] = @STARS;
        my $s1 = $s[0].' '.$s[1]; my $s2 = $s[2].' '.$s[3];
        my $trans = $self->model->model->{$s1}{$s2};
        if ($trans){
            mapp {
                # $a = trg_treelet, $b = P(trg|src)
                push @rules, [$b*$weight,  $node, $a, "$s1 $s2"];
            } @$trans; 
        }
    } @WMASKS;
    return @rules;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Treelets::TrEasyFirst - translate treelets greedily

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
