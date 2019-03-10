package Treex::Block::Discourse::CS::MarkTFA;
use Moose;
use Treex::Core::Common;
use Data::Dumper;
use Treex::Core::Node::EffectiveRelations;

extends 'Treex::Core::Block';

my $file_tfa_t_count;
my $file_tfa_c_count;
my $file_tfa_f_count;

my @ttrees;

sub process_document {
  my ($self, $doc) = @_;

  $file_tfa_t_count = 0;
  $file_tfa_c_count = 0;
  $file_tfa_f_count = 0;
  my $tfa_relevant_without_tfa = 0;

  @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;

  foreach my $t_root (@ttrees) {
    my $tfa_relevant_without_tfa_after;
    my $tfa_relevant_without_tfa_before;
    my $iterations = 0;
    do {
      $tfa_relevant_without_tfa_before = scalar(get_tfa_relevant_without_tfa($t_root->get_descendants({ordered=>1, add_self=>0})));
      pre_annotate($t_root); # pre_annotation of individual nodes
      pre_annotate_2($t_root); # pre_annotation of sons of a predicate etc.
      pre_annotate_3($t_root); # pre_annotation of coordinations/appositions
      $tfa_relevant_without_tfa_after = scalar(get_tfa_relevant_without_tfa($t_root->get_descendants({ordered=>1, add_self=>0})));
      $iterations++;
    }  
    while ($tfa_relevant_without_tfa_before - $tfa_relevant_without_tfa_after > 0); # while some nodes get annotated...
    #log_info("Number of iterations: $iterations\n");    
    $tfa_relevant_without_tfa += $tfa_relevant_without_tfa_after;
  }

  log_info("Number of tfa values set: 't': $file_tfa_t_count, 'c': $file_tfa_c_count, 'f': $file_tfa_f_count, tfa relevant nodes without tfa value: $tfa_relevant_without_tfa");

} # process_document


sub get_tfa_relevant_without_tfa {
  my (@nodes) = @_;
  my @tfa_relevant_nodes = grep {is_tfa_relevant($_)} @nodes;
  my @nodes_without_tfa = grep {!defined($_->get_attr('tfa'))} @tfa_relevant_nodes;
  return @nodes_without_tfa;
}

# Moves subtree to the left
sub move_subtree_left_auto {
  my ($node) = @_;
  return if $node eq $node->get_root();
  subtree_skip_subtree_left($node);
  #add_log($node, 'A1_mssl'); # Auto 2nd_phase move subtree left (skip subtree)
}

# Moves subtree to the right
sub move_subtree_right_auto {
  my ($node) = @_;
  return if $node eq $node->get_root();
  subtree_skip_subtree_right($node);
  #add_log($node, 'A1_mssr'); # Auto 2nd_phase move subtree right (skip subtree)
}


sub subtree_skip_subtree_left {
  my ($node) = @_;
  return if $node eq $node->get_root();
  my $node_deepord = $node->get_attr('ord');
  my $father = $node->get_parent();
  my $father_deepord = $father->get_attr('ord');
  my $lbrother = $node->get_left_neighbor();
  if (!defined($lbrother)) { # no left brother
    return if $father eq $father->get_root();
    if ($father_deepord < $node_deepord) { # not yet on the leftmost position, i.e. the father is on the left side
      $node->shift_before_node($father);
    }
  }
  else { # there is a left brother
    my $lbrother_deepord = $lbrother->get_attr('ord');
    if ($lbrother_deepord < $father_deepord and $father_deepord < $node_deepord) { # father to skip
      $node->shift_before_node($father);
    }
    else { # skip the left brother (and all its descendants)
      $node->shift_before_subtree($lbrother);
    }
  }
} # subtree_skip_subtree_left


sub subtree_skip_subtree_right {
  my ($node) = @_;
  return if $node eq $node->get_root();
  my $node_deepord = $node->get_attr('ord');
  my $father = $node->get_parent();
  my $father_deepord = $father->get_attr('ord');
  my $rbrother = $node->get_right_neighbor();
  if (!defined($rbrother)) { # no right brother
    return if $father eq $node->get_root();
    if ($father_deepord > $node_deepord) { # not yet on the rightmost position, i.e. the father is on the right side
      $node->shift_after_node($father);
    }
  }
  else {
    my $rbrother_deepord = $rbrother->get_attr('ord');
    if ($rbrother_deepord > $father_deepord and $father_deepord > $node_deepord) { # father to skip
      $node->shift_after_node($father);
    }
    else { # skip the right brother (and all its descendants)
      $node->shift_after_subtree($rbrother);
    }
  }
} # subtree_skip_subtree_right

# Returns the projective part of the subtree of the given node (incl. the node)
sub get_projective_subtree_part {
  my ($node) = @_;
#  my @nodes = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} $node->get_descendants({ordered=>1, add_self=>1}); # get the nodes in the ascending deep order
  my @nodes = $node->get_descendants({ordered=>1, add_self=>1}); # get the nodes in the ascending deep order
  my $i = Treex::PML::Index(\@nodes, $node);
  my $shift = $node->get_attr('ord') - $i; # the difference between the deepord of the node and its position in the array of the subtree nodes
  my @projective = ();
  for (my $j=0; $j<=$#nodes; $j++) {
    if ($nodes[$j]->get_attr('ord') - $j eq $shift) { # collect all nodes that have the same difference, i.e. they are in the projective part of the subtree
      push(@projective, $nodes[$j]);
    }
  }
  return @projective;
} # get_projective_subtree_part

# Returns 1 if the node is tfa-relevant, i.e. it should have tfa value assigned; otherwise returns 0
sub is_tfa_relevant {
  my ($node) = @_;
  if ($node eq $node->get_root()) {
    return 0;
  }
  my $nodetype = $node->get_attr('nodetype');
  if (defined($nodetype) and ($nodetype eq 'coap' or $nodetype eq 'fphr')) {
    return 0;
  }
  my $functor = $node->get_attr('functor');
  if (defined($functor) and ($functor eq 'CM' or $functor eq 'FPHR')) {
    return 0;
  }
  return 1;
} # is_tfa_relevant

sub set_tfa_at_node {
  my ($node, $value) = @_;
  if (is_tfa_relevant($node)) {
    my $tfa = $node->get_attr('tfa');
    # if (!defined($tfa) or $tfa ne $value) { # if the value has changed
    if (!defined($tfa)) { # if the value has not been set yet
#      if (!defined($tfa)) { # lower the number of nodes without TFA annotation
#        my $nodes_without_tfa = FileUserData('nodes_without_tfa');
#        FileUserData('nodes_without_tfa', $nodes_without_tfa-1);
#      }
      $node->set_attr('tfa',$value);

      if ($value eq 't') {
        $file_tfa_t_count++;
      }
      elsif ($value eq 'c') {
        $file_tfa_c_count++;
      }
      else {
        $file_tfa_f_count++;
      }
#      #ChangingFile(1);
    }
  }
} # set_tfa_at_node

# it checks the deepord of the siblings and moves them if necessary according to the annotation rules
sub check_siblings_order {
  my ($node) = @_;
  # print STDERR "check_siblings_order: Entering the function.\n";
  my $parent = $node->get_parent();
  check_sons_order($parent);
} # check_siblings_order

# it checks the deepord of the sons and moves them if necessary according to rules of communicative dynamism
sub check_sons_order {
  my ($father) = @_;
  return if ($father eq $father->get_root());
  if ($father->get_attr('nodetype') eq 'coap') {
    check_sons_order_coap($father);
    return;
  }
  my @sons = $father->get_children();
  my @relevant_sons = grep {is_tfa_relevant($_)} @sons;
  my @tfa_sons = grep {defined($_->get_attr('tfa'))} @relevant_sons;
  if (scalar(@relevant_sons) > scalar(@tfa_sons)) { # not all tfa-relevant nodes have been set a tfa value yet
    return;
  }
  # print STDERR "check_sons_order: All relevant sons have a tfa-value set.\n";

  my @f_sons = grep {$_->get_attr('tfa') eq 'f'} @relevant_sons;
  my @tc_sons = grep {$_->get_attr('tfa') =~ /^[tc]$/} @relevant_sons;

  # first, move everything in focus from the left of the governing node to the right of it; do it from right to left to minimize number of shifts
  my $father_deepord = $father->get_attr('ord'); # it changes for every moved son
  my @left_f_sons_reverse = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {$_->get_attr('ord') < $father_deepord} @f_sons;
  foreach my $left_f_son (@left_f_sons_reverse) {
    # print STDERR "father's order: $father_deepord, left f-son's order: " . $left_f_son->get_attr('ord') . "\n";
    while ($left_f_son->get_attr('ord') < $father_deepord) {
      # print STDERR " - moving subtree to the right\n";
      move_subtree_right_auto($left_f_son);
      $father_deepord = $father->get_attr('ord'); # it may change during moving the son (and its descendants)
    }
  }
  #print STDERR "All sons in focus have been moved to the right from the father.\n";

  # second, move everything in topic and contrastive topic from the right of the governing node to the left of it; do it from left to right to minimize number of shifts
  $father_deepord = $father->get_attr('ord'); # it changes for every moved son
  my @right_tc_sons = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('ord') > $father_deepord} @tc_sons;
  foreach my $right_tc_son (@right_tc_sons) {
    # print STDERR "father's order: $father_deepord, right tc-son's order: " . $right_tc_son->get_attr('ord') . "\n";
    while ($right_tc_son->get_attr('ord') > $father_deepord) {
      # print STDERR " - moving subtree to the left\n";
      move_subtree_left_auto($right_tc_son);
      $father_deepord = $father->get_attr('ord'); # it may change during moving the son (and its descendants)
    }
  }
  # print STDERR "All sons in (contrastive) topic have been moved to the left from the father.\n";

  # third, in some cases (noun phrases and verb phrases), re-order the sons according to the annotation rules
  my $father_sempos = $father->get_attr('gram/sempos');

  # ========= noun phrases =========

  if (defined($father_sempos) and $father_sempos =~ /^n/) { # a noun phrase
    # first, move easily distinguishable sorts of 'f' nodes that should be on the left side from the other 'f' sons
    my @f_sons1 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') =~ /^[CD]PHR$/} @f_sons; # CPHR or DPHR
    my @f_sons2 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') eq 'ID'} @f_sons; # ID
    # my @sons3 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') eq 'APP'} @f_sons; # APP; arguments are missing here
    # all other types of nodes will be left on the right side of these (difficult to distinguish)
    # nodes from @f_sons1
    my @f_nodes_ok = @f_sons1;
    move_siblings_left(\@f_sons1, \@f_nodes_ok, \@f_sons);
    push(@f_nodes_ok, @f_sons2); # all these nodes can be on the left side from nodes from @t_sons2
    move_siblings_left(\@f_sons2, \@f_nodes_ok, \@f_sons);
    # all other types of nodes (RSTRS, arguments, other modifications) need to be ordered manually

    # second, move easily distinguishable sorts of 't' and 'c' nodes that should be on the right side from the other 't' or 'c' sons
    my @tc_sons1 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {$_->get_attr('functor') =~ /^[CD]PHR$/} @tc_sons; # CPHR or DPHR
    my @tc_sons2 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {$_->get_attr('functor') eq 'ID'} @tc_sons; # ID
    # nodes from @tc_sons1
    my @tc_nodes_ok = @tc_sons1;
    move_siblings_right(\@tc_sons1, \@tc_nodes_ok, \@tc_sons);
    # nodes from @tc_sons2
    push(@tc_nodes_ok, @tc_sons2); # all these nodes can be on the right side from nodes from @tc_sons2
    move_siblings_right(\@tc_sons2, \@tc_nodes_ok, \@tc_sons);
    # all other types of nodes (RSTRS, arguments, other modifications) need to be ordered manually
  } # noun phrase

  # ========= verb phrases =========

  if (defined($father_sempos) and $father_sempos =~ /^v/) { # a verb phrase
    # move easily distinguishable sorts of 't' and 'c' nodes that should be on the left side from the other 't' or 'c' sons
    my @tc_sons1 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') eq 'VOCAT'} @tc_sons; # VOCAT
    my @tc_sons2 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') eq 'PREC'} @tc_sons; # PREC
    my @tc_sons3 = sort {$a->get_attr('ord') <=> $b->get_attr('ord')} grep {$_->get_attr('functor') eq 'ATT'} @tc_sons; # ATT
    # categories 4 to 6 from the manual are difficult to distinguish
    my @tc_sons7 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {!$_->get_attr('a/lex.rf')} grep {$_->get_attr('is_generated') and $_->get_attr('is_generated') eq '1'} @tc_sons; # generated nodes without a surface counterpart
    my @tc_sons8 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {$_->get_attr('a/lex.rf')} grep {$_->get_attr('t_lemma') eq '#PersPron'} @tc_sons; # nodes expressed on the surface with t_lemma #PersPron
    my @t_sons9 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')} grep {$_->get_attr('a/lex.rf')} grep {$_->get_attr('functor') =~ /(^T|^DIR)/} grep {$_->get_attr('tfa') eq 't'} @tc_sons; # nodes expressed on the surface with a space or time functor
    my @f_sons10 = ();
    my $father_lex_rf = $father->get_attr('a/lex.rf');
    if ($father_lex_rf and $father->get_attr('tfa') and $father->get_attr('tfa') eq 'f') { # father node is in focus and has a lexical counterpart
      my $father_lex = $father->get_lex_anode();
      my $father_lex_ord = $father_lex->get_attr('ord');
      # print STDERR "father lex ord = $father_lex_ord\n";
      @f_sons10 = sort {$b->get_attr('ord') <=> $a->get_attr('ord')}
                  grep {$_->get_attr('a/lex.rf') and $_->get_lex_anode()->get_attr('ord')<$father_lex_ord}
                  grep {$_->get_attr('t_lemma') ne '#Neg'}
                  grep {$_->get_attr('functor') eq 'RHEM'}
                  @f_sons; # RHEMs (but not #Neg) in focus that are on the surface on the left from the governing verb
    }
    # print STDERR "There are " . scalar(@f_sons10) . " RHEMS to be moved to the left from the governing verb.\n";

    # nodes that should be placed on the left from the others
    my @tc_nodes_ok = @tc_sons1;
    move_siblings_left(\@tc_sons1, \@tc_nodes_ok, \@tc_sons);
    push (@tc_nodes_ok, @tc_sons2);
    move_siblings_left(\@tc_sons2, \@tc_nodes_ok, \@tc_sons);
    push (@tc_nodes_ok, @tc_sons3);
    move_siblings_left(\@tc_sons3, \@tc_nodes_ok, \@tc_sons);

    # nodes that should be placed on the right from the others
    # first, move some RHEMS from the right of the governing node just to the left of it (right from all @tc_nodes)
    @tc_nodes_ok = @tc_sons;
    push(@tc_nodes_ok, @f_sons10);
    my @nodes_to_skip = @f_sons;
    push (@nodes_to_skip, $father);
    move_siblings_left(\@f_sons10, \@tc_nodes_ok, \@nodes_to_skip);
    # now take care of the tc_nodes that need to be close to the verb
    @tc_nodes_ok = @f_sons10;
    push (@tc_nodes_ok, @t_sons9);
    move_siblings_right(\@t_sons9, \@tc_nodes_ok, \@tc_sons);
    push (@tc_nodes_ok, @tc_sons8);
    move_siblings_right(\@tc_sons8, \@tc_nodes_ok, \@tc_sons);
    push (@tc_nodes_ok, @tc_sons7);
    move_siblings_right(\@tc_sons7, \@tc_nodes_ok, \@tc_sons);
    # noded of categories 4 to 6 from the manual remain in between and need to be oredered manually
  } # verb phrase

} # check_sons_order

# it checks the deepord of non-member sons of a coap node and moves them if necessary according to rules of communicative dynamism
sub check_sons_order_coap {
  my ($father) = @_;
  my @sons = $father->get_children();
  my @relevant_sons = grep {!($_->get_attr('is_member') and $_->get_attr('is_member') eq '1')} grep {is_tfa_relevant($_)} @sons;
  my @tfa_sons = grep {defined($_->get_attr('tfa'))} @relevant_sons;
  if (scalar(@relevant_sons) > scalar(@tfa_sons)) { # not all tfa-relevant nodes have been set a tfa value yet
    return;
  }
  my @f_sons = grep {$_->get_attr('tfa') eq 'f'} @relevant_sons;
  my @tc_sons = grep {$_->get_attr('tfa') =~ /^[tc]$/} @relevant_sons;
  my @member_sons = grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq '1'} @sons;

  # nodes that should be placed on the left from the others
  my @tc_nodes_ok = @tc_sons;
  my @nodes_to_skip = @tc_sons;
  push (@nodes_to_skip, @member_sons);
  move_siblings_left(\@tc_sons, \@tc_nodes_ok, \@nodes_to_skip);

  # nodes that should be placed on the right from the others
  my @f_nodes_ok = @f_sons;
  @nodes_to_skip = @f_sons;
  push (@nodes_to_skip, @member_sons);
  move_siblings_right(\@f_sons, \@f_nodes_ok, \@nodes_to_skip);
} # check_sons_order_coap

sub move_siblings_left {
  my ($p_nodes_to_move, $p_nodes_not_to_skip, $p_all_nodes) = @_;
  foreach my $node (@$p_nodes_to_move) {
    my $node_deepord = $node->get_attr('ord');
    my @wrong_left_from_node = grep {!defined(Treex::PML::Index($p_nodes_not_to_skip, $_))} grep {$_->get_attr('ord') < $node_deepord} @$p_all_nodes; # nodes left from $node that are not in @$node_not_to_skip
    while (@wrong_left_from_node) { # there are some nodes that need to be skipped
      move_subtree_left_auto($node);
      $node_deepord = $node->get_attr('ord');
      @wrong_left_from_node = grep {!defined(Treex::PML::Index($p_nodes_not_to_skip, $_))} grep {$_->get_attr('ord') < $node_deepord} @$p_all_nodes; # nodes left from $node that are not in @$node_not_to_skip
    }
  }
} # move_siblings_left

sub move_siblings_right {
  my ($p_nodes_to_move, $p_nodes_not_to_skip, $p_all_nodes) = @_;
  foreach my $node (@$p_nodes_to_move) {
    my $node_deepord = $node->get_attr('ord');
    my @wrong_right_from_node = grep {!defined(Treex::PML::Index($p_nodes_not_to_skip, $_))} grep {$_->get_attr('ord') > $node_deepord} @$p_all_nodes; # nodes right from $node that are not in @$node_not_to_skip
    while (@wrong_right_from_node) { # there are some nodes that need to be skipped
      move_subtree_right_auto($node);
      $node_deepord = $node->get_attr('ord');
      @wrong_right_from_node = grep {!defined(Treex::PML::Index($p_nodes_not_to_skip, $_))} grep {$_->get_attr('ord') > $node_deepord} @$p_all_nodes; # nodes right from $node that are not in @$node_not_to_skip
    }
  }
} # move_siblings_right



# It adds a log to the comment of type TFA_log
sub add_log {
  my ($node, $log) = @_;

=item

  my @comment = grep {defined($_->{'type'}) and $_->{'type'} eq 'TFA_log'} ListV($node->get_attr('annot_comment'));
  my $new_log;
  if (!@comment) {
    $new_log = $log;
    AddToList($node,'annot_comment', {'type' => 'TFA_log',
                                      'text' => $log});
  }
  else {
    my $prev_log = $comment[0]->{'text'};
    if (!defined($prev_log)) {
      $prev_log = '';
    }
    # print STDERR "The prev log is '$prev_log'\n";
    $new_log = $prev_log . '@' . $log;
    $comment[0]->{'text'} = $new_log;
  }
  my $id = $node->get_attr('id');
  print STDERR "log:\t$id\t$log\n";
  # print STDERR "The new log is '$new_log'\n";

=cut

} # add_log


=item

  The function pre-annotates some TFA-values in the subtree of a given node (incl.); it annotates the individual nodes

=cut

sub pre_annotate {
  my ($root_node) = @_;
  my @nodes_without_tfa = get_tfa_relevant_without_tfa($root_node->get_descendants({ordered=>1, add_self=>0}));
  my $changed = 0;
  if (@nodes_without_tfa) {
    foreach my $node_without_tfa (@nodes_without_tfa) {
      $changed += pre_annotate_node($node_without_tfa);
    }
  }
  return $changed;
} # pre_annotate

=item

  The function pre-annotates some TFA-values in the subtree of a given node (incl.); it annotates sons of 'f' verbs not in the second position etc.

=cut

sub pre_annotate_2 {
  my ($root_node) = @_;
  my @tfa_relevant_nodes = grep {is_tfa_relevant($_)} $root_node->get_descendants({ordered=>1, add_self=>1});
  my $changed = 0;

  # sons of verbs:
  my @verbs = grep {$_->get_attr('gram/sempos') and $_->get_attr('gram/sempos') eq 'v'} @tfa_relevant_nodes;
  foreach my $verb (@verbs) {
    if ($verb->get_attr('tfa') and $verb->get_attr('tfa') eq 'f' and !in_second_position($verb)) {
      $changed += pre_annotate_sons_of_verb($verb);
    }
  }
  
=item

V povrchovém slovosledu v analytické rovině poslední přímý potomek uzlu s funktory PRED, DENOM nebo PAR má tfa=f.
V povrchovém slovosledu v analytické rovině poslední přímý potomek uzlu s gram/verbmod=cdn nebo imp nebo ind má tfa=f.
Výjimkou jsou dogenerované a dokopírované uzly. Pokud jsou ty posledním přímým potomkem, pak tfa=f musí mít jejich děti.
Tím by se měla oanotovat vlastní ohniska. Pavel přijel zase jednou do práce.
=cut

  my @nodes = grep {($_->get_attr('gram/verbmod') and $_->get_attr('gram/verbmod') =~ /^(cdn|imp|ind)$/) or $_->get_attr('functor') =~ /^(PRED|DENOM|PAR)$/} @tfa_relevant_nodes;
  foreach my $node (@nodes) {
    my @sons = $node->get_children({ordered=>1});
    if (scalar(@sons)) {
      my $last_son = $sons[-1];
      if (is_tfa_relevant($last_son)) {
        if (!$last_son->get_attr('is_generated')) {
          set_tfa_at_node($last_son, 'f');
          add_log($last_son, 'A2_lastson_f');
          check_siblings_order($last_son);
          $changed ++;
        }
        else { # last son generated
          my @grandsons = grep {is_tfa_relevant($_)} $last_son->get_echildren();
          foreach my $grandson (@grandsons) {
            set_tfa_at_node($grandson, 'f');
            add_log($grandson, 'A2_lastsonseson_f');
            check_siblings_order($grandson);
            $changed ++;
          }
        }
      }
      else { # not tfa relevant
        if ($last_son->get_attr('nodetype') eq 'coap') {
          my @grandsons = grep {is_tfa_relevant($_)} $last_son->get_children();
          foreach my $grandson (@grandsons) {
            set_tfa_at_node($grandson, 'f');
            add_log($grandson, 'A2_lastsonscoapson_f');
            check_siblings_order($grandson);
            $changed ++;
          }
        }
      }
    }
  }

  return $changed;
} # pre_annotate_2


=item

  The function checks if all non-generated member nodes (members of coordination etc.) have the same tfa value; if not, the majority value among the esiblings is put to the non-annotated members

=cut

sub pre_annotate_3 {
  my ($root_node) = @_;
  my @leftmost_member_nodes = grep {scalar($_->get_esiblings({preceding_only=>1})) eq 0} grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq 1} grep {is_tfa_relevant($_)} $root_node->get_descendants({add_self=>0});
  foreach my $node (@leftmost_member_nodes) {
    my @esiblings = grep {is_tfa_relevant($_)} $node->get_esiblings({add_self => 1});
    check_esiblings(@esiblings);
  }
}

sub check_esiblings {
  my @nodes = @_;
  my @f = grep {$_->get_attr('tfa') and $_->get_attr('tfa') eq 'f'} @nodes;
  my @t = grep {$_->get_attr('tfa') and $_->get_attr('tfa') eq 't'} @nodes;
  my @c = grep {$_->get_attr('tfa') and $_->get_attr('tfa') eq 'c'} @nodes;
  if (scalar(@f) or scalar(@t) or scalar(@c)) {
    my @without_tfa = grep {!$_->get_attr('tfa')} @nodes;
    if (scalar(@without_tfa)) {
      my $tfa_max = 'f';
      $tfa_max = 't' if (scalar(@t) > scalar(@f));
      $tfa_max = 'c' if (scalar(@c) > scalar(@f) and scalar(@c) > scalar(@t));
      foreach my $n (@without_tfa) {
        set_tfa_at_node($n, $tfa_max);
        add_log($n, 'A3_esiblings_' . $tfa_max);
      }
      check_siblings_order($without_tfa[0]);      
    }
  }
}


=item

  The function checks whether the given verb node is on the second position in the clause.

=cut

sub in_second_position {
  my ($verb) = @_;
  my $verb_deepord = $verb->get_attr('ord');
  my @sons =  $verb->get_children();
  if ($verb->get_attr('is_member')) {
    my $coap = $verb->get_parent();
    my @non_member_brothers = grep {!$_->get_attr('is_member')} $coap->get_children();
    if (scalar(@non_member_brothers)) {
      push (@sons, @non_member_brothers);
    }
  }
  my @relevant = grep {!$_->get_attr('is_generated')} grep {$_->get_attr('functor') !~ /^(CM|PREC|RHEM)$/} grep {!$_->get_attr('is_parenthesis')} @sons; # get rid of unimportant nodes
  my @left = grep {$verb_deepord > $_->get_attr('ord')} @relevant; # take only nodes that are left from the verb
  if (scalar(@left) > 1) { # not on the first or second position
    return 0;
  }
  return 1;
} # in_second_position


=item

  The function tries to pre-annotate a TFA-value at the given node
  Return 1 if the node has been pre-annotated; otherwise 0

=cut

sub pre_annotate_node {
  my ($node) = @_;
  if (!is_tfa_relevant($node)) {
    return 0;
  }
  if ($node->get_attr('tfa')) {
    return 0;
  }
  my $t_lemma = $node->get_attr('t_lemma') // '';
  my $functor = $node->get_attr('functor') // '';
  my $id = $node->get_attr('id');
  my $is_generated = $node->get_attr('is_generated') // 0;

  # print STDERR "Preannotation: checking node $t_lemma ($functor), id=$id\n";

  # ========================================

  # print STDERR "Preannotation: checking if the node is generated and without an analytical counterpart (and ...); expected error rate: 0\n";
  if ($is_generated) {
    if ($t_lemma ne '#Forn' and $functor ne 'RHEM' and !$node->get_attr('a/lex.rf')) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_gen_t');
      check_siblings_order($node);
      #ChangingFile(1);
      return 1;
    }
  }

  # ========================================

  # print STDERR "Preannotation: checking if the node is a generated member of coordination/apposition with an analytical counterpart\n";
  # print STDERR "-> 't' if there is no right non-generated with the same t_lemma, otherwise -> 'f'; expected error rate: 0\n";
  if ($is_generated) {
    if ($t_lemma ne '#Forn' and $node->get_attr('a/lex.rf') and $node->get_attr('is_member')) {
      my @same_right_not_generated = grep {$_->get_attr('is_member')} grep {!$_->get_attr('is_generated')} grep {$_->get_attr('t_lemma') eq $t_lemma} $node->get_siblings({following_only=>1});
      if (scalar(@same_right_not_generated)) {
        set_tfa_at_node($node, 'f');
        add_log($node, 'A1_genmemb2_f');
        foreach my $n (@same_right_not_generated) { # probably only one but anyway...
          set_tfa_at_node($n, 't');
          add_log($node, 'A1_genmemb2_t');
        }
      }
      else {
        set_tfa_at_node($node, 't');
        add_log($node, 'A1_genmemb_t');
      }
      check_siblings_order($node);
      #ChangingFile(1);
      return 1;
    }
  }

  # ========================================

  # print STDERR "Preannotation: checking if the node is a generated non-member of coordination/apposition with an analytical counterpart\n";
  # print STDERR "-> 't' ; expected error rate: 0\n";
  if ($is_generated) {
    if ($t_lemma ne '#Forn' and $node->get_attr('a/lex.rf') and !$node->get_attr('is_member')) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_genwithlexnonmemb_t');
      check_siblings_order($node);
      #ChangingFile(1);
      return 1;
    }
  }

  # ========================================

  # print STDERR "Preannotation: checking if a coreference starts at the node $id; expected error rate: 1:100\n";
  if ($node->get_coref_gram_nodes()) {
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_corefgr_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }
  if ($node->get_coref_text_nodes()) {
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_coreftx_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }
  if ($node->get_attr('coref_special') and $node->get_attr('coref_special') eq 'segm') {
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_corefsg_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  # ========================================

  # print STDERR "Checking if the node $id is PRED\n";
  if ($functor eq 'PRED') {
    # check if it is a verb of direct speech
    if ($t_lemma =~ /^(říkat|uvést|říci|dodat|uvádět|dodávat|prohlašovat|prohlásit|konstatovat|tvrdit|doplnit|doplňovat|sdělit|sdělovat|oznámit|oznamovat|pravit|odpovědět|odpovídat|#EmpVerb|#Dash|#Colon)$/) {
      # check if EFF is among its sons
      my @esons_EFF = grep {$_->get_attr('functor') eq 'EFF'} $node->get_echildren();
      if (scalar(@esons_EFF)) {
        set_tfa_at_node($node, 't');
        add_log($node, 'A1_PREDdirect_t');
        check_siblings_order($node);
        foreach my $eson (@esons_EFF) {
          set_tfa_at_node($eson, 'f');
          add_log($node, 'A1_PREDdirectEFF_f');
          check_siblings_order($eson);
        }
        my @esons_ACT = grep {$_->get_attr('functor') eq 'ACT'} $node->get_echildren();
        foreach my $eson (@esons_ACT) {
          set_tfa_at_node($eson, 't');
          add_log($node, 'A1_PREDdirectACT_t');
          check_siblings_order($eson);
        }
        return 1;
      }
    }
    elsif (!$is_generated and !t_lemma_in_prev_sentence($node,1)) { # not generated and the t_lemma is not in the prev. sentence -> 'f'; expected error rate: 1:40
      set_tfa_at_node($node, 'f');
      add_log($node, 'A1_PREDngen_f');
      check_siblings_order($node);
      return 1;
    }
    elsif ($is_generated) { # a generated PRED; expected error rate: less than 1:100
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_PREDgen_t');
      check_siblings_order($node);
      return 1;    
    }
  }

  # ========================================

  # print STDERR "Checking if the node $id is a verb (but not PRED).\n";
  if ($node->get_attr('gram/sempos') and $node->get_attr('gram/sempos') eq 'v') { # a verb but not a PRED (i.e. a head of a subordinated clause)
    if ($functor =~ /^(ADDR|AIM|CAUS|ACMP|MANN|PAT|EFF|AUTH|BEN|COMPL|EXT|ORIG|RESL|TFHL|TSIN)$/) { # a functor with 'f' as a usual TFA-value for a verb in this position; expected error rate: less than or equal to 1:10
      set_tfa_at_node($node, 'f');
      add_log($node, 'A1_v' . $functor . '_f');
      check_siblings_order($node);
      #ChangingFile(1);
      return 1;
    }
  }

  # ========================================

  # print STDERR "Checking for a few functors that highly prefer one of the TFA-values.\n";
  if ($functor eq 'PARTL') { # maybe always in focus -> 'f'; expected error rate: 0
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_PARTL_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  if ($functor eq 'DENOM') { # usually in focus -> 'f'; expected error rate: 1:35
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_DENOM_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  if ($functor eq 'MOD') { # usually in focus -> 'f'; expected error rate: 1:29
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_MOD_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  if ($functor eq 'EXT') { # usually in focus -> 'f'; expected error rate: 1:14
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_EXT_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }
  
  if ($functor eq 'PAR' and !$is_generated) { # usually in focus -> 'f'; expected error rate: 0.08
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_PAR_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  if ($functor eq 'VOCAT') { # usually in focus -> 'f'; expected error rate: ?
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_VOCAT_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }
  
# =======
  
  if ($functor eq 'ATT') { # usually in topic -> 't'; expected error rate: 0
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_ATT_t');
    check_siblings_order($node);
    return 1;
  }

  if ($functor eq 'PREC') { # usually in topic -> 't'; expected error rate: 0
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_PREC_t');
    check_siblings_order($node);
    return 1;
  }

  if ($functor eq 'INTF') { # usually in topic -> 't'; expected error rate: 0
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_INTF_t');
    check_siblings_order($node);
    return 1;
  }

# ===

  if ($functor =~ /^(RSTR|APP|MAT|ID)$/) {
    if ($is_generated) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_RSTR-APP-MAT-ID_gen_t');
      check_siblings_order($node);
      return 1;
    }
    if ($node->get_coref_gram_nodes() or $node->get_coref_text_nodes() or ($node->get_attr('coref_special') and $node->get_attr('coref_special') eq 'segm')) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_RSTR-APP-MAT-ID_coref_t');
      check_siblings_order($node);
      return 1;
    }
    if (t_lemma_in_prev_sentence($node, 5)) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_RSTR-APP-MAT-ID_tlemmaincontext_t');
      check_siblings_order($node);
      return 1;
    }
    my @eparents = $node->get_eparents();
    if (scalar(@eparents and $eparents[0]->get_attr('gram/sempos') and $eparents[0]->get_attr('gram/sempos') =~ /^n/)) {
      my @egrandparents = $eparents[0]->get_eparents(); # I only care about one (any) of them
      if (scalar(@egrandparents) and $egrandparents[0]->get_attr('functor') and $egrandparents[0]->get_attr('functor') =~ /^(PRED|DENOM)$/) {
        if ($node->get_attr('ord') == 1) { # e.g. >>Vyšší<< ceny naopak lákají.
          set_tfa_at_node($node, 'c');
          add_log($node, 'A1_RSTR-APP-MAT-ID_c');
          check_siblings_order($node);
          return 1;
        }
      }
    }
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_RSTR-APP-MAT-ID_f');
    check_siblings_order($node);
    return 1;
  }
  
  
  if ($t_lemma eq '#Neg') {
    my @eparents = $node->get_eparents();
    if (scalar(@eparents)) {
      my $eparent_tfa = $eparents[0]->get_attr('tfa');
      if ($eparent_tfa) {
        if ($eparent_tfa eq 'f') {
          set_tfa_at_node($node, 'f');
          add_log($node, 'A1_Neg_f');
        }
        else {
          set_tfa_at_node($node, 't');
          add_log($node, 'A1_Neg_t');
        }
        check_siblings_order($node);
        #ChangingFile(1);
        return 1;
      }  
    }
  }
  
  if ($functor eq 'RHEM') { 
    # first find the probable rhematized words; it is either the eparenting verbs (if they just follow the rhematizer) or its right brothers
    my $first_position = 0;
    my $lex = $node->get_lex_anode();
    my $lex_ord = $lex->get_attr('ord') // 0;
    if ($lex_ord eq '1') {
      $first_position = 1;
    }

    my @scope = get_rhematized_nodes($node);
    my $scope_eparents = 0; # 0 means that scope consists of ebrothers
    my @right_eparents = grep {$_->get_attr('ord') > $node->get_attr('ord')} $node->get_eparents({ordered => 1});
    my $i=Treex::PML::Index(\@scope,$right_eparents[0]);
    if ($i) {
      $scope_eparents = 1; # 1 means that scope consists of eparents
    }

    if ($first_position) {
      set_tfa_at_node($node, 't');
      add_log($node, 'A1_RHEMfirst_t');
      check_siblings_order($node);
      if (!@scope) {
        return 1;
      }
      if ($scope_eparents) {
        foreach my $right_eparent (@scope) {
          set_tfa_at_node($right_eparent, 't');
          add_log($node, 'A1_RHEMscopeeparents_t');
          check_siblings_order($right_eparent);
        }
      }
      else { # the scope is the first right brother
        if ($scope[0]->get_attr('is_generated')) {
          add_log($node, 'A1_RHEMscopeesibling_t');
          set_tfa_at_node($scope[0], 't');
        }
        else {
          add_log($node, 'A1_RHEMscopeesibling_c');
          set_tfa_at_node($scope[0], 'c');
        }
        check_siblings_order($scope[0]);
      }
      return 1;
    }
    
    else { # not at the first position in the sentence
      if (!@scope) {
        set_tfa_at_node($node, 'f');
        add_log($node, 'A1_RHEMnotfirstnoscope_f');
        check_siblings_order($node);
        return 1;
      }
    
      my $first_scope = $scope[0];
      my $first_scope_tfa = $scope[0]->get_attr('tfa');
      if ($first_scope_tfa) { # set the rhematizer accordingly
        set_tfa_at_node($node, $first_scope_tfa);
        add_log($node, 'A1_RHEMnotfirst_' . $first_scope_tfa);
        check_siblings_order($node);
        return 1;              
      }

      set_tfa_at_node($node, 'f');
      add_log($node, 'A1_RHEM_f');
      check_siblings_order($node);

      foreach my $scope_node (@scope) { # if the rhematizer has just been set to 'f', set all the potential scope nodes (either the right eparents or all right esiblings) to 'f' as well
        set_tfa_at_node($scope_node, 'f');
        add_log($scope_node, 'A1_RHEMscope_f');
        check_siblings_order($scope_node);
      }
      return 1;
    }
  }

=item

functor!=PRED, gram/verbmod!=ind, gram/sempos=v	 	tfa=f
V PDT
t=361, c=183, f=6015 (p=0,92)

Případně:
functor!=PRED, gram/sempos=v	 	tfa=f
V PDT
t=2570, c=605, f=25211 (p=0,89)

Zvážit:
functor=MANN, is_generated!=1, gram/verbmod!=ind / cdn / imp		tfa=f
(vychází to z 87%)

=cut

  if ($functor ne 'PRED' and $node->get_attr('gram/sempos') and $node->get_attr('gram/sempos') eq 'v') {
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_v_notPRED_f');
    check_siblings_order($node);
  }

  if ($functor eq 'MANN' and !$is_generated and (!$node->get_attr('gram/verbmod') or $node->get_attr('gram/verbmod') !~ /^(ind|cdn|imp)$/)) {
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_MANN_f');
    check_siblings_order($node);
  }

  # ========================================

  # print STDERR "Checking for t_lemmas that highly prefer one of the TFA-values.\n";
  if ($t_lemma eq 'tady') { # usually in topic -> 't'; expected error rate: 1:10
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_tady_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  if ($t_lemma eq 'ten') { # usually in topic -> 't'; expected error rate: 1:20
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_ten_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  # ========================================

  # print STDERR "Checking for #-t_lemmas that highly prefer 't'.\n";
  if ($t_lemma =~ /^(#Colon|#Dash|#Comma|#PersPron|#Cor|#Gen|#EmpVerb|#Idph|#Rcp|#AsMuch|#Benef|#Equal|#Oblfm|#QCor|#Some|#Total|#Unsp)$/ ) { # usually in topic -> 't'; expected error rate: various
    set_tfa_at_node($node, 't');
    add_log($node, 'A1_#t_t');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  # ========================================

  # print STDERR "Checking for #-t_lemmas that highly prefer 'f'.\n";
  if ($t_lemma =~ /^(#Period3|#Forn|#Percnt)$/ ) { # usually in focus -> 'f'; expected error rate: various
    set_tfa_at_node($node, 'f');
    add_log($node, 'A1_#f_f');
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  # ========================================

  # print STDERR "Checking for #EmpNoun.\n";
  if ($t_lemma =~ /^(#EmpNoun)$/ ) {
    my @aaux = $node->get_aux_anodes();
    my $tfa = 't'; # usually 't', except in cases such as "jsem pro" or "jsem proti":
    foreach my $a (@aaux) {
      if ($a->get_attr('m/lemma') =~ /^pro/) { # 'pro' or 'proti'
        $tfa = 'f';
        last;
      }
    }
    set_tfa_at_node($node, $tfa);
    add_log($node, 'A1_#EmpNoun-' . $tfa . '_' . $tfa);
    check_siblings_order($node);
    #ChangingFile(1);
    return 1;
  }

  # ========================================

=item

Všem uzlům, které nejsou přímými potomky uzlů s funktory PRED, DENOM, VOCAT, PARTL, PAR a nejsou ani přímými potomky uzlů s gram/verbmod=cdn nebo imp nebo ind, přiřadit hodnotu tfa=f kromě:
    • těch, od kterých vede koreferenční nebo anaforická šipka (těm bychom daly tfa=t),
    • těch, jejichž t-lemma se opakuje v předchozích cca 5 větách (tohle je politické rozhodnutí, prostě musíme nějak ohraničit předchozí kontext; možná i víc než 5, možná 10) (?) (těm bychom daly tfa=t),
    • těch, které jsou dogenerované nebo dokopírované (těm bychom daly tfa=t).

=cut

  my @eparents = $node->get_eparents();
  if (scalar(@eparents)) {
    my $eparent = $eparents[0]; # I only care about one (any, the first) of them
    if (!$eparent->get_attr('functor') or $eparent->get_attr('functor') !~ /^(PRED|DENOM|VOCAT|PARTL|PAR)$/) {
      if (!$eparent->get_attr('gram/verbmod') or $eparent->get_attr('gram/verbmod') !~ /^(cdn|imp|ind)$/) {
        if ($is_generated) {
          set_tfa_at_node($node, 't');
          add_log($node, 'A1_deep_gen_t');
          check_siblings_order($node);
          return 1;
        }
        if ($node->get_coref_gram_nodes() or $node->get_coref_text_nodes() or ($node->get_attr('coref_special') and $node->get_attr('coref_special') eq 'segm')) {
          set_tfa_at_node($node, 't');
          add_log($node, 'A1_deep_coref_t');
          check_siblings_order($node);
          return 1;
        }
        if (t_lemma_in_prev_sentence($node, 5)) {
          set_tfa_at_node($node, 't');
          add_log($node, 'A1_deep_tlemmaincontext_t');
          check_siblings_order($node);
          return 1;
        }
        set_tfa_at_node($node, 'f');
        add_log($node, 'A1_RSTR-APP-MAT-ID_f');
        check_siblings_order($node);
        return 1;
      }
    }
    
=item

Nastavit:

Přímý potomek (is_generated!=1) uzlu s funktorem DENOM má tfa=f.
V PDT:
t= 101, c=10, f=3341 [functor=DENOM]([is_generated!=1,tfa=f])

Přímý potomek (is_generated!=1) uzlu s funktorem VOCAT má tfa=f.
V PDT:
t=4, c=0, f= 13 (s těmi t ale v těch vyhledaných větách moc nesouhlasíme, dávaly bychom tam f)

Přímý potomek (is_generated!=1) uzlu s funktorem PARTL má tfa=f.
V PDT:
t=2, c=0, f=1 (obecně bychom nastavily fakt f, ty t, tam, kde mají být, se když tak předanotujou dřív, v těch větách v PDT šlo totiž o PREC a ATT)

=cut

    if ($eparent->get_attr('functor') and $eparent->get_attr('functor') =~ /^(DENOM|VOCAT|PARTL)$/) {
      if (!$is_generated) {
        set_tfa_at_node($node, 'f');
        add_log($node, 'A1_son_DENOM-VOCAT-PARTL_f');
        check_siblings_order($node);
        return 1;
      }
    }
  }

  
  return 0;
} # pre_annotate_node


sub get_rhematized_nodes {
  my ($rhem) = @_;
  my $rhem_ord = $rhem->get_attr('ord');
  my @right_eparents = grep {$_->get_attr('ord') > $rhem_ord} $rhem->get_eparents({ordered => 1});
  my @right_esiblings = $rhem->get_esiblings({following_only=>1});
  if (@right_eparents and (!@right_esiblings or $right_esiblings[0]->get_attr('ord') > $right_eparents[0]->get_attr('ord'))) { # no right brothers or the first right eparent is closer than the first right esibling
    return @right_eparents;
  }
  return @right_esiblings;
}


sub is_clitic {
  my ($n) = @_;
  my $form = $n->get_attr('m/form');
  my $tag = $n->get_attr('m/tag');
  if ($form =~ /^s[ei]$/ and $tag =~ /^P/) { # se, si
    return 1;
  }
  if ($form =~ /^(jsem|jsi|jsme|jste|ses)$/ and $tag =~ /^V/) { # pomocne sloveso 'být' v min. case
    return 1;
  }
  if ($form =~ /^(bych|bys|by|bychom|byste)$/ and $tag =~ /^V/) { # pomocne sloveso 'být' v podm. zpusobu
    return 1;
  }
  if ($form =~ /^(mi|ti|mu)$/ and $tag =~ /^....3/) { # kratke tvary osobnich zajmen ve 3. pade
    return 1;
  }
  if ($form =~ /^(mě|tě|ho)$/ and $tag =~ /^....4/) { # kratke tvary osobnich zajmen ve 4. pade
    return 1;
  }
  if ($form eq 'tu' and $tag =~ /^D/) { # zkracena verze 'tady'
    return 1;
  }
  return 0;
} # is_clitic


sub pre_annotate_sons_of_verb {
  my ($verb) = @_;
  my @sons_to_annotate = grep {is_tfa_relevant($_)} grep {!defined($_->get_attr('tfa'))} $verb->get_children({ordered=>1});
  my $verb_deepord = $verb->get_attr('ord');
  my $last_changed_node = 0;
  foreach my $son (@sons_to_annotate) {
    if ($son->get_attr('ord') > $verb_deepord) { # I assume that before the TFA annotation, the deep order coppies the surface order
      set_tfa_at_node($son, 'f');
      add_log($son, 'A1_vRson_f');
      $last_changed_node = $son;
    }
  }
  if ($last_changed_node) {
    check_siblings_order($last_changed_node);
    #ChangingFile(1);
    return 1;
  }
  return 0;
} # pre_annotate_sons_of_verb


=item

Checks if the t_lemma of the given node appears in the given number of previous sentences 

=cut

sub t_lemma_in_prev_sentence {
  my ($node, $context_size) = @_;
  my $i=Treex::PML::Index(\@ttrees,$node->get_root());
  if ($i > 0) {
    my $start = List::Util::max(0,$i-$context_size-1);
    my $t_lemma = $node->get_attr('t_lemma');
    for (my $j=$start; $j<$i; $j++) {
      my $prev_root = $ttrees[$j];
      my @t_lemmas_descendants = map {$_->get_attr('t_lemma')} grep {defined($_->get_attr('t_lemma'))} $prev_root->get_descendants({ordered=>1, add_self=>1});
      if (defined(Treex::PML::Index(\@t_lemmas_descendants, $t_lemma))) {
        return 1;
      }
    }
  }
  return 0;
} # t_lemma_in_prev_sentence




1;

__END__

=encoding utf-8


=head1 NAME

Treex::Block::Discourse::CS::MarkTFA

=head1 DESCRIPTION

The block annotates some values of tofic-focus articulation in the file (attribute tfa) in Czech t-layer data.

=head1 AUTHOR

Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>
K. and M. Rysovy <(magdalena.)?rysova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
