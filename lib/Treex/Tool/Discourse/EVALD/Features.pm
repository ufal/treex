package Treex::Tool::Discourse::EVALD::Features;
use Moose;
use Treex::Core::Common;
use POSIX;
use Treex::Tool::Lexicon::CS;
use Data::Printer;

has 'target' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'target classification set, two possible values: L1 for native speakers, L2 for second language learners',
);
has 'language' => ( is => 'ro', isa => 'Str', required => 1 );
has 'selector' => ( is => 'ro', isa => 'Str', default => '' );
has 'all_classes' => ( is => 'ro', isa => 'ArrayRef[Str]', builder => 'build_all_classes', lazy => 1 );
has 'weka_featlist' => ( is => 'ro', isa => 'ArrayRef[ArrayRef[Str]]', builder => 'build_weka_featlist' );

sub build_all_classes {
    my ($self) = @_;
    if ($self->target eq 'L1') {
      return ['1', '2', '3', '4', '5'];
    }
    else {
      return ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    }  
}

sub build_weka_featlist {
    my ($self) = @_;
    my $weka_feats_types = [
      ["avg_words_per_sent",                          "NUMERIC"],

    # ["different_t_lemmas",                          "NUMERIC"],
      ["t_lemmas_per_100t_lemmas",                    "NUMERIC"],
      ["simpson_index",                               "NUMERIC"],
      ["yule_index",                                  "NUMERIC"],
      ["avg_PREDless_per_100sent",                    "NUMERIC"],

      ["avg_connective_words_coord_per_100sent",      "NUMERIC"],
      ["avg_connective_words_subord_per_100sent",     "NUMERIC"],
      ["avg_connective_words_per_100sent",            "NUMERIC"],

      ["avg_discourse_intra_per_100sent",             "NUMERIC"],
      ["avg_discourse_inter_per_100sent",             "NUMERIC"],
      ["avg_discourse_per_100sent",                   "NUMERIC"],
      ["different_connectives",                       "NUMERIC"],

      ["perc_a",                                      "NUMERIC"],
      ["perc_ale",                                    "NUMERIC"],
      ["perc_protoze",                                "NUMERIC"],
      ["perc_take",                                   "NUMERIC"],
      ["perc_potom",                                  "NUMERIC"],
      ["perc_kdyz",                                   "NUMERIC"],
      ["perc_nebo",                                   "NUMERIC"],
      ["perc_proto",                                  "NUMERIC"],
      ["perc_tak",                                    "NUMERIC"],
      ["perc_aby",                                    "NUMERIC"],
      ["perc_totiz",                                  "NUMERIC"],

      ["perc_first_connective",                       "NUMERIC"],
      ["perc_first_and_second_connectives",           "NUMERIC"],
      
      ["perc_temporal",                               "NUMERIC"],
      ["perc_contingency",                            "NUMERIC"],
      ["perc_contrast",                               "NUMERIC"],
      ["perc_expansion",                              "NUMERIC"],
    ];
    return $weka_feats_types;
}

############################################ MAIN FEATURE EXTRACTING METHODS ############################################

sub extract_features {
    my ($self, $doc, $params) = @_;

    # Ranking style is set as default
    $params = {} if (!defined $params);
    $params->{as_ranking} = 1 if (!defined $params->{as_ranking});

    if ($params->{as_ranking}) {
        return $self->extract_features_as_ranking($doc);
    }
    else {
        log_fatal "Extracting EVALD features in non-ranking style is not supported, yet!";
    }
}

sub extract_features_as_ranking {
    my ($self, $doc) = @_;

    $self->collect_info($doc);
    my $feat_hash = $self->create_feat_hash($doc);

    # create the "shared" part of the instance represenatiotn
    # distribute them by the specified namespace ("ns^" prefix)
    my %ns_feats = ();
    foreach my $key (sort keys %$feat_hash) {
        my ($ns, $feat) = split /\^/, $key, 2;
        my $feat_list = $ns_feats{$ns};
        if (!defined $feat_list) {
            $feat_list = [[ "|$ns", undef ]];
            $ns_feats{$ns} = $feat_list;
        }
        #my @feat_array = map {my $key = $_->[0]; [ $key, $feat_hash->{$key} ]} @{$self->weka_featlist};
        # TODO: so far, all features are considered numeric - as weights   
        push @$feat_list, [ $feat, undef, $feat_hash->{$key} ];
    }
    my @feat_array = map {@{$ns_feats{$_}}} sort keys %ns_feats;

    # create the "cands" part of the instance representation
    # in this case, every candidate correpsonds to a possible class => only a single feature "class" is specified
    # the class feature should belong to a "class" namespace
    my @class_arrays = map { [['|class', undef], ['class', $_ ]] } @{$self->all_classes};
    return [ \@class_arrays, \@feat_array ];
}

sub create_feat_hash {
    my ($self, $doc) = @_;

    my $discourse_feats = $self->discourse_features($doc);
    my $coreference_feats = $self->coreference_features($doc);

    my %all_feats_hash = ( %$discourse_feats, %$coreference_feats );
    return \%all_feats_hash;
}



############################################ COLLECTING INFORMATION AND COUNTS ############################################

my $number_of_sentences;
my $number_of_words;

# baseline features:
my $count_connective_words_subord;
my $count_connective_words_coord;

# surface features:
my %lemmas_counts;

# t-layer features
my %t_lemmas_counts;

my %t_lemmas_counts_corrected;
my $t_lemmas_per_100_t_lemmas;
my $t_lemmas_per_100_t_lemmas_sum;
my $number_of_t_lemmas;

my $count_PREDless_sentences;

# discourse-parsing features
my $number_of_discourse_relations_intra;
my $number_of_discourse_relations_inter;
my %connectives;

my $count_contingency;
my $count_temporal;
my $count_contrast;
my $count_expansion;

sub collect_info {
    my ($self, $doc) = @_;
    $self->collect_info_discourse($doc);
    $self->collect_info_coreference($doc);
}

my %ha_discourse_type_2_class = ('synchr' => 'TEMPORAL',
                                 'preced' => 'TEMPORAL',
                                 'reason' => 'CONTINGENCY',
                               'f_reason' => 'CONTINGENCY',
                               'explicat' => 'CONTINGENCY',
                                   'cond' => 'CONTINGENCY',
                                 'f_cond' => 'CONTINGENCY',
                                   'purp' => 'CONTINGENCY',
                                  'confr' => 'CONTRAST',
                                    'opp' => 'CONTRAST',
                                  'restr' => 'CONTRAST',
                                  'f_opp' => 'CONTRAST',
                                   'conc' => 'CONTRAST',
                                   'corr' => 'CONTRAST',
                                   'grad' => 'CONTRAST',
                                   'conj' => 'EXPANSION',
                                'conjalt' => 'EXPANSION',
                                'disjalt' => 'EXPANSION',
                                 'exempl' => 'EXPANSION',
                                   'spec' => 'EXPANSION',
                                  'equiv' => 'EXPANSION',
                                  'gener' => 'EXPANSION');

my %ha_connectors_coord = ('a' => '1',
                            'ale' => '1',
                            'ani' => '1',
                            'avšak' => '1',
                            'dále' => '1',
                            'dokonce' => '1',
                            'i' => '1',
                            'jen' => '1',
                            'jenže' => '1',
                            'nakonec' => '1',
                            'naopak' => '1',
                            'například' => '1',
                            'navíc' => '1',
                            'nebo' => '1',
                            'nicméně' => '1',
                            'ovšem' => '1',
                            'pak' => '1',
                            'potom' => '1',
                            'pouze' => '1',
                            'přesto' => '1',
                            'přitom' => '1',
                            'proto' => '1',
                            'rovněž' => '1',
                            'spíše' => '1',
                            'stejně' => '1',
                            'tak' => '1',
                            'také' => '1',
                            'taky' => '1',
                            'takže' => '1',
                            'tedy' => '1',
                            'ten' => '1',
                            'totiž' => '1',
                            'však' => '1',
                            'vždyť' => '1',
                            'zároveň' => '1',
                            'zase' => '1',
                            'zato' => '1');

my %ha_connectors_subord = ('protože' => '1',
                            'pokud' => '1',
                            'aby' => '1',
                            'zatímco' => '1',
                            'i když' => '1', # nepoužije se (víc slov)
                            'takže' => '1',
                            'kdyby' => '1',
                            'přestože' => '1',
                            'jestli' => '1');

# collects discourse-related information and counts from the document
sub collect_info_discourse {
    my ($self, $doc) = @_;
    
    $number_of_words = 0;
    $number_of_discourse_relations_intra = 0;
    $number_of_discourse_relations_inter = 0;
    %connectives = ();
    %t_lemmas_counts = ();
  
    %t_lemmas_counts_corrected = ();
    $t_lemmas_per_100_t_lemmas = 0;
    $t_lemmas_per_100_t_lemmas_sum = 0;
    $number_of_t_lemmas = 0;
  
    %lemmas_counts = ();
    $count_contingency = 0;
    $count_temporal = 0;
    $count_contrast = 0;
    $count_expansion = 0;
    $count_connective_words_subord = 0;
    $count_connective_words_coord = 0;
    $count_PREDless_sentences = 0;
  
    my $prev_root;
  
    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
  
    $number_of_sentences = scalar(@ttrees);
    
    foreach my $t_root (@ttrees) {
  
  #    foreach my $t_node ($t_root->get_descendants({ordered=>1, add_self=>0})) {
  
      # first surface features - numbers of coordinating and subordinating connective words taken from the a/m-layers
      my $a_root = get_aroot($doc, $t_root);
      my @anodes = grep {$_ ne $a_root} $a_root->get_descendants({ordered=>1, add_self=>0});
      $number_of_words += scalar(@anodes);
      foreach my $anode (@anodes) {
        my $lemma = $anode->lemma;
        if ($lemma) {
          $lemma =~ s/^(.[^-_^~]*)[-_^~].+$/$1/;
          # print STDERR "lemma = $lemma\n";
          $lemmas_counts{$lemma}++;
          if ($ha_connectors_coord{$lemma}) {
            $count_connective_words_coord++;
          }
          elsif ($ha_connectors_subord{$lemma}) {
            $count_connective_words_subord++;
          }
        }
      }
      
      # then t-layer and discourse features
      my @nodes = $t_root->get_descendants({ordered=>1, add_self=>0});
  
      my $has_PRED = 0;
      foreach my $node (@nodes) {
      
        my $t_lemma = $node->t_lemma;
        if ($t_lemma) {
          $t_lemmas_counts{$t_lemma}++;
          
          $number_of_t_lemmas++;
          $t_lemmas_counts_corrected{$t_lemma}++;
          if ($number_of_t_lemmas/100 == ceil($number_of_t_lemmas/100)) { # divisible by 100
            my $different_new_t_lemmas = scalar (keys (%t_lemmas_counts_corrected));
            # print STDERR "Incorporating number of new different t_lemmas ($different_new_t_lemmas) to the running value ($t_lemmas_per_100_t_lemmas).\n";
            $t_lemmas_per_100_t_lemmas = ($t_lemmas_per_100_t_lemmas * $t_lemmas_per_100_t_lemmas_sum + $different_new_t_lemmas * 100) / $number_of_t_lemmas;
            # print STDERR "New avarage number of different t_lemmas per 100 t_lemmas: $t_lemmas_per_100_t_lemmas.\n";
            $t_lemmas_per_100_t_lemmas_sum += 100;
            %t_lemmas_counts_corrected = ();
          }
        }
        
        my $functor = $node->functor;
        if ($functor and $functor eq 'PRED') {
          $has_PRED = 1;
        }
  
        my $ref_discourse_arrows = $node->get_attr('discourse');
        my @discourse_arrows = ();
        if ($ref_discourse_arrows) {
          @discourse_arrows = @{$ref_discourse_arrows};
        }
  
        foreach my $arrow (@discourse_arrows) { # take all discourse arrows starting at the given node
          #my $connective = get_surface_connector($arrow);
          #if (!defined($connective) or !length($connective)) {
          #  $connective = "no_connective";
          #}
          #my $connective_lc = lc($connective);
          #$connective_lc =~ s/ /_/g;
          # print STDERR "\nA connective found: $connective_lc";
          #my $discourse_type = $arrow->{'discourse_type'};
          #if (!defined($discourse_type) or !length($discourse_type)) {
          #  $discourse_type = "no_discourse_type";
          #}
          my $target_node = $doc->get_node_by_id($arrow->{'target_node.rf'});
          if ($target_node) {
            if ($node->root eq $target_node->root) {
              $number_of_discourse_relations_intra++;
              # print "$number_of_discourse_relations_intra\n";
            }
            else {
              $number_of_discourse_relations_inter++;
            }
          }
          else {
            log_warn("Warning - no target node!\n");
          }
  
          my $connective = lc(get_surface_connective($doc, $arrow));
          $connectives{$connective}++;
  
          my $discourse_type = $arrow->{'discourse_type'};
          my $class = $ha_discourse_type_2_class{$discourse_type};
          if ($class) {
            if ($class eq 'TEMPORAL') {
              $count_temporal++;
            }
            elsif ($class eq 'CONTINGENCY') {
              $count_contingency++;
            }
            elsif ($class eq 'CONTRAST') {
              $count_contrast++;
            }
            elsif ($class eq 'EXPANSION') {
              $count_expansion++;
            }
          }
        }
        if (!$has_PRED) {
          $count_PREDless_sentences++;
        }
      }
    }
}

my $pron_a_count = 0;
my $noun_a_count = 0;
my %pron_a_subpos_counts = ();
my %pron_a_lemmas = ();
my $to_a_count = 0;

my $pron_t_count = 0;
my %pron_t_sempos_counts = ();
my $perspron_act_t_count = 0;
my %perspron_act_t_lemmas = ();

# collects coreference-related information and counts from the document
sub collect_info_coreference {
    my ($self, $doc) = @_;

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} $doc->get_bundles;
    foreach my $atree (@atrees) {
        foreach my $anode ($atree->get_descendants({ordered => 1})) {
            if ($anode->tag =~ /^P/) {
                $pron_a_count++;
                my $subpos = substr($anode->tag, 1, 1);
                $pron_a_subpos_counts{$subpos}++;
                my $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, 1);
                $pron_a_lemmas{$lemma}++;
                $to_a_count++ if ($anode->form eq "to");
            }
            $noun_a_count++ if ($anode->tag =~ /^N/);
        }
    }
    
    my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    foreach my $ttree (@ttrees) {
        foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
            my $sempos = $tnode->gram_sempos // "";
            if ($sempos =~ /pron/) {
                $pron_t_count++;
                $pron_t_sempos_counts{$sempos}++;
                if ($sempos eq "n.pron.def.pers" && $tnode->functor eq "ACT") {
                    $perspron_act_t_count++;
                    my $anode = $tnode->get_lex_anode;
                    $perspron_act_t_lemmas{defined $anode ? Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, 1) : "undef"}++;
                }
            }
        }
    }
}

sub get_surface_connective {
  my ($doc, $arrow) = @_;
  my $ref_t_connectors = $arrow->{'t-connectors.rf'};
  my $ref_a_connectors = $arrow->{'a-connectors.rf'};

  my @connectors_t_nodes = map {$doc->get_node_by_id($_)} @{$ref_t_connectors};
  my @connectors_a_nodes = map {$doc->get_node_by_id($_)} @{$ref_a_connectors};
  
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


sub get_aroot {
    my ($doc, $t_node) = @_;
    my $aroot_rf = $t_node->get_attr('atree.rf');
    return $doc->get_node_by_id($aroot_rf) if $aroot_rf;
    return;
}

sub get_sentence_t {
  my ($doc, $t_node) = @_;
  my $a_root = get_aroot($doc, $t_node->root);
  my @a_nodes = $a_root->get_descendants({ordered => 1, add_self=>0});
  my $sentence = join '', map { defined( $_->form ) ? ( $_->form . ( $_->no_space_after ? '' : ' ' ) ) : '' } @a_nodes;
  return $sentence;
} # get_sentence_t


############################################ USING COLLECTED INFORMATION TO EXTRACT FEATURES ############################################

#-------------------------------  discourse-related features implemented in the 1st year of the project by Jirka ------------------------
sub discourse_features {
    my ($self, $doc) = @_;

    #my $file_name = FileName();
    #$file_name =~ s/^.+\/([^\/]+)$/$1/;
    #print "$file_name";
    #print ", ";

    my %feats = ();
  
    $feats{'disc^avg_words_per_sent'} = ceil($number_of_words/$number_of_sentences);
  
    #my $different_t_lemmas = scalar(keys(%t_lemmas_counts));
    #print "$different_t_lemmas";
    #print ", ";
  
    #my $new_number_of_t_lemmas = $number_of_t_lemmas - $t_lemmas_per_100_t_lemmas_sum;
    #my $different_new_t_lemmas = scalar (keys (%t_lemmas_counts_corrected));
    #print STDERR "Last addition - incorporating number of new different t_lemmas ($different_new_t_lemmas) among $new_number_of_t_lemmas t_lemmas to the running value ($t_lemmas_per_100_t_lemmas).\n";
    #$t_lemmas_per_100_t_lemmas = ceil(($t_lemmas_per_100_t_lemmas * $t_lemmas_per_100_t_lemmas_sum + $different_new_t_lemmas * 100) / $number_of_t_lemmas);
    #print STDERR "Final avarage number of different t_lemmas per 100 t_lemmas: $t_lemmas_per_100_t_lemmas.\n";
    if (!$t_lemmas_per_100_t_lemmas) { # not set yet, i.e. there have been only less than 100 t_lemmas in total  
      $t_lemmas_per_100_t_lemmas = scalar (keys (%t_lemmas_counts_corrected)); # take only the number of so far observed different t_lemmas (do not normalize to 100 observed t_lemmas)
      # print STDERR "There have not been 100 t_lemmas in the text - counting only so far observed different t_lemmas (in $number_of_t_lemmas): $t_lemmas_per_100_t_lemmas.\n";
    }
    
    $feats{'disc^t_lemmas_per_100t_lemmas'} = ceil($t_lemmas_per_100_t_lemmas);
    $feats{'disc^simpson_index'} = get_simpson_index();
    $feats{'disc^yule_index'} = get_george_udny_yule_index();
    $feats{'disc^avg_PREDless_per_100sent'} = ceil(100*$count_PREDless_sentences/$number_of_sentences);
    $feats{'disc^avg_connective_words_coord_per_100sent'} = ceil(100*$count_connective_words_coord/$number_of_sentences);
    $feats{'disc^avg_connective_words_subord_per_100sent'} = ceil(100*$count_connective_words_subord/$number_of_sentences);
    $feats{'disc^avg_connective_words_per_100sent'} = ceil(100*($count_connective_words_coord+$count_connective_words_subord)/$number_of_sentences);
    $feats{'disc^avg_discourse_intra_per_100sent'} = ceil(100*$number_of_discourse_relations_intra/$number_of_sentences);
    $feats{'disc^avg_discourse_inter_per_100sent'} = ceil(100*$number_of_discourse_relations_inter/$number_of_sentences);
    $feats{'disc^avg_discourse_per_100sent'} = ceil(100*($number_of_discourse_relations_inter + $number_of_discourse_relations_intra)/$number_of_sentences);
    $feats{'disc^different_connectives'} = scalar(keys(%connectives));

    $feats{'disc^perc_a'} = ceil(100*(scalar($connectives{'a'}) ? scalar($connectives{'a'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_ale'} = ceil(100*(scalar($connectives{'ale'}) ? scalar($connectives{'ale'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_protoze'} = ceil(100*(scalar($connectives{'protože'}) ? scalar($connectives{'protože'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_take'} = ceil(100*((scalar($connectives{'také'}) or scalar($connectives{'taky'})) ? scalar($connectives{'také'}//0 + $connectives{'taky'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_potom'} = ceil(100*((scalar($connectives{'potom'}) or scalar($connectives{'pak'})) ? scalar($connectives{'potom'}//0 + $connectives{'pak'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_kdyz'} = ceil(100*(scalar($connectives{'když'}) ? scalar($connectives{'když'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_nebo'} = ceil(100*(scalar($connectives{'nebo'}) ? scalar($connectives{'nebo'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_proto'} = ceil(100*(scalar($connectives{'proto'}) ? scalar($connectives{'proto'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_tak'} = ceil(100*(scalar($connectives{'tak'}) ? scalar($connectives{'tak'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_aby'} = ceil(100*(scalar($connectives{'aby'}) ? scalar($connectives{'aby'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    $feats{'disc^perc_totiz'} = ceil(100*(scalar($connectives{'totiž'}) ? scalar($connectives{'totiž'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  
  
    my @connective_usages_sorted = sort {$b <=> $a} map {$connectives{$_}} keys (%connectives); # sort numbers of usages of the connectives in the decreasing order (disregard the connectives themselves)
    my $percent_most_frequent_connectives_first = 0;
    if (scalar(@connective_usages_sorted) >= 1) {
      my $most_frequent_connectives_first = $connective_usages_sorted[0];
      $percent_most_frequent_connectives_first = ceil(100*$most_frequent_connectives_first/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    }
    $feats{'disc^perc_first_connective'} = $percent_most_frequent_connectives_first;
  
    my $percent_most_frequent_connectives_first_and_second = 0;
    if (scalar(@connective_usages_sorted) >= 2) {
      my $most_frequent_connectives_first_and_second = $connective_usages_sorted[0] + $connective_usages_sorted[1];
      $percent_most_frequent_connectives_first_and_second = ceil(100*$most_frequent_connectives_first_and_second/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
    }
    else {
      $percent_most_frequent_connectives_first_and_second = $percent_most_frequent_connectives_first;
    }
    $feats{'disc^perc_first_and_second_connectives'} = $percent_most_frequent_connectives_first_and_second;
    
    $feats{'disc^perc_temporal'} = ceil(100*$count_temporal/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
    $feats{'disc^perc_contingency'} = ceil(100*$count_contingency/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
    $feats{'disc^perc_contrast'} = ceil(100*$count_contrast/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
    $feats{'disc^perc_expansion'} = ceil(100*$count_expansion/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  
    return \%feats;
}

sub get_simpson_index {
  return 0 if ($number_of_words < 2);
  my %frequencies_counts;
  # count how many times various frequencies of lemmas occurred
  foreach my $key (keys (%lemmas_counts)) {
    $frequencies_counts{$lemmas_counts{$key}}++;
  }
  # count the simpson index
  my $simpson = 0;
  foreach my $frequency (keys (%frequencies_counts)) {
    my $count = $frequencies_counts{$frequency};
    $simpson += $count * $frequency/$number_of_words * ($frequency-1)/($number_of_words-1);
    # print STDERR "Simpson so far: $simpson\n";
  }
  return ceil(10000*$simpson);
}

sub get_george_udny_yule_index {
  my %frequencies_counts;
  # count how many times various frequencies of lemmas occurred
  foreach my $key (keys (%lemmas_counts)) {
    $frequencies_counts{$lemmas_counts{$key}}++;
  }
  # count the George Udny Yule's index
  my $inner = 0;
  foreach my $frequency (keys (%frequencies_counts)) {
    my $count = $frequencies_counts{$frequency};
    $inner += $frequency * $frequency * $count;
    # print STDERR "Yule inner sum so far: $inner\n";
  }
  my $yule = 10000 * ($inner - $number_of_words) / ($number_of_words * $number_of_words);
  return ceil($yule);
}

my @ALL_PRON_SUBPOS = qw/0 1 4 5 6 7 8 9 D E H J K L O P Q S W Y Z/;
my @ALL_PRON_SEMPOS = qw/n.pron.def.pers n.pron.indef adj.pron.indef n.pron.def.demon adj.pron.def.demon adv.pron.def adv.pron.indef/;

#------------------------------------ coreference-related features implemented in the 2nd year of the project by Michal ---------------------------
sub coreference_features { 
    my ($self, $doc) = @_;

    my $feats = {};
    $feats->{'pron^prons_a_perc_words'} = ceil($number_of_words ? 100*$pron_a_count/$number_of_words : 0);
    $feats->{'pron^prons_a_perc_nps'} = ceil(($pron_a_count+$noun_a_count) ? 100*$pron_a_count/($pron_a_count+$noun_a_count) : 0);
    foreach my $subpos (@ALL_PRON_SUBPOS) {
        my $subpos_count = $pron_a_subpos_counts{$subpos} // 0;
        $feats->{"pron^prons_a_".$subpos."_perc_words"} = ceil($number_of_words ? 100*$subpos_count/$number_of_words : 0);
        $feats->{"pron^prons_a_".$subpos."_perc_prons"} = ceil($pron_a_count ? 100*$subpos_count/$pron_a_count : 0);
        $feats->{"pron^prons_a_".$subpos."_perc_nps"}   = ceil(($pron_a_count+$noun_a_count) ? 100*$subpos_count/($pron_a_count+$noun_a_count) : 0);
    }
    $feats->{'pron^prons_a_lemmas_perc_words'} = ceil($number_of_words ? 100*scalar(keys %pron_a_lemmas)/$number_of_words : 0);
    $feats->{'pron^prons_a_lemmas_perc_prons'} = ceil($pron_a_count ? 100*scalar(keys %pron_a_lemmas)/$pron_a_count : 0);
    $feats->{'pron^to_a_perc_prons'} = ceil($pron_a_count ? 100*$to_a_count/$pron_a_count : 0);

    $feats->{'pron^prons_t_perc_tnodes'} = ceil($number_of_t_lemmas ? 100*$pron_t_count/$number_of_t_lemmas : 0);
    foreach my $sempos (@ALL_PRON_SUBPOS) {
        my $sempos_count = $pron_t_sempos_counts{$sempos} // 0;
        $feats->{"pron^prons_t_".$sempos."_perc_prons"} = ceil($pron_t_count ? 100*$sempos_count/$pron_t_count : 0);
    }
    foreach my $lemma (keys %perspron_act_t_lemmas) {
        my $lemma_count = $perspron_act_t_lemmas{$lemma} // 0;
        $feats->{"pron^perspron_t_".$lemma."_perc_persprons"} = ceil($perspron_act_t_count ? 100*$lemma_count/$perspron_act_t_count : 0);
    }
    return $feats;
}



1;
__END__

=encoding utf-8


=head1 NAME

Treex::Block::Discourse::CS::EvaldExtractFeaturesWeka

=head1 DESCRIPTION

Extracts features from the data for evaluation of text coherence using the WEKA toolkit

=head1 AUTHOR

Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


