package Treex::Block::Treelets::TrEasyFirstLM;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::Chain;
use Treex::Tool::TranslationModel::Rule;
use Treex::Tool::TranslationModel::Segment;
use Storable;
use List::Pairwise qw(mapp);
use List::Util qw(sum);
use List::MoreUtils qw(all any none first_index uniq);
extends 'Treex::Core::Block';

has tm_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'data/models/translation/en2cs',
    documentation => 'Base directory for all models'
);

has tm_name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'chain35k.gz',
);

has lm_dir => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'cs.wmt2007-2012',
    documentation => 'Base directory for Language Model'
);


has tm_model => (is => 'rw');

has [qw(wL1 wF1 wL2 wF2 wL3 wF3 wL4 wTM wLogTM)] => (is=>'rw', default=>0);
has [qw(bin0 bin1 bin2 bin3 bin4 bin5)] => (is=>'rw', default=>0);
has [qw(Ld_Fd Fd_Lg Ld_FdLg LdFd_Lg)] => (is=>'rw', default=>0); # topLM
has [qw(Fd_Ld Lg_Fd Lg_FdLd LgFd_Ld)] => (is=>'rw', default=>0); # bottomLM


my $MAX_RULE_SIZE = 3;     # max number of nodes in src treelet

my $WEIGHTS;

my (@s_label, @s_parent, @s_children, @t_label, @t_origin, @covered_by);


use LanguageModel::Lemma;
my $ALL = '<ALL>';
my ($cLgFdLd, $cPgFdLd);

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::Chain->new();
    $model->load($self->tm_dir.'/'.$self->tm_name);
    $self->set_tm_model($model->model);
    $WEIGHTS = {
        TM => $self->wTM,
        LogTM => $self->wLogTM,
        L1 => $self->wL1,
        F1 => $self->wF1,
        L2 => $self->wL2,
        F2 => $self->wF2,
        L3 => $self->wL3,
        F3 => $self->wF3,
        bin0 => $self->bin0,
        bin1 => $self->bin1,
        bin2 => $self->bin2,
        bin3 => $self->bin3,
        bin4 => $self->bin4,
        bin5 => $self->bin5,
        # topLM
        Ld_Fd   => $self->Ld_Fd,    # ne (-0.1)
        Fd_Lg   => $self->Fd_Lg,    # 0.1
        Ld_FdLg => $self->Ld_FdLg,  # ne (2.0)
        LdFd_Lg => $self->LdFd_Lg,  # 2.5
        # bottomLM
        Fd_Ld   => $self->Fd_Ld,    # ne (0)
        Lg_Fd   => $self->Lg_Fd,    # ne (-0.1...20 nema vliv)
        Lg_FdLd => $self->Lg_FdLd,  # ne (-0.1...20 nema vliv)
        LgFd_Ld => $self->LgFd_Ld,  # ne (-50)
    };
    
    my $dir = $ENV{TMT_ROOT}.'/share/data/models/language/'. $self->lm_dir;
    $cLgFdLd = _load_plsgz( $dir . '/c_LgFdLd.pls.gz' );
    $cPgFdLd = _load_plsgz( $dir . '/c_PgFdLd.pls.gz' );
    LanguageModel::Lemma::init("$dir/lemma_id.pls.gz");
    return;
}

sub _load_plsgz {
    my ($filename) = @_;
    open my $PLSGZ, '<:gzip', $filename;
    my $model = Storable::fd_retrieve($PLSGZ);
    log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model );
    close $PLSGZ;
    return $model;
}


sub process_ttree {
    my ($self, $ttree) = @_;

    # Build subnode tree representation
    my @trg_nodes = $ttree->get_descendants({ordered=>1});
    #my @src_nodes = map {$_->src_tnode} @trg_nodes;
    #@s_label = ('_ROOT', map {escape($_)} map {($_->formeme, $_->t_lemma)} @src_nodes);
    #@s_parent = (-1, map {($_->get_parent->ord*2, $_->ord*2 - 1)} @src_nodes);
    @s_label = ('_ROOT', map {escape($_)} map {($_->formeme, $_->t_lemma)} @trg_nodes);
    @s_parent = (-1, map {($_->get_parent->ord*2, $_->ord*2 - 1)} @trg_nodes);
    
    @s_children = map {[]} (0..$#s_parent);
    for my $i (1 .. $#s_parent){ push @{$s_children[$s_parent[$i]]}, $i;}

    # Translate subnodes
    @t_label = (); @t_origin = ();
    $self->translate_sentence_subnodes();

    # Convert subnodes back to t-trees
    # TODO de-escape labels
    for my $i (1 .. $#t_label){
        next if !$t_origin[$i]; #skip untranslated (left them as clone)
        my $is_formeme = $i % 2;
        my $t_node = $trg_nodes[($i-2+$is_formeme)/2];
        if ($is_formeme){
            $t_node->set_formeme($t_label[$i]);
            $t_node->set_formeme_origin($t_origin[$i]);
        } else {
            $t_node->set_t_lemma($t_label[$i]);
            $t_node->set_t_lemma_origin($t_origin[$i]);
        }
    }
    return;
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


sub translate_sentence_subnodes {
    my ($self) = @_;
    my @rules = sort {$b->{score} <=> $a->{score}} $self->retrieve_matching_rules();
    
    while (@rules){
        my $rule = shift @rules;
        $self->apply_rule($rule);
        # TODO: we don't need the full sort, we just need to find the best scoring rule
        @rules = sort {$b->{score} <=> $a->{score}} grep {is_valid($_)} @rules;
    }
    return;
}

sub apply_rule {
    my ($self, $rule) = @_;
    my @subnodes = @{$rule->{s_nodes}};
    my @labels   = @{$rule->{t_labels}};
    my $origin = $rule->{src} .' -> '. $rule->{trg} . "\nscore=" . $rule->{score}
       . "\nTM=" . $rule->{TM} . ' P(Ld|FdLg)='. ($rule->{features}{Ld_FdLg}//'x') ;
    my @newly_translated;
    foreach my $i (0..$#subnodes){
        my $subnode = $subnodes[$i];
        
        # if already translated, just log origin
        if ($t_origin[$subnode]){
            $t_origin[$subnode] .= "\n$origin";
        }

        # otherwise, translate an untranslated subnode
        else {
            $t_label[$subnode] = $labels[$i];
            $t_origin[$subnode] = $origin;
            push @newly_translated, $subnode;
        }
    }

    foreach my $rule (uniq map {@{$covered_by[$_]}} map {lm_context($_)} @newly_translated){
        $self->update_lm_scores($rule);
    }
    return;
}

sub update_lm_scores {
    my ($self, $rule) = @_;
    my @subnodes    = @{$rule->{s_nodes}};
    my @labels      = @{$rule->{t_labels}};
    my $top_node    = $subnodes[-1];
    my $top_label   = $labels[-1];
    my $top_formeme = $top_node % 2;
    my $parent      = $s_parent[$top_node];
    if ($parent != -1 && $t_origin[$parent]){
        if ($top_formeme){
            my $Fd = $top_label;
            my $Lg = lemma_id($t_label[$parent]);
            my $nLgFd = $cLgFdLd->[$$Lg]{$Fd}{$ALL} || 0;
            my $nLg   = $cLgFdLd->[$$Lg]{$ALL};
            my $pFd_Lg = $nLgFd / ($nLg || 1);
            $rule->{features}{Fd_Lg} = $pFd_Lg;
            if (@subnodes > 1){
                my $Ld = lemma_id($labels[-2]);
                my $nLgFdLd = $cLgFdLd->[$$Lg]{$Fd}{$$Ld} || 0;
                my $pLdFd_Lg = $nLgFdLd / ($nLg || 1);
                $rule->{features}{LdFd_Lg} = $pLdFd_Lg;
            }
        } else {
            my $Ld = lemma_id($top_label);
            my $Fd = $t_label[$parent];
            my $nFdLd = $cPgFdLd->{$ALL}{$Fd}{$$Ld} || 0;
            my $nFd   = $cPgFdLd->{$ALL}{$Fd}{$ALL};
            my $pLd_Fd = $nFdLd / ($nFd || 1);
            $rule->{features}{Ld_Fd} = $pLd_Fd;
            my $grandpa = $s_parent[$parent];
            if ($grandpa!=-1 && $t_origin[$grandpa]){
                my $Lg = lemma_id($t_label[$grandpa]);
                my $nLgFdLd = $cLgFdLd->[$$Lg]{$Fd}{$$Ld} || 0;
                my $nLgFd   = $cLgFdLd->[$$Lg]{$Fd}{$ALL};
                my $pLd_FdLg = $nLgFdLd / ($nLgFd || 1);
                $rule->{features}{Ld_FdLg} = $pLd_FdLg;
            }
        }
    }
    
    my $bottom_node    = $subnodes[0];
    my $bottom_label   = $labels[0];
    my $bottom_formeme = $bottom_node % 2;
    my @children       = grep {$t_origin[$_]} @{$s_children[$bottom_node]};
    my $grandchildren  = 0; # number of translated grandchildren
    my ($pFd_Ld, $pLgFd_Ld, $pLg_Fd, $pLg_FdLd) = (0,0,0,0);
    foreach my $child (@children){
        my $parent_label = @subnodes>1 ? $labels[1] : undef;
        my ($iFd_Ld, $iLgFd_Ld, $iLg_Fd, $iLg_FdLd) = $self->bottom_lm($bottom_node, $child, $bottom_label, $parent_label);
        $pFd_Ld   += $iFd_Ld || 0;
        $pLgFd_Ld += $iLgFd_Ld || 0;
        $pLg_Fd   += $iLg_Fd || 0;
        $pLg_FdLd += $iLg_FdLd || 0;
        $grandchildren++ if defined $iLg_FdLd;
    }
    if (@children){
        $rule->{features}{Fd_Ld}   = $pFd_Ld; # just one child
        $rule->{features}{LgFd_Ld} = $pLgFd_Ld; # just one child
        $rule->{features}{Lg_Fd}   = $pLg_Fd / @children;
        $rule->{features}{Lg_FdLd} = $pLg_Fd / $grandchildren if $grandchildren;
    }
    
    $self->compute_score($rule);
    
    return;
}

sub bottom_lm {
    my ($self, $subnode, $child, $label, $parent_label) = @_;
    my ($pFd_Ld, $pLgFd_Ld, $pLg_Fd, $pLg_FdLd);# = (0,0,0,0);
    my $is_formeme = $subnode % 2;
    if ($is_formeme){
        my $Fd = $label;
        my $Ld = lemma_id($t_label[$child]);
        my $nFdLd = $cPgFdLd->{$ALL}{$Fd}{$$Ld} || 0;
        my $nLd   = $cPgFdLd->{$ALL}{$ALL}{$$Ld};
        $pFd_Ld   = $nFdLd / ($nLd || 1);
        if (defined $parent_label){
            my $Lg = lemma_id($parent_label);
            my $nLgFdLd = $cLgFdLd->[$$Lg]{$Fd}{$$Ld} || 0;
            $pLgFd_Ld   = $nLgFdLd / ($nLd || 1);
        }
    } else {
        my $Lg = lemma_id($label);
        my $Fd = $t_label[$child];
        my $nLgFd = $cLgFdLd->[$$Lg]{$Fd}{$ALL} || 0;
        my $nFd   = $cPgFdLd->{$ALL}{$Fd}{$ALL};
        $pLg_Fd   = $nLgFd / ($nFd || 1);
        my ($grandchild) = @{$s_children[$child]}; # each formeme must have exactly one child
        if ($t_origin[$grandchild]){
            my $Ld = lemma_id($t_label[$grandchild]);
            my $nLgFdLd = $cLgFdLd->[$$Lg]{$Fd}{$$Ld} || 0;
            my $nFdLd   = $cPgFdLd->{$ALL}{$Fd}{$$Ld};
            $pLg_FdLd   = $nLgFdLd / ($nFdLd || 1);
        }
    }
    return ($pFd_Ld, $pLgFd_Ld, $pLg_Fd, $pLg_FdLd);
}

sub lemma_id {
    my $lemma = shift;
    $lemma =~ s/#(.)$/ $1/;
    return LanguageModel::Lemma->new($lemma);
}

sub lm_context {
    my ($subnode) = @_;
    my $parent = $s_parent[$subnode];
    my @ancestors = ();
    if ($parent != -1){
        push @ancestors, $parent;
        push @ancestors, $s_parent[$parent] if $parent;
    }
    my @children = @{$s_children[$subnode]};
    my @grandchildren = map {@{$s_children[$_]}} @children;
    return (@ancestors, @children, @grandchildren);
}

# A rule is "valid" if it is compatible with the already translated nodes
# and if it covers some untranslated nodes.
sub is_valid {
    my ($rule) = @_;
    my @subnodes = @{$rule->{s_nodes}};
    my @labels = @{$rule->{t_labels}};
    my $at_least_one_untranslated = 0;
    for my $i (0..$#subnodes){
        my $subnode = $subnodes[$i];
        if ($t_origin[$subnode]){
            return 0 if $labels[$i] ne $t_label[$subnode];
        } else {
            $at_least_one_untranslated = 1;
        }
    }
    return $at_least_one_untranslated;
}

sub retrieve_matching_rules {
    my ($self) =@_;
    my @rules;
    @covered_by = map {[]} @s_label;

    foreach my $s_i (1..$#s_label){
        my @s_side = ($s_i);
        for my $size (1 .. $MAX_RULE_SIZE){
            my $s_str = join ' ', map {$s_label[$_]} @s_side;
            my $entry = $self->tm_model->{$s_str};
            if ($entry){
                mapp {
                    my $rule = {
                        s_nodes => [@s_side],
                        src => $s_str,
                        trg => $a,
                        t_labels => [split / /, $a],
                        TM => $b,
                    };
                    $self->precompute_features($rule);
                    foreach my $s_node (@s_side){
                        push @{$covered_by[$s_node]}, $rule;
                    }
                    $self->compute_score($rule);
                    push @rules, $rule;
                } @$entry;
            }
            my $s_next_i = $s_parent[$s_side[-1]];
            last if $s_next_i == -1; # reached the root
            push @s_side, $s_next_i;
        }
    }
    return @rules;
}

sub compute_score {
    my ($self, $rule) = @_;
    my $score = 0;
    while (my ($name, $value) = each %{$rule->{features}}){
        $score += ($WEIGHTS->{$name} || 0) * $value;
    }
    $rule->{score} = $score;
    return $score;
}

sub precompute_features {
    my ($self, $rule) = @_;
    my @subnodes = map {$s_label[$_]} @{$rule->{s_nodes}};
    my $is_formeme = $subnodes[0] =~ /(.:.|^adv$|^x$)/ ? 'F' : 'L';
    my $size = @subnodes;
    my $TM = $rule->{TM};
    my $logTM = log($TM);
    my $binTM = int(-$logTM);
    
    my %features = (
        #$is_formeme => 1,
        $is_formeme.$size => 1,
        TM => $TM,
        LogTM => $logTM,
        #'bin'.$binTM => 1,
    );
    $rule->{features} = \%features;
    return;
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

=cut
