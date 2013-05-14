package Treex::Block::Treelets::TrEasyFirstLM;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::Chain;
use Treex::Tool::TranslationModel::Rule;
use Treex::Tool::TranslationModel::Segment;
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

has tm_model => (is => 'rw');

has [qw(wL wF wLF wxFL wLFL wxFLF wLFLF)] => (is=>'rw', default=>1);

my $MAX_RULE_SIZE = 3;     # max number of nodes in src treelet

my $WEIGHTS;

my (@s_label, @s_parent, @s_children, @t_label, @t_origin, @translated, @covered_by);

sub process_start {
    my ($self) = @_;
    my $model = Treex::Tool::TranslationModel::Chain->new();
    $model->load($self->model_dir.'/'.$self->model_name);
    $self->set_tm_model($model->model);
    $WEIGHTS = {
        tmL1 => $self->wL,
        tmF1 => $self->wF,
        tmL2 => $self->wLF,
        tmF2 => $self->wxFL,
        tmL3 => $self->wLFL,
        tmF3 => $self->wxFLF,
        tmL4 => $self->wLFLF,
    };
    return;
}

sub process_ttree {
    my ($self, $ttree) = @_;

    # Build subnode tree representation
    my @trg_nodes = $ttree->get_descendants({ordered=>1});
    my @src_nodes = map {$_->src_tnode} @trg_nodes;
    @s_label = ('_ROOT', map {escape($_)} map {($_->formeme, $_->t_lemma)} @src_nodes);
    @s_parent = (0, map {($_->get_parent->ord*2, $_->ord*2 - 1)} @src_nodes);
    @s_children = map {[]} (0..$#s_parent);
    for my $i (1 .. $#s_parent){ push @{$s_children[$s_parent[$i]]}, $i;}

    # Translate subnodes
    @t_label = (); @t_origin =();
    $self->translate_sentence_subnodes();

    # Convert subnodes back to t-trees
    # TODO de-escape labels
    for my $i (1 .. $#t_label){
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
    $self->retrieve_matching_rules();

    # @queue holds all roots of untranslated components
    # 0=root - it governs the whole src tree as there are no translated nodes yet
    my @queue = (0); 
    while (@queue){

        # If the first item in @queue was already translated, just skip it.
        # We can be sure that its children were included in the queue unless they were translated as well.
        # Note that when searching the best rule for a give component,
        # the rule may translate also nodes from other components (if MAX_RULE_SIZE > 2),
        # which might be included in the queue but we don't bother to detect it
        # and we leave the translated nodes in the queue and remove them now.
        if ($translated[$queue[0]]){
            shift @queue;
            next;
        }

        my $treelet = $self->find_best_in_subtree($queue[0]);
        if (!$treelet){
            my @segment_nodes = shift @queue;
            while(@segment_nodes){
                my $n = shift @segment_nodes;
                $translated[$n] = 1;
                $t_label[$n] = $s_label[$n];
                $t_origin[$n] = 'cloneX';
                push @segment_nodes, grep {!$translated[$_]} @{$s_children[$n]};
            }
        } else {
            my $rule = $treelet->{rules}[0];
            my @subnodes = @{$treelet->{s_nodes}};
            my @labels   = @{$rule->{t_labels}};
            my $origin = $treelet->{src} .' -> '. $rule->{trg} .' = '. $treelet->{score};
            foreach my $i (0..$#subnodes){
                my $subnode = $subnodes[$i];
                $t_label[$subnode] = $labels[$i];
                $t_origin[$subnode] = $t_origin[$subnode] ? $t_origin[$subnode]."\n$origin" : $origin;
                push @queue, grep {!$translated[$_]} @{$s_children[$subnode]} if !$translated[$subnode];
                $translated[$subnode] = 1;
            }
        }
    }
    return;
}

sub find_best_in_subtree {
    my ($self, $s_root_i) = @_;
    my $best = 0;
    my %seen_treelet = ();
    my @queue = ($s_root_i);
    while (@queue){
        my $s_i = shift @queue;
        push @queue, grep{!$translated[$_]} @{$s_children[$s_i]};
        my @treelets = grep {!$seen_treelet{$_}} @{$covered_by[$s_i]};
        foreach my $treelet (@treelets){
            $seen_treelet{$treelet} = 1;
            my @new_rules = grep {is_valid($_,$treelet)} @{$treelet->{rules}};
            # TODO $rule->{logLM} should be updated where needed and @new_rules sorted again
            $treelet->{rules} = \@new_rules;
            next if !@new_rules;
            $self->update_features($treelet);
            my $score = $self->compute_score($treelet);
            $best = $treelet if !$best || ($best->{score} < $score);
        }
    }
    return $best;
}

# A rule is "valid" if it is compatible with the already translated nodes
# and if it covers some untranslated nodes.
sub is_valid {
    my ($rule, $treelet) = @_;
    my @subnodes = @{$treelet->{s_nodes}};
    my @labels = @{$rule->{t_labels}};
    my $at_least_one_untranslated = 0;
    for my $i (0..$#subnodes){
        my $subnode = $subnodes[$i];
        if ($translated[$subnode]){
            return 0 if $labels[$i] ne $t_label[$subnode];
        } else {
            $at_least_one_untranslated = 1;
        }
    }
    return $at_least_one_untranslated;
}


sub retrieve_matching_rules {
    my ($self) =@_;
    @translated = ();
    @covered_by = map {[]} @s_label;

    foreach my $s_i (1..$#s_label){
        my @s_side = ($s_i);
        for my $size (1 .. $MAX_RULE_SIZE){
            my $s_str = join ' ', map {$s_label[$_]} @s_side;
            my $entry = $self->tm_model->{$s_str};
            if ($entry){
                my @rules;
                mapp {
                    push @rules, {
                        trg => $a,
                        t_labels => [split / /, $a],
                        TM => $b,
                    };
                } @$entry;
                my $treelet = {
                    rules => \@rules,
                    s_nodes => [@s_side],
                    src => $s_str,
                };
                $self->precompute_features($treelet);
                foreach my $s_node (@s_side){
                    push @{$covered_by[$s_node]}, $treelet;
                }
            }
            my $s_next_i = $s_parent[$s_side[-1]];
            last if $s_next_i == 0; # reached the root
            push @s_side, $s_next_i;
        }
    }
    return;
}

sub compute_score {
    my ($self, $treelet) = @_;
    my $score = 0;
    while (my ($name, $value) = each %{$treelet->{features}}){
        $score += ($WEIGHTS->{$name} || 0) * $value;
    }
    $treelet->{score} = $score;
    return $score;
}

sub precompute_features {
    my ($self, $treelet) = @_;
    my @subnodes = map {$s_label[$_]} @{$treelet->{s_nodes}};
    my $is_formeme = $subnodes[0] =~ /(.:.|^adv$|^x$)/ ? 'F' : 'L';
    my $size = @subnodes;
    my %features = (
        #$is_formeme.$size => 1,
        #entropy => $self->precompute_entropy($treelet),
        #'src:'.$treelet->{src} => 1,
        # TODO add other features, e.g.
        # log_count(src)
    );
   
    $treelet->{features} = \%features;
    return;
}

sub precompute_entropy {
    my ($self, $treelet) = @_;
    my $entropy = 0;
    foreach my $rule (@{$treelet->{rules}}){
        my $prob = $rule->{TM};
        $entropy -= $prob * log($prob);
    }
    return $entropy;
}

sub update_features {
    my ($self, $treelet) = @_;
    my $TM = $treelet->{rules}[0]{TM};
    
    my $logTM = log($TM);
    #$treelet->{features}{logTM} = $logTM;
    #$treelet->{features}{TM} = $TM;
    
    my @subnodes = map {$s_label[$_]} @{$treelet->{s_nodes}};
    my $is_formeme = $subnodes[0] =~ /(.:.|^adv$|^x$)/ ? 'F' : 'L';
    my $size = @subnodes;
    $treelet->{features}{'tm'.$is_formeme.$size} = $logTM;
    
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
