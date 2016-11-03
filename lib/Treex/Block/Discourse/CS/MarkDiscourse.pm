package Treex::Block::Discourse::CS::MarkDiscourse;
use Moose;
use Treex::Core::Common;
use Data::Dumper;
use Treex::Core::Node::EffectiveRelations;

extends 'Treex::Core::Block';

my %ha_functor_2_discourse_type = ('CAUS' => 'reason',
                                   'COND' => 'cond',
                                   'CNCS' => 'conc',
                                   'AIM' => 'purp',
                                   'CONTRD' => 'confr',
                                   'SUBS' => 'corr',
                                   
                                   'TTILL' => 'cond', # the most common type for TTILL
                                   'TWHEN' => 'preced', # the most common type fo TWHEN
                                   'TFHL' => 'preced', # the most common type fo TFHL
                                   'THL' => 'cond', # the most common type fo THL
                                   'THO' => 'preced', # the most common type fo THO
                                   'TSIN' => 'reason', # the most common type fo TSIN
                                   
                                   'REAS' => 'reason',
                                   'CSQ' => 'reason',
                                   'ADVS' => 'opp',
                                   'CONFR' => 'confr',
                                   'GRAD' => 'grad',
                                   'CONJ' => 'conj',
                                   'DISJ' => 'disjalt');

# The following table was generated from PDT 3.0 by this query (with the exception of "taky", which was added manually); it represents most frequent discourse types for inter-sentential relations marked by given connectors found by the query:

# t-node $s := 
# [ file() !~ "etest", !same-tree-as $n3, 
#      member discourse $d := 
#      [ t-connectors.rf t-node $c := 
#           [ depth() = "2", functor in {"PREC","RHEM","TWHEN","ATT"}, t_lemma ~ "^(však|a|ale|totiž|proto|tedy|také|taky|ovšem|přitom|potom|navíc|tak|naopak|přesto|zároveň|rovněž|i|například|pak|dále|dokonce|nicméně|jenže|zase|nebo|ten|vždyť|takže|avšak|spíše|ani|nakonec|zato|jen|pouze|stejně|vlastně|prostě|přece|ostatně)$" ], 
#           target_node.rf t-node $n3 := [  ] ] ];
#   >> for $c.t_lemma,$d.discourse_type give $1,$2,count() sort by $1,$3 desc
#   >> give $1,$2,$3,row_number(over $1)
#   >> filter $4 = 1
#   >> give $1,$2

my %ha_inter_connector_level2_2_discourse_type = ('a' => 'conj',
                                                  'ale' => 'opp',
                                                  'ani' => 'conj',
                                                  'avšak' => 'opp',
                                                  'dále' => 'conj',
                                                  'dokonce' => 'grad',
                                                  'i' => 'conj',
                                                  'jen' => 'corr',
                                                  'jenže' => 'opp',
                                                  'nakonec' => 'preced',
                                                  'naopak' => 'confr',
                                                  'například' => 'exempl',
                                                  'navíc' => 'grad',
                                                  'nebo' => 'conjalt',
                                                  'nicméně' => 'opp',
                                                  'ostatně' => 'conj',
                                                  'ovšem' => 'opp',
                                                  'pak' => 'conj',
                                                  'potom' => 'preced',
                                                  'pouze' => 'restr',
                                                  'přesto' => 'conc',
                                                  'přitom' => 'conj',
                                                  'proto' => 'reason',
                                                  'prostě' => 'equiv',
                                                  'přece' => 'opp',
                                                  'rovněž' => 'conj',
                                                  'spíše' => 'corr',
                                                  'stejně' => 'conj',
                                                  'tak' => 'reason',
                                                  'také' => 'conj',
                                                  'taky' => 'conj',
                                                  'takže' => 'reason',
                                                  'tedy' => 'reason',
                                                  'ten' => 'conj',
                                                  'totiž' => 'reason',
                                                  'vlastně' => 'equiv',
                                                  'však' => 'opp',
                                                  'vždyť' => 'explicat',
                                                  'zároveň' => 'conj',
                                                  'zase' => 'conj',
                                                  'zato' => 'confr');
                                   
                                   
my %ha_tak_pak = ('jestliže' => 1, 'kdyby' => 1, 'pokud' => 1, 'jestli' => 1, 'li' => 1, 'protože' => 1, 'jelikož' => 1, 'aby' => 1, 'ačkoliv' => 1, 'přestože' => 1);

my %secondary_intersent_prep_ten_2_discourse_type = ('díky' => 'reason',
                                           'kromě' => 'conj',
                                           'kvůli' => 'reason',
                                           'místo' => 'opp',
                                         'naproti' => 'confr',
                                        'navzdory' => 'conc',
                                          'oproti' => 'opp',
                                           'vedle' => 'conj');

my %connector_ids = ();

my $file_discourse_intra_count;
my $file_discourse_inter_count;

sub process_document {
  my ($self, $doc) = @_;

  $file_discourse_intra_count = 0;
  $file_discourse_inter_count = 0;

  my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;

  
  # read ids of all existing manually annotated connectors in the file to a hash:
  foreach my $t_root (@ttrees) {
    foreach my $t_node ($t_root->get_descendants({ordered=>1, add_self=>0})) {
      my $ref_discourse_arrows = $t_node->get_attr('discourse');
      my @discourse_arrows = ();
      if ($ref_discourse_arrows) {
        @discourse_arrows = @{$ref_discourse_arrows};
      }
      foreach my $arrow (@discourse_arrows) { # take all discourse arrows starting at the given node
        if (!$arrow->{'src'} or $arrow->{'src'} !~ /A_._A/) { # do not store connectives from previously completely automatically annotated relations
          foreach my $connector_id (grep {defined and length} @{$arrow->{'t-connectors.rf'}}) {
            $connector_ids{$connector_id} = 1;
          }
          foreach my $connector_id (grep {defined and length} @{$arrow->{'a-connectors.rf'}}) {
            $connector_ids{$connector_id} = 1;
          }
        }
      }
    }
  }

  
  _discourse_annotate_intra($self,$doc);
  _discourse_annotate_inter($self,$doc);
  
  my $file_discourse_links_count = $file_discourse_inter_count + $file_discourse_intra_count;
  log_info("Number of discourse links created: $file_discourse_links_count (intra: $file_discourse_intra_count, inter: $file_discourse_inter_count)\n");

} # process_document


sub _discourse_annotate_intra {
  my ($self, $doc) = @_;

  my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;

  # read ids of all existing manually annotated connectors in the file to a hash:
  foreach my $t_root (@ttrees) {
    foreach my $t_node ($t_root->get_descendants({ordered=>1, add_self=>0})) {

      my $functor = $t_node->functor;
      my $id = $t_node->id;

      # VERTICAL RELATIONS

      if (finite_verb($t_node) and $functor and $functor =~ /^(CAUS|COND|CNCS|AIM|CONTRD|SUBS|TFHL|THL|THO|TSIN|TTILL|TWHEN)$/) {
        my @eparents = $t_node->get_eparents();
        if (scalar(@eparents)) {
          foreach my $eparent (@eparents) {
            if (finite_verb($eparent)) {

              # print STDERR "A_V_A at node $id (" . $t_node->attr('t_lemma') . ")\n";

              if ($eparent->get_attr('is_generated') and $eparent->get_attr('is_generated') eq 1 and $eparent->functor eq 'CPR') {
                # print STDERR "Not interested in is_generated CPRs.\n";
                next;
              }

              my @eparent_echildren_tak_pak_potom = grep {!defined($connector_ids{$_->id})} grep {$_->t_lemma =~ /^(tak|pak|potom)$/} grep {$_->functor =~ /^(PREC|T.+)$/} $eparent->get_echildren(); # may become a part of the connective
              # lift the governing node if possible
              my $target_node = lift_eparent($eparent, $t_node); # if $eparent is not a predecessor of $t_node and is is_member, recursively climp up through coap nodes

              # get connectors from the dependent node before attempting to lift it
              my @aux_nodes = $t_node->get_aux_anodes();
              my @a_connectors = grep {$_->tag !~ /^V/} grep {$_->form !~ /^(se|si)$/} @aux_nodes;  # everything hidden at the node but verbs and 'se' and 'si'
              my @t_connectors = ();
              if (tak_pak(@a_connectors)) {
                push (@t_connectors, @eparent_echildren_tak_pak_potom);
              }

              # lift the dependent node if possible
              my $start_node = lift_echild($t_node, $target_node); # if $t_node is is_member of a coap node, recursively climb up

              # determine the direction of the arrow
              my $target_dord = $target_node->ord;
              my $start_dord = $start_node->ord;
              if ($functor =~ /^(SUBS)$/ or ($functor =~ /^CONTRD$/ and $start_dord lt $target_dord)) { # switch start and target nodes - the arrow goes from the governing node to the dependent one (in case of CONTRD from right to left)
                # print STDERR "Switching the start and target nodes as required by the functor (functor=$functor, id=$id).\n";
                switch_nodes(\$start_node, \$target_node);
              }
              
              # get other values of the relation
              my $target_id = $target_node->id;
              my $discourse_type = $ha_functor_2_discourse_type{"$functor"};
              if (!$discourse_type) {
                # print STDERR "Did not find a discourse type for functor '$functor'!\n";
                $discourse_type = 'no_discourse_type';
              }
              # my $start_range = 0;
              # my $target_range = 0;
              my $source = 'A_V_A'; # Automatic Vertical Automatic
              my $comment = 'no_comment';
              create_discourse_link($doc, 1, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);
            }
          }
        }
      }
      
      # HORIZONTAL RELATIONS
      
      # chybí zpracování např. "potom" u koordinace s "a" (mělo by být "preced" a šipka doleva)

      if ($t_node->get_attr('nodetype') eq 'coap' and $functor and $functor =~ /^(REAS|CSQ|ADVS|CONFR|GRAD|CONJ|DISJ)$/) {
        my $coap_id = $t_node->id;
        my $coz_case = 0;
        # print STDERR "Checking coap node id='$coap_id' (not interested in #Commas without CM and in #Separs apart from a few special cases - like cases with 'což')\n";
        my @conj_CM_children = grep {$_->functor eq 'CM'} $t_node->get_children();
        if ($t_node->t_lemma eq '#Comma' and !scalar(@conj_CM_children)) {
          if (!coz_case($t_node)) {
            # print STDERR "Not interested in #Commas without CM!\n";
            next; # not interested in commas without CM
          }
          else {
            # print STDERR "Found #Comma without CM but with 'což' and grammatical coreference going from it to another member.\n";
            $coz_case = 1;
          }
        }
        if ($t_node->t_lemma eq '#Separ' and !scalar(@conj_CM_children)) {
          if (!coz_case($t_node)) {
            # print STDERR "Not interested in #Separs without CM!\n";
            next; # not interested in separs without CM
          }
          else {
            # print STDERR "Found #Separ with 'což' and grammatical coreference going from it to another member.\n";
            $coz_case = 1;
          }
        }
        if ($t_node->t_lemma eq '#Bracket' and !scalar(@conj_CM_children)) {
          if (!coz_case($t_node)) {
            # print STDERR "Not interested in #Brackets without CM!\n";
            next; # not interested in brackets without CM
          }
          else {
            # print STDERR "Found #Bracket with 'což' and grammatical coreference going from it to another member.\n";
            $coz_case = 1;
          }
        }
        if ($t_node->t_lemma eq '#Semicolon' and !scalar(@conj_CM_children)) {
          if (!coz_case($t_node)) {
            # print STDERR "Not interested in #Semicolons without CM!\n";
            next; # not interested in semicolons without CM
          }
          else {
            # print STDERR "Found #Bracket with 'což' and grammatical coreference going from it to another member.\n";
            $coz_case = 1;
          }
        }
        if ($t_node->t_lemma eq '#Slash' and !scalar(@conj_CM_children)) {
          if (!coz_case($t_node)) {
            # print STDERR "Not interested in #Slashes without CM!\n";
            next; # not interested in slashes without CM
          }
          else {
            # print STDERR "Found #Slash with 'což' and grammatical coreference going from it to another member.\n";
            $coz_case = 1;
          }
        }
        # print STDERR "Coap node id='$coap_id'\n";
        my @is_member_children = sort {$a->ord <=> $b->ord} grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq 1} $t_node->get_children(); # take is_member children and sort them  
        my @is_member_children_finite = grep {finite_verb_is_member_recursive($_)} @is_member_children; # and take only those that are or recursively over is_member have in subtree a finite verb
        my $number_of_finite_children = scalar(@is_member_children_finite);
        if ($number_of_finite_children >= 2) { # if there are at least two such children
          # print STDERR "A_H_A or A_H_M at node $coap_id (" . $t_node->t_lemma . ")\n";
          my $last_link = 0;
          for (my $i=0; $i<$number_of_finite_children-1; $i++) {
            # create a link from $is_member_children_finite[$i+1] do $is_member_children_finite[$i]
            if ($i == $number_of_finite_children-2) { # last link
              $last_link = 1;
            }
            my @t_connectors = ();
            my @a_connectors = ();
            if ($coz_case) {
              my $coz_node = coz_case($t_node);
              if ($coz_node) {
                push(@t_connectors, $coz_node);
              }
            }
            else {
              if ($last_link) { # last link
                # set connective to what is at the coap node ($t_node) and whatever is at its children with functor CM (Conjunction Modifier)
                push(@t_connectors, $t_node);
                push (@t_connectors, @conj_CM_children);
                if ($t_node->t_lemma eq '#Comma' and scalar(@conj_CM_children)) { # get rid of the comma if present among connectors of #Comma with CM
                  @t_connectors = grep {$_->t_lemma ne '#Comma'} @t_connectors;
                }
              }
            }
            my $start_node = $is_member_children_finite[$i+1];
            my $target_node = $is_member_children_finite[$i];
            my $target_id = $target_node->id;
            my $discourse_type = $ha_functor_2_discourse_type{"$functor"};
            if (!$discourse_type) {
              # print STDERR "Did not find a discourse type for functor '$functor'!\n";
              $discourse_type = 'no_discourse_type';
            }
            my $source = 'A_H_A';
            # my $start_range = 0;
            # my $target_range = 0;
            my $comment = 'no_comment';
            if ($last_link) { # get rid of this 'if' to enable creation of other than last links at coap nodes with more than two finite verb sons
              create_discourse_link($doc, 1, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);
            }
          }
        }
        
        # the following part is a copy of the prev. part but now we search for non-finite verbs that are PREDs
        
        my @is_member_children_PRED_not_finite = grep {PRED_not_finite_verb_is_member_recursive($_)} @is_member_children; # and take only those that are or recursively over is_member have in subtree a non-finite verb that is PRED
        my $number_of_PRED_not_finite_children = scalar(@is_member_children_PRED_not_finite);
        if ($number_of_PRED_not_finite_children >= 2) { # if there are at least two such children
          # print STDERR "A_H_A at node $coap_id (" . $t_node->attr('t_lemma') . "), case of PRED not-finite verbs\n";
          my $last_link = 0;
          for (my $i=0; $i<$number_of_PRED_not_finite_children-1; $i++) {
            # create a link from $is_member_children_PRED_not_finite[$i+1] do $is_member_children_PRED_not_finite[$i]
            if ($i == $number_of_PRED_not_finite_children-2) { # last link
              $last_link = 1;
            }
            my @t_connectors = ();
            my @a_connectors = ();
            if ($coz_case) {
              push(@t_connectors, coz_case($t_node));
            }
            else {
              if ($last_link) { # last link
                # set connective to what is at the coap node ($t_node) and whatever is at its children with functor CM (Conjunction Modifier)
                push(@t_connectors, $t_node);
                push (@t_connectors, @conj_CM_children);
                if ($t_node->t_lemma eq '#Comma' and scalar(@conj_CM_children)) { # get rid of the comma if present among connectors of #Comma with CM
                  @t_connectors = grep {$_->t_lemma ne '#Comma'} @t_connectors;
                }
              }
            }
            my $start_node = $is_member_children_PRED_not_finite[$i+1];
            my $target_node = $is_member_children_PRED_not_finite[$i];
            my $target_id = $target_node->id;
            my $discourse_type = $ha_functor_2_discourse_type{"$functor"};
            if (!$discourse_type) {
              # print STDERR "Did not find a discourse type for functor '$functor'!\n";
              $discourse_type = 'no_discourse_type';
            }
            my $source = 'A_H_A';
            # my $start_range = 0;
            # my $target_range = 0;
            my $comment = 'no_comment';
            if ($last_link) { # get rid of this 'if' to enable creation of other than last links at coap nodes with more than two finite verb sons
              create_discourse_link($doc, 1, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);
            }
          }
        }
      }
    }
  }
} # _discourse_annotate_intra


sub _discourse_annotate_inter {
  my ($self, $doc) = @_;

  my $prev_root;

  my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;

  # read ids of all existing manually annotated connectors in the file to a hash:
  foreach my $t_root (@ttrees) {
    foreach my $t_node ($t_root->get_descendants({ordered=>1, add_self=>0})) {

      my $functor = $t_node->functor;
      my $id = $t_node->id;
      my $t_lemma = $t_node->t_lemma;
      
      my $parent = $t_node->get_parent();

      if ($prev_root) { # can only create a leftward inter-sentential relation if this is not the first sentence

        # CONNECTOR AT LEVEL 2
        
        if ($t_node->get_depth() == 1) { # the connector word must be a child of the linguistic root (i.e. a child of this $t_node)
          my @connectors = grep {$_->functor and $_->functor =~ /^(PREC|RHEM|TWHEN|ATT)$/}
                           grep {$_->t_lemma and $_->t_lemma =~ /^(však|a|ale|totiž|proto|tedy|také|taky|ovšem|přitom|potom|navíc|tak|naopak|přesto|zároveň|rovněž|i|například|pak|dále|dokonce|nicméně|jenže|zase|nebo|ten|vždyť|takže|avšak|spíše|ani|nakonec|zato|jen|pouze|stejně|vlastně|prostě|přece|ostatně)$/}
                           $t_node->get_children();
          if (scalar(@connectors)) { # found one or more connectors
            my $start_node = $t_node;
            my $target_node = ($prev_root->get_children())[0]; # usually there is one linguistic child below the technical root
            my $target_id = $target_node->id;
            my @core_connectors = simplify(@connectors); # if the connective is compounded with 'a', e.g. "a proto", take only the "proto" to determine the discourse type
            my $discourse_type = $ha_inter_connector_level2_2_discourse_type{$core_connectors[0]->t_lemma};
            if (!$discourse_type) {
              log_warn("Did not find a discourse type for inter-sentential level 2 t_lemma '" . $core_connectors[0]->t_lemma . "'!");
              $discourse_type = 'no_discourse_type';
            }
            my $source = 'A_I_A';
            my $comment = 'no_comment';
            my @t_connectors = @connectors;
            my @a_connectors = ();
            
            create_discourse_link($doc, 0, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);
          }

          # SECONDARY CONNECTIVES PREP+TEN WITHOUT 'že'
          my @tens_with_prep = grep {has_selected_prep($_)} # check if there is one of the selected prepositions
                               grep {without_ze($_)} # check that there is no 'že'
                               grep {$_->wild->{entity_event} and $_->wild->{entity_event} eq 'EVENT'} # check that it refers to an event (not an entity)
                               grep {$_->t_lemma and $_->t_lemma eq 'ten'}
                               $t_node->get_children();
          if (scalar(@tens_with_prep)) { # found one or more such secondary connectives
            my $ten = $tens_with_prep[0]; # take only the first one (it is unlikely that there are more)
            my $prep = has_selected_prep($ten); # take the preposition
            my $start_node = $t_node;
            my $target_node = ($prev_root->get_children())[0]; # usually there is one linguistic child below the technical root
            if (lc($prep->form) eq 'kvůli' or lc($prep->form) eq 'díky') {
              switch_nodes(\$start_node, \$target_node);
            }
            my $target_id = $target_node->id;
            my $discourse_type = $secondary_intersent_prep_ten_2_discourse_type{lc($prep->form)};
            if (!$discourse_type) {
              log_warn("Did not find a discourse type for inter-sentential secondary connective '" . lc($prep->form) . " + ten'!");
              $discourse_type = 'no_discourse_type';
            }
            else {
              log_info("A secondary connective found: '" . lc($prep->form) . " + ten'!");
            }
            my $source = 'A_I_A';
            my $comment = 'no_comment';
            my @t_connectors = ();
            my @a_connectors = ($prep);

            create_discourse_link($doc, 0, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);

          }
        }

        # CONNECTOR AT LEVEL 3
        
        elsif ($t_node->get_depth() == 2 and $functor and $functor eq 'PRED' and $parent->nodetype and $parent->nodetype eq 'coap' and $parent->ord>$t_node->ord) { # the connector word must be a child of a PRED (i.e. a child of this $t_node) that is a left child of a coap node
          my @connectors = grep {$_->functor and $_->functor =~ /^(PREC|RHEM|TWHEN|ATT)$/}
                           grep {$_->t_lemma and $_->t_lemma =~ /^(však|a|ale|totiž|proto|tedy|také|taky|ovšem|přitom|potom|navíc|tak|naopak|přesto|zároveň|rovněž|i|například|pak|dále|dokonce|nicméně|jenže|zase|nebo|ten|vždyť|takže|avšak|spíše|ani|nakonec|zato|jen|pouze|stejně|vlastně|prostě|přece|ostatně)$/}
                           $t_node->get_children();
          if (scalar(@connectors)) { # found one or more connectors
            my $start_node = $t_node;
            my $target_node = ($prev_root->get_children())[0]; # usually there is one linguistic child below the technical root
            my $target_id = $target_node->id;
            my @core_connectors = simplify(@connectors); # if the connective is compounded with 'a', e.g. "a proto", take only the "proto" to determine the discourse type
            my $discourse_type = $ha_inter_connector_level2_2_discourse_type{$core_connectors[0]->t_lemma};
            if (!$discourse_type) {
              log_warn("Did not find a discourse type for inter-sentential level 2 t_lemma '" . $core_connectors[0]->t_lemma . "'!");
              $discourse_type = 'no_discourse_type';
            }
            my $source = 'A_I_A';
            my $comment = 'no_comment';
            my @t_connectors = @connectors;
            my @a_connectors = ();
            
            create_discourse_link($doc, 0, $start_node, $target_id, 'discourse', $discourse_type, \@t_connectors, \@a_connectors, $source, $comment);
          }
        }

      }

    }
    
    $prev_root = $t_root;
  }

} # _discourse_annotate_inter

# --------- t-node discourse-related functions ----------

sub add_discourse_relation {
    my ($self, $refha_link) = @_;
    my $links_rf = $self->get_attr('discourse');
    push(@$links_rf, $refha_link);
    $self->set_attr('discourse', $links_rf);
    return;
}
    

# -------------------------------------------------------

sub _get_node_by_id {
    my ( $self, $id ) = @_;
    my $doc = $self->get_document;
    return $doc->get_node_by_id($id);
}

# -------------------------------------------------------

sub simplify { # if the connective is compounded with 'a', e.g. "a proto", take only the "proto" to determine the discourse type
  my @connectors = @_;
  my @simplified = @connectors;
  if (scalar(@connectors) > 1) { # the connective consists of more than one word
    @simplified = grep {$_->t_lemma ne 'a'} @connectors; # get rid of 'a's
  }
  if (scalar(@simplified)) { # if it was not only several 'a's
    return @simplified;
  }
  else {
    return @connectors;
  }
}

sub create_discourse_link {
  my ($doc, $intra, $start_node, $target_id, $type, $discourse_type, $ref_t_connectors, $ref_a_connectors, $source, $comment) = @_;
  my $target_node = _get_node_by_id($start_node, $target_id);
  my $connective = get_surface_connective($ref_t_connectors, $ref_a_connectors);
  # log_info("Going to create a '$type' link from @" . $start_node->id . "@ to @" . $target_id . "@ (@" . $start_node->t_lemma . "@ -> @" . $target_node->t_lemma . "@) with discourse type: @" . $discourse_type . "@ (connective: @" . $connective . "@), and source: @" . $source . "@, comment: @" .  $comment . "@\n");

  # there should not be any manual link going from the start_node to the target_id
  if (manual_link_exists($start_node, $target_id)) {
    log_info("A conflict: A manual link already exists here! Not doing anything!");
  }
  # neither from the target_node to the start_node
  if (manual_link_exists($target_node, $start_node->id)) {
    log_info("A conflict: A manual link (in the opposite direction) already exists here! Not doing anything!");
    return;
  }

  my @prev_t_connectors = ();
  my @prev_a_connectors = ();
  # in any case first remove all previous automatic links going from the start_node to the target_id; but save the information about the connective if present
  if (automatic_link_exists($start_node, $target_id)) {
    @prev_t_connectors = grep {defined and length} get_existing_t_connectors($doc, $start_node, $target_id);
    @prev_a_connectors = grep {defined and length} get_existing_a_connectors($doc, $start_node, $target_id);
    my $prev_connective = get_surface_connective(\@prev_t_connectors, \@prev_a_connectors);
    #log_info('Stored the prevously annotated connective: @' . $start_node->id . '@ -> @' . $target_id . '@: @' . $prev_connective . "@\n");
  }

  my @t_connectors = @{$ref_t_connectors};
  my @a_connectors = @{$ref_a_connectors};

  my $start_range = 0;
  my $target_range = 0;
  my $start_group_id = undef;
  my $target_group_id = undef;

  if ($target_id eq 'no_target_id') {
    $target_id = undef;
  }

  my $multiple_connectors = 0; # connectors acquired from several parts of a coordination
  if (!(scalar(@t_connectors) or scalar(@a_connectors))) {
    if (scalar(@prev_t_connectors) or scalar(@prev_t_connectors)) {
      @t_connectors = @prev_t_connectors;
      @a_connectors = @prev_a_connectors;
      $connective = get_surface_connective(\@t_connectors, \@a_connectors);
      log_info('Using previously found connective for the link: @' . $start_node->id . '@ -> @' . $target_id . '@: @' . $connective . "@");
    }
    else {
      @t_connectors = undef;
      @a_connectors = undef;
    }
  }
  else { # there is a connector acquired from this place
    if (scalar(@prev_t_connectors) or scalar(@prev_t_connectors)) { # there is also a connector from a previously processed node of the coordination
      foreach my $one_t_connector (@prev_t_connectors) {
        if (!is_member($one_t_connector, @t_connectors)) {
          push(@t_connectors, $one_t_connector);
          $multiple_connectors = 1;
        }
      }
      foreach my $one_a_connector (@prev_a_connectors) {
        if (!is_member($one_a_connector, @a_connectors)) {
          push(@a_connectors, $one_a_connector);
          $multiple_connectors = 1;
        }
      }
      $connective = get_surface_connective(\@t_connectors, \@a_connectors);
      if ($multiple_connectors) {
        log_info('Adding previously found connective for the link: @' . $start_node->id . '@ -> @' . $target_id . '@: @' . $connective . "@");
      }
    }
  }
    
  if ($comment eq 'no_comment') {
    $comment = undef;
  }
  if ($discourse_type eq 'no_discourse_type') {
    $discourse_type = undef;
  }

  # remove the previous automatic link and create a new one
  remove_automatic_links($start_node, $target_id);
  # log_info('Removed previous automatic annotation: @' . $start_node->id . '@ -> @' . $target_id . "@\n");

  # log_info("Calling add_discourse_relation...\n");
  
  my @t_connectors_ids = map {$_->id} grep {defined and length} @t_connectors;
  my @a_connectors_ids = map {$_->id} grep {defined and length} @a_connectors;

  my %new_link = ('target_node.rf' => $target_id,
                            'type' => $type,
                  'discourse_type' => $discourse_type,
                     'start_range' => $start_range,
                    'target_range' => $target_range,
                  'start_group_id' => $start_group_id,
                 'target_group_id' => $target_group_id,
                             'src' => $source,
                 't-connectors.rf' => \@t_connectors_ids,
                 'a-connectors.rf' => \@a_connectors_ids,
                         'comment' => $comment);
  
  add_discourse_relation($start_node, \%new_link);

  if (!defined($comment)) {
    $comment = 'no_comment';
  }
  if (!defined($discourse_type)) {
    $discourse_type = 'no_discourse_type';
  }

  log_info("A discourse link was created: type '$type', from @" . $start_node->{'id'} . "@ to @" . $target_id . "@ (@" . $start_node->attr('t_lemma') . "@ -> @" . $target_node->attr('t_lemma') . "@) with discourse type: @" . $discourse_type . "@ (connective: @" . $connective . "@), and source: @" . $source . "@, start_range: @" . $start_range . "@, target_range: @" . $target_range . "@, comment: @" .  $comment . "@");
  
  if ($intra) {
    $file_discourse_intra_count++;
  }
  else {
    $file_discourse_inter_count++;
  }

} # create_discourse_link



sub finite_verb { # vrati 1, pokud mezi vsemi analytickymi protejsky najde finitni sloveso (neurcitek, prechodnik a pricesti trpne tu za finitni nepocitame); jinak vrati 0
  my ($node) = @_;
  # print "finite_verb: node " . $node->attr('id') . " (" . $node->attr('t_lemma') . ")\n";
  my @anals = $node->get_anodes();
  foreach my $a_node (@anals) {
    # my $lemma = $a_node->attr('m/lemma');
    my $tag = $a_node->tag;
    # print "  testing node $a_node_id with lemma $lemma and tag $tag ...";
    if ($tag and $tag =~ /^V[Bipqt]/) {
      # print "hit!\n";
      return 1;
    }
    # print "no.\n";
  }
  # print "...nothing at the node.\n";
  return 0;
}


sub PRED_not_finite_verb { # vrati 1, pokud jde o PRED a mezi vsemi analytickymi protejsky najde nefinitni sloveso (neurcitek, prechodnik a pricesti trpne tu za finitni nepocitame); jinak vrati 0
  my ($node) = @_;
  # print "finite_verb: node " . $node->attr('id') . " (" . $node->attr('t_lemma') . ")\n";
  my $functor = $node->functor;
  if ($functor ne 'PRED') {
    return 0;
  }
  my @anals = $node->get_anodes();
  foreach my $a_node (@anals) {
    # my $lemma = $a_node->attr('m/lemma');
    my $tag = $a_node->tag;
    # print "  testing node $a_node_id with lemma $lemma and tag $tag ...";
    if ($tag and $tag =~ /^V[Bipqt]/) {
      # print "hit!\n";
      return 0;
    }
    # print "no.\n";
  }
  # print "...nothing at the node.\n";
  return 1;
}



=item

sub get_sentence {
  my ($t_node) = @_;
  my $sentence = PML_T::GetSentenceString($t_node->root);
  return $sentence;
}

=cut

sub switch_nodes {
  my ($ref_node_1, $ref_node_2) = @_;
  my $temp = $$ref_node_1;
  $$ref_node_1 = $$ref_node_2;
  $$ref_node_2 = $temp;
}


sub lift_echild {  # if $node is is_member of a coap node, recursively climb up
  my ($node, $target_node) = @_;
  my $parent = $node->get_parent();
  my $lifted_of = 0;
  while ($node->get_attr('is_member') and $node->get_attr('is_member') eq 1 and $parent and $parent->get_attr('nodetype') eq 'coap' and $parent ne $target_node) {
    $node = $parent;
    $parent = $node->get_parent();
    $lifted_of++;
  }
  # print STDERR "lift_echild (lifted of $lifted_of): " . $node->attr('id') . " (" . $node->attr('t_lemma') . ") -> " . $parent->attr('id') . " (" . $parent->attr('t_lemma') . ")\n";
  return $node;
}


sub lift_eparent { # if $eparent is not a predecessor of $node and is is_member, recursively climp up through coap nodes
  my ($eparent, $node) = @_;
  my $parent = $eparent->get_parent();
  my $lifted_of = 0;
  while ($eparent->get_attr('is_member') and $eparent->get_attr('is_member') eq 1 and $parent and $parent->get_attr('nodetype') eq 'coap' and !is_predecessor($eparent, $node)) {
    $eparent = $parent;
    $parent = $parent->get_parent();
    $lifted_of++;
  }
  # print STDERR "lift_eparent (lifted of $lifted_of): " . $eparent->attr('id') . " (" . $eparent->attr('t_lemma') . ") -> " . $parent->attr('id') . " (" . ($parent eq $parent->root ? 'root' : $parent->attr('t_lemma')) . ")\n";
  return $eparent;
}


sub is_predecessor {
  my ($pred, $succ) = @_;
  if ($succ eq $pred) {
    return 1;
  }
  while ($succ = $succ->get_parent()) {
    if ($succ eq $pred) {
      return 1;
    }
  }
  return 0;
}  


sub finite_verb_is_member_recursive {  # returns 1 if the given node is a finite verb or recursively over is_member nodes has in its subtree a finite verb
  my ($node) = @_;
  if (finite_verb($node)) {
    return 1;
  }
  my @is_member_children = grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq 1} $node->get_children();
  foreach my $is_member_child (@is_member_children) {
    if (finite_verb_is_member_recursive($is_member_child)) {
      return 1;
    }
  }
  return 0;
}


sub PRED_not_finite_verb_is_member_recursive {  # returns 1 if the given node is a PRED but non-finite verb or recursively over is_member nodes has in its subtree such a verb
  my ($node) = @_;
  if (PRED_not_finite_verb($node)) {
    return 1;
  }
  my @is_member_children = grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq 1} $node->get_children();
  foreach my $is_member_child (@is_member_children) {
    if (PRED_not_finite_verb_is_member_recursive($is_member_child)) {
      return 1;
    }
  }
  return 0;
}


sub has_selected_prep { # returns a node from the referred a-layer nodes that is a preposition that forms together with 'ten' a secondary connective
  my ($node) = @_;
  my @anals = $node->get_anodes();
  foreach my $a_node (@anals) {
    # log_info("has_selected_prep: checking '" . $a_node->form . "'\n");
    if ($a_node->form and $secondary_intersent_prep_ten_2_discourse_type{lc($a_node->form)}) {
      return $a_node;
    }
  }
  return undef;
}


sub without_ze { # returns 1 if at this t-node there is no reference to an a-layer node with lemma 'že'; otherwise returns 0
  my ($node) = @_;
  my @anals = $node->get_anodes();
  foreach my $a_node (@anals) {
    if ($a_node->form and lc($a_node->form) eq 'že') {
      return 0;
    }
  }
  return 1;
}


sub manual_link_exists { # returns 1 if there is a manually created link to the given target id
  my ($start_node, $target_id) = @_;
  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  foreach my $link (@discourse_arrows) {
    my $source = $link->{'src'};
    my $t_id = $link->{'target_node.rf'};
    if ((!$source or $source !~ /._._[AM]$/) and $t_id and $target_id eq $t_id) {
      return 1;
    }
  }
  return 0;
}

sub automatic_link_exists { # returns 1 if there is an automatically created link to the given target id
  my ($start_node, $target_id) = @_;
  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  foreach my $link (@discourse_arrows) {
    my $source = $link->{'src'};
    my $t_id = $link->{'target_node.rf'};
    if ($source and $source =~ /._._A$/ and $t_id and $target_id eq $t_id) {
      return 1;
    }
  }
  return 0;
}

sub semi_automatic_link_exists { # returns 1 if there is a semi-automatically created link to the given target id
  my ($start_node, $target_id) = @_;
  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  foreach my $link (@discourse_arrows) {
    my $source = $link->{'src'};
    my $t_id = $link->{'target_node.rf'};
    if ($source and $source =~ /._._M$/ and $t_id and $target_id eq $t_id) {
      return 1;
    }
  }
  return 0;
}



sub get_existing_t_connectors { # returns t-connectors from the (first found) link to the given target id
  my ($doc, $start_node, $target_id) = @_;
  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  my @t_connectors = ();
  foreach my $link (@discourse_arrows) {
    my $t_id = $link->{'target_node.rf'};
    if ($t_id and $target_id eq $t_id) {
      my @connectors_refs = ();
      if($link->{'t-connectors.rf'}) {
        @connectors_refs = @{$link->{'t-connectors.rf'}};
      }
      @t_connectors = map {$doc->get_node_by_id($_)} @connectors_refs;
      return @t_connectors;
    }
  }
  return @t_connectors;
}

sub get_existing_a_connectors { # returns a-connectors from the (first found) link to the given target id
  my ($doc, $start_node, $target_id) = @_;
  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  my @a_connectors = ();
  foreach my $link (@discourse_arrows) {
    my $t_id = $link->{'target_node.rf'};
    if ($t_id and $target_id eq $t_id) {
      my @connectors_refs = ();
      if($link->{'a-connectors.rf'}) {
        @connectors_refs = @{$link->{'a-connectors.rf'}};
      }
      @a_connectors = map {$doc->get_node_by_id($_)} @connectors_refs;
      return @a_connectors;
    }
  }
  return @a_connectors;
}


sub remove_automatic_links { # removes automatic links created from the given node to the given target id
  my ($start_node, $target_id) = @_;

  my $ref_discourse_arrows = $start_node->get_attr('discourse');
  my @discourse_arrows = ();
  if ($ref_discourse_arrows) {
    @discourse_arrows = @{$ref_discourse_arrows};
  }
  my $position = 0;
  foreach my $link (@discourse_arrows) {
    $position++;
    my $source = $link->{'src'};
    my $t_id = $link->{'target_node.rf'};
    if ($source and $source =~ /._._A$/ and $t_id and $target_id eq $t_id) {
      @{$start_node->{discourse}} = map {$start_node->{discourse}->[$_]} grep {$_ ne $position-1} (0..$#{$start_node->{discourse}});
    }
    # print STDERR "Removing a previous automatically created link.\n";
  }
}

=item

  Given two references to arrays of connector ids (t-nodes and a-nodes, respectively), it returns the surface representation
  of the connective

=cut

sub get_surface_connective {
  my ($ref_t_connectors, $ref_a_connectors) = @_;

  my @connectors_t_nodes = @{$ref_t_connectors};
  my @connectors_a_nodes = @{$ref_a_connectors};
  
  if (! (@connectors_t_nodes or @connectors_a_nodes)) {
    return 'no_connective';
  }

  my %h_a_surface_connectors;

  my $add_negation = 0;

  foreach my $t_node (@connectors_t_nodes) {
    my @a_nodes = $t_node->get_anodes();
    if (!@a_nodes) { # no analytical counterparts
      if ($t_node->t_lemma eq '#Neg') {
        $add_negation = 1;
      }
      else {
        # print STDERR "No analytical counterparts of the node " . $t_node->attr('id') . " with t_lemma " . $t_node->attr('t_lemma') . "\n";
        my $t_parent = $t_node->parent;
        if ($t_parent) {
          # print STDERR "It has a parent.\n";
          @a_nodes = $t_parent->get_anodes();
        } # if no parent - give up
      }
    }
    if (@a_nodes) {
      push(@connectors_a_nodes, @a_nodes);
    }
  }

  foreach my $a_node (grep {defined and length} @connectors_a_nodes) {
    my $ord = $a_node->ord;
    # my ($file_name, $tree_number, $deepfirst_order) = LocateNode($a_node); # NEFUNGUJE, protože aktuálně nahraný je t-soubor a tohle je a-node a já neumím LocateNode dát správný odkaz na soubor
    # print "LocateNode: $file_name $tree_number $deepfirst_order\n";
    my $root_id = $a_node->root->id;
    my $tree_fake_number = 0;
    if ($root_id =~ /-p(\d+)s(\d+)([A-Z]?)/) {
      $tree_fake_number = $1 * 1000000 + $2 * 1000;
      if ($3) {
        $tree_fake_number += ord($3);
      }
    }
    my $pa_a_surface_connector = $h_a_surface_connectors{"$tree_fake_number"};
    if (!defined($pa_a_surface_connector)) {
      $h_a_surface_connectors{"$tree_fake_number"} = [];
      $pa_a_surface_connector = $h_a_surface_connectors{"$tree_fake_number"};
    }
    if (defined($$pa_a_surface_connector[$ord])) {
      $$pa_a_surface_connector[$ord] = $$pa_a_surface_connector[$ord] . ' ' . $a_node->form;
    }
    else {
      $$pa_a_surface_connector[$ord] = $a_node->form;
    }
  }

  my $surface_connector = "";
  foreach my $tree_fake_number (sort keys %h_a_surface_connectors) { # for each tree containing a part of the connective
    #print "Fake tree number: $tree_fake_number\n";
    my $pa_a_surface_connector = $h_a_surface_connectors{"$tree_fake_number"};
    foreach my $form (@$pa_a_surface_connector) {
      if (defined($form)) {
        if (length($surface_connector)) {
          $surface_connector .= ' ';
        }
        $surface_connector .= $form;
        # print "The connector so far: $surface_connector\n";
      }
    }
  }
  
  if ($add_negation) {
    $surface_connector = '#Neg ' . $surface_connector;
  }
  return $surface_connector;
} # get_surface_connective


# $node is a coap node #Separ or #Comma; the function checks if there is a grammatical coreference from a son of a is_member son of the node to another is_member son of the node;
# If yes, it returns the son's son (it is the connective)
sub coz_case {
  my ($node) = @_;
  # print STDERR "Checking coz_case...\n";
  my @member_sons = grep {$_->get_attr('is_member') and $_->get_attr('is_member') eq 1} $node->get_children();
  foreach my $member_son (@member_sons) {
    my @sons_sons = $member_son->get_children();
    if (@sons_sons) {
      foreach my $sons_son (@sons_sons) {
        if ($sons_son->t_lemma eq 'co') {
          # print STDERR "Found t_lemma='co'\n";
          my @gram_rfs = ();
          my $gram_rf = $sons_son->get_attr('coref_gram.rf');
          if ($gram_rf) {
            @gram_rfs = @{$gram_rf};
          }
          foreach my $gram_rf (@gram_rfs) {
            if (defined($gram_rf)) {
              if (scalar(grep {$_->id eq $gram_rf} @member_sons)) {
                return $sons_son;
              }
            }
          }
        }
      }
    }
  }
  return undef;
}


# returns 1 if there is one of the predefined lemmas among the given a-nodes
# the lemmas are predefined in the hash %ha_tak_pak; also, presence of "i když" is tested
sub tak_pak {
  my (@connectors) = @_;
  my $is_i = 0;
  my $is_kdyz = 0;
  foreach my $connector (@connectors) {
    my $lemma = $connector->lemma;
    if (defined($ha_tak_pak{$lemma})) {
      # print STDERR "tak_pak: found '$lemma'\n";
      return 1;
    }
    if ($lemma eq 'i') {
      $is_i = 1;
    }
    if ($lemma eq 'když') {
      $is_kdyz = 1;
    }
  }
  if ($is_i and $is_kdyz) {
    # print STDERR "tak_pak: found 'i když'\n";
    return 1;
  }
  return 0;
}



sub is_member {
  my ($m, @ar) = @_;
  foreach my $a (@ar) {
    if ($m eq $a) {
      return 1;
    }
  }
  return 0;
}

1;

__END__

=encoding utf-8


=head1 NAME

Treex::Block::Discourse::CS::MarkDiscourse

=head1 DESCRIPTION

The block annotates intra-sentential and inter-sentential discourse relations
in the Czech t-layer data.

=head1 AUTHOR

Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
