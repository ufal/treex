package Treex::Block::Discourse::CS::EvaldExtractFeaturesWeka;
use Moose;
use Treex::Core::Common;
use Data::Dumper;
use POSIX;

extends 'Treex::Core::Block';

has target => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'target classification set, two possible values: L1 for native speakers, L2 for second language learners',
);

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

my $target;

sub process_document {
  my ($self, $doc) = @_;

  $target = $self->target;

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

  my $features = '';
  #my $file_name = FileName();
  #$file_name =~ s/^.+\/([^\/]+)$/$1/;
  #print "$file_name";
  #print ", ";

  my $avg_words_per_sentence = ceil($number_of_words/$number_of_sentences);
  $features .= "$avg_words_per_sentence, ";

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
  
  $features .= ceil($t_lemmas_per_100_t_lemmas);
  $features .= ', ';
  
  my $simpson_index = get_simpson_index();
  $features .= "$simpson_index, ";

  my $yule_index = get_george_udny_yule_index();
  $features .= "$yule_index, ";

  my $avg_PREDless_per_100sent = ceil(100*$count_PREDless_sentences/$number_of_sentences);
  $features .= "$avg_PREDless_per_100sent, ";

  my $avg_connective_words_coord_per_100sent = ceil(100*$count_connective_words_coord/$number_of_sentences);
  $features .= "$avg_connective_words_coord_per_100sent, ";

  my $avg_connective_words_subord_per_100sent = ceil(100*$count_connective_words_subord/$number_of_sentences);
  $features .= "$avg_connective_words_subord_per_100sent, ";

  my $avg_connective_words_per_100sent = ceil(100*($count_connective_words_coord+$count_connective_words_subord)/$number_of_sentences);
  $features .= "$avg_connective_words_per_100sent, ";

  my $avg_discourse_intra_per_100sentences = ceil(100*$number_of_discourse_relations_intra/$number_of_sentences);
  $features .= "$avg_discourse_intra_per_100sentences, ";

  my $avg_discourse_inter_per_100sentences = ceil(100*$number_of_discourse_relations_inter/$number_of_sentences);
  $features .= "$avg_discourse_inter_per_100sentences, ";

  my $avg_discourse_per_100sentences = ceil(100*($number_of_discourse_relations_inter + $number_of_discourse_relations_intra)/$number_of_sentences);
  $features .= "$avg_discourse_per_100sentences, ";

  my $number_of_different_connectives = scalar(keys(%connectives));
  $features .= "$number_of_different_connectives, ";


  my $avg_a_per_100connectives = ceil(100*(scalar($connectives{'a'}) ? scalar($connectives{'a'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_a_per_100connectives, ";

  my $avg_ale_per_100connectives = ceil(100*(scalar($connectives{'ale'}) ? scalar($connectives{'ale'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_ale_per_100connectives, ";

  my $avg_protoze_per_100connectives = ceil(100*(scalar($connectives{'protože'}) ? scalar($connectives{'protože'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_protoze_per_100connectives, ";

  my $avg_take_taky_per_100connectives = ceil(100*((scalar($connectives{'také'}) or scalar($connectives{'taky'})) ? scalar($connectives{'také'}//0 + $connectives{'taky'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_take_taky_per_100connectives, ";

  my $avg_potom_pak_per_100connectives = ceil(100*((scalar($connectives{'potom'}) or scalar($connectives{'pak'})) ? scalar($connectives{'potom'}//0 + $connectives{'pak'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_potom_pak_per_100connectives, ";

  my $avg_kdyz_per_100connectives = ceil(100*(scalar($connectives{'když'}) ? scalar($connectives{'když'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_kdyz_per_100connectives, ";

  my $avg_nebo_per_100connectives = ceil(100*(scalar($connectives{'nebo'}) ? scalar($connectives{'nebo'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_nebo_per_100connectives, ";

  my $avg_proto_per_100connectives = ceil(100*(scalar($connectives{'proto'}) ? scalar($connectives{'proto'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_proto_per_100connectives, ";

  my $avg_tak_per_100connectives = ceil(100*(scalar($connectives{'tak'}) ? scalar($connectives{'tak'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_tak_per_100connectives, ";

  my $avg_aby_per_100connectives = ceil(100*(scalar($connectives{'aby'}) ? scalar($connectives{'aby'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_aby_per_100connectives, ";

  my $avg_totiz_per_100connectives = ceil(100*(scalar($connectives{'totiž'}) ? scalar($connectives{'totiž'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features .= "$avg_totiz_per_100connectives, ";


  my @connective_usages_sorted = sort {$b <=> $a} map {$connectives{$_}} keys (%connectives); # sort numbers of usages of the connectives in the decreasing order (disregard the connectives themselves)
  my $percent_most_frequent_connectives_first = 0;
  if (scalar(@connective_usages_sorted) >= 1) {
    my $most_frequent_connectives_first = $connective_usages_sorted[0];
    $percent_most_frequent_connectives_first = ceil(100*$most_frequent_connectives_first/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  }
  $features .= "$percent_most_frequent_connectives_first, ";

  my $percent_most_frequent_connectives_first_and_second = 0;
  if (scalar(@connective_usages_sorted) >= 2) {
    my $most_frequent_connectives_first_and_second = $connective_usages_sorted[0] + $connective_usages_sorted[1];
    $percent_most_frequent_connectives_first_and_second = ceil(100*$most_frequent_connectives_first_and_second/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  }
  else {
    $percent_most_frequent_connectives_first_and_second = $percent_most_frequent_connectives_first;
  }
  $features .= "$percent_most_frequent_connectives_first_and_second, ";

  my $percentage_temporal = ceil(100*$count_temporal/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features .= "$percentage_temporal, ";

  my $percentage_contingency = ceil(100*$count_contingency/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features .= "$percentage_contingency, ";

  my $percentage_contrast = ceil(100*$count_contrast/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features .= "$percentage_contrast, ";

  my $percentage_expansion = ceil(100*$count_expansion/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features .= "$percentage_expansion, ";

  #my $coherence_mark = get_document_attr('CEFR_coherence');
  #if ($coherence_mark) {
  #  $features .= "$coherence_mark";
  #}
  #else {
    $features .= "?";
  #}

  my $arff = get_weka_header(); # the output in the arff format
  $arff .= $features;
  $arff .= "\n";
  
  log_info($arff);
  
  $doc->{'coherence_weka_arff'} = $arff;
  
} # process_document


sub get_weka_header {
  my $header = '@RELATION Evald' . "\n\n";
 
  $header .= '@ATTRIBUTE avg_words_per_sent  NUMERIC' . "\n";

#  $header .= '@ATTRIBUTE different_t_lemmas  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE different_t_lemmas_per_100t_lemmas  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE simpson_index  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE george_udny_yule_index  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE avg_PREDless_per_100sent  NUMERIC' . "\n";

  $header .= '@ATTRIBUTE avg_connective_words_coord_per_100sent  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE avg_connective_words_subord_per_100sent  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE avg_connective_words_per_100sent  NUMERIC' . "\n";
  
  $header .= '@ATTRIBUTE avg_intra_per_100sent   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE avg_inter_per_100sent  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE avg_discourse_per_100sent   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE different_connectives   NUMERIC' . "\n";

  $header .= '@ATTRIBUTE percentage_a   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_ale   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_protoze   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_take_taky   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_potom_pak   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_kdyz   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_nebo   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_proto   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_tak   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_aby   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_totiz   NUMERIC' . "\n";

  $header .= '@ATTRIBUTE percentage_first_connective   NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_first_and_second_connectives   NUMERIC' . "\n";
  
  $header .= '@ATTRIBUTE percentage_temporal  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_contingency  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_contrast  NUMERIC' . "\n";
  $header .= '@ATTRIBUTE percentage_expansion  NUMERIC' . "\n";

  if ($target eq 'L1') {
    $header .= '@ATTRIBUTE mark_coherence  {1, 2, 3, 4, 5}' . "\n";
  }
  else {
    $header .= '@ATTRIBUTE mark_coherence  {A1, A2, B1, B2, C1, C2}' . "\n";
  }  

  $header .= "\n" . '@DATA' . "\n";
  return $header;
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

sub get_sentence_t {
  my ($doc, $t_node) = @_;
  my $a_root = get_aroot($doc, $t_node->root);
  my @a_nodes = $a_root->get_descendants({ordered => 1, add_self=>0});
  my $sentence = join '', map { defined( $_->form ) ? ( $_->form . ( $_->no_space_after ? '' : ' ' ) ) : '' } @a_nodes;
  return $sentence;
} # get_sentence_t



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


