package Treex::Block::Treelets::TrEasyFirstChain;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::Chain;
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
    default => 'chain35k.gz',
);

has model => (is => 'rw');

has [qw(wL wF wLF wxFL wLFL wxFLF wLFLF)] => (is=>'rw', default=>1);

#TM    wL=0.6 wF=1.0 wLF=1.0 wxFL=2.0 wLFL=5.0 wxFLF=1.6
#logTM wL=1.8 wF=1.1 wLF=1.0 wxFL=0.9 wLFL=0.1 wxFLF=0.7

my @WMASKS;

my @ORIG_WMASKS = (
    [0]         => 0.6, # L***
    [1]         => 1, # *F**
    [0,1],      => 1, # LF**
    [1,2],      => 2, # *FL*
    [0,1,2],    => 5, # LFL*
    [1,2,3],    => 1.6, # *FLF
    #[0,1,2,3], => 0, # LFLF
);

my @STARS = ('*') x 4;

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::Chain->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_model($model);
    @WMASKS = (
        [0]         => $self->wL,
        [1]         => $self->wF,
        [0,1],      => $self->wLF,
        [1,2],      => $self->wxFL,
        [0,1,2],    => $self->wLFL,
        [1,2,3],    => $self->wxFLF,
        [0,1,2,3],  => $self->wLFLF,
    );
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
    my ($score, $node, $trg_string, $src_string, $mask) = @$rule;
    my $parent = $node->get_parent();
    my @subnodes = @STARS;
    @subnodes[@$mask] = split / /, $trg_string;
    my ($tnL, $tnF, $tpL, $tpF) = @subnodes;

    my ($nLo, $nFo) = map {defined($_) ? $_ : ''} ($node->t_lemma_origin, $node->formeme_origin);
    my ($pLo, $pFo) = map {defined($_) ? $_ : ''} ($parent->t_lemma_origin, $parent->formeme_origin);
    my $origin = "$src_string -> $trg_string = $score";

    # skip rules covering formeme of root (perhaps I should not extract such rules at all)
    return 0 if $tpF eq '_ROOT';
    #return 0 if $tpL eq '_ROOT'; this helps a bit, but one _ROOT subnode seems like a good idea

    # skip useless rules that bring no new (not translated so far) nodes
    return 0 if ($nLo ne 'clone' || $tnL eq '*') && ($nFo ne 'clone' || $tnF eq '*')
            && ($pLo ne 'clone' || $tpL eq '*') && ($pFo ne 'clone' || $tpF eq '*');

    # skip rules not compatible with the already translated nodes
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
        my $src_key = join ' ', map {escape($_)} @src[@$mask];
        my $trans = $self->model->model->{$src_key};
        if ($trans && $weight){
            mapp {
                # $a = trg_treelet, $b = P(trg|src)
                push @rules, [log($b)*$weight, $node, $a, $src_key, $mask];
            } @$trans;
        }
    } @WMASKS;
    return @rules;
}

sub escape {
    my ($string) = $_;
    return '_' if !defined $string;
    $string =~ s/ /&#32;/g;
    $string =~ s/\(/&#40;/g;
    $string =~ s/\(/&#41;/g;
    $string =~ s/=/&#61;/g;
    return $string;
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
