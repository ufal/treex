package Treex::Block::Discourse::CS::EvaldExtractFeaturesWeka;
use Moose;
use Treex::Core::Common;
use Data::Dumper;
use POSIX;
use Treex::Tool::Tagger::MorphoDiTa;
use List::Util qw/sum/;

extends 'Treex::Core::Block';

has target => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'target classification set, two possible values: L1 for native speakers, L2 for second language learners',
);

my $number_of_sentences;
my $number_of_words;

my $length_of_words; # to count the average length of words by dividing $length_of_words by $number_of_words

my $number_of_typos;
my $number_of_punctuation_marks;

my $number_of_passive_verbs;
my $number_of_active_verbs;

my $number_of_indicative_mood;
my $number_of_imper_and_cond_mood;

my $number_of_proc_aspect;
my $number_of_cpl_aspect;

my $number_of_verbs;
my $number_of_future_tense;
my $number_of_present_tense;
my $number_of_past_tense;

my $number_of_case_1;
my $number_of_case_2;
my $number_of_case_3;
my $number_of_case_4;
my $number_of_case_5;
my $number_of_case_6;
my $number_of_case_7;

my $number_of_singular;
my $number_of_plural;

my $number_of_adjectives_degree_1;
my $number_of_adjectives_degree_2;
my $number_of_adjectives_degree_3;

my $number_of_adverbs_degree_1;
my $number_of_adverbs_degree_2;
my $number_of_adverbs_degree_3;

my $number_of_pos_noun;
my $number_of_pos_adj;
my $number_of_pos_pron;
my $number_of_pos_num;
my $number_of_pos_verb;
my $number_of_pos_adv;
my $number_of_pos_prep;
my $number_of_pos_conj;
my $number_of_pos_part;
my $number_of_pos_inter;

my $count_connective_words_subord;
my $count_connective_words_coord;

my %lemmas_counts;

my %t_lemmas_counts;

my %t_lemmas_counts_corrected;
my $t_lemmas_per_100_t_lemmas;
my $t_lemmas_per_100_t_lemmas_sum;
my $number_of_t_lemmas;

my $count_PREDless_sentences;

my $number_of_dependent_clauses;

my $number_of_PREDs;

my $number_of_dependent_clauses_RSTR;
my $number_of_dependent_clauses_PAT;
my $number_of_dependent_clauses_EFF;
my $number_of_dependent_clauses_COND;
my $number_of_dependent_clauses_ACT;
my $number_of_dependent_clauses_CPR;
my $number_of_dependent_clauses_PAR;
my $number_of_dependent_clauses_CAUS;
my $number_of_dependent_clauses_CNCS;
my $number_of_dependent_clauses_TWHEN;

my $number_of_tree_levels;

my $level_1_number_of_nodes; # usually 1 in each tree :-)
my $level_2_number_of_nodes;
my $level_3_number_of_nodes;
my $level_4_number_of_nodes;
my $level_5_number_of_nodes;


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

# Michal's coreference

my $pron_a_count;
my $noun_a_count;
my %pron_a_subpos_counts;
my %pron_a_lemmas;
my $to_a_count;

my $pron_t_count;
my %pron_t_sempos_counts;
my $perspron_act_t_count;
my %perspron_act_t_lemmas;

my @ALL_PRON_SUBPOS = qw/0 1 4 5 6 7 8 9 D E H J K L O P Q S W Y Z/;
my @ALL_PRON_SEMPOS = qw/n.pron.def.pers n.pron.indef adj.pron.indef n.pron.def.demon adj.pron.def.demon adv.pron.def adv.pron.indef/;
my @ALL_CHAIN_LENGTHS = 2 .. 5;
my @ALL_PERSPRON_ACT_T_LEMMAS = qw/já jeho můj on se svůj tvůj ty undef/;

# tfa

my $number_of_RHEMs;
my %RHEMs; # podobně jako u počtu různých konektorů, i tady počítám s tím, že jich bude málo, a rezignuji na normalizaci vůči délce textu
my $count_sentences_PRED_in_first_or_second;
my $count_tfa_t;
my $count_tfa_c;
my $count_tfa_f;
my $count_F_T;
my $count_ACT_at_end;
my $count_SVO;
my $count_OVS;
                      
my @ar_enclitics = qw(jsem jsi jsme jste bych bys by bychom byste si se mi ti mu mě tě ho tu to); # order of the enclitics in the main sentence
my %ha_enclitics = map { $_ => 1 } @ar_enclitics;
my $count_enclitic_at_first_position;
my $count_wrong_enclitics_order;
                      
# ========                            



sub process_document {
  my ($self, $doc) = @_;

  $target = $self->target;

  $number_of_words = 0;
  $length_of_words = 0;
  $number_of_typos = 0;
  $number_of_punctuation_marks = 0;
  
  $number_of_passive_verbs = 0;
  $number_of_active_verbs = 0;

  $number_of_indicative_mood = 0;
  $number_of_imper_and_cond_mood = 0;

  $number_of_proc_aspect = 0;
  $number_of_cpl_aspect = 0;

  $number_of_verbs = 0;
  $number_of_future_tense = 0;
  $number_of_present_tense = 0;
  $number_of_past_tense = 0;

  $number_of_case_1 = 0;
  $number_of_case_2 = 0;
  $number_of_case_3 = 0;
  $number_of_case_4 = 0;
  $number_of_case_5 = 0;
  $number_of_case_6 = 0;
  $number_of_case_7 = 0;

  $number_of_singular = 0;
  $number_of_plural = 0;

  $number_of_adjectives_degree_1 = 0;
  $number_of_adjectives_degree_2 = 0;
  $number_of_adjectives_degree_3 = 0;

  $number_of_adverbs_degree_1 = 0;
  $number_of_adverbs_degree_2 = 0;
  $number_of_adverbs_degree_3 = 0;

  $number_of_pos_noun = 0;
  $number_of_pos_adj = 0;
  $number_of_pos_pron = 0;
  $number_of_pos_num = 0;
  $number_of_pos_verb = 0;
  $number_of_pos_adv = 0;
  $number_of_pos_prep = 0;
  $number_of_pos_conj = 0;
  $number_of_pos_part = 0;
  $number_of_pos_inter = 0;
  
  
  $number_of_discourse_relations_intra = 0;
  $number_of_discourse_relations_inter = 0;
  %connectives = ();
  %t_lemmas_counts = ();

  %t_lemmas_counts_corrected = ();
  $t_lemmas_per_100_t_lemmas = 0;
  $t_lemmas_per_100_t_lemmas_sum = 0;
  $number_of_t_lemmas = 0;

  %lemmas_counts = ();

  $count_PREDless_sentences = 0;

  $number_of_dependent_clauses = 0;

  $number_of_PREDs = 0;

  $number_of_dependent_clauses_RSTR = 0;
  $number_of_dependent_clauses_PAT = 0;
  $number_of_dependent_clauses_EFF = 0;
  $number_of_dependent_clauses_COND = 0;
  $number_of_dependent_clauses_ACT = 0;
  $number_of_dependent_clauses_CPR = 0;
  $number_of_dependent_clauses_PAR = 0;
  $number_of_dependent_clauses_CAUS = 0;
  $number_of_dependent_clauses_CNCS = 0;
  $number_of_dependent_clauses_TWHEN = 0;

  $number_of_tree_levels = 0;

  $level_1_number_of_nodes = 0;
  $level_2_number_of_nodes = 0;
  $level_3_number_of_nodes = 0;
  $level_4_number_of_nodes = 0;
  $level_5_number_of_nodes = 0;

  $count_contingency = 0;
  $count_temporal = 0;
  $count_contrast = 0;
  $count_expansion = 0;
  $count_connective_words_subord = 0;
  $count_connective_words_coord = 0;

  # Michal's coreference
  
  $pron_a_count = 0;
  $noun_a_count = 0;
  %pron_a_subpos_counts = ();
  %pron_a_lemmas = ();
  $to_a_count = 0;

  $pron_t_count = 0;
  %pron_t_sempos_counts = ();
  $perspron_act_t_count = 0;
  %perspron_act_t_lemmas = ();

  # tfa
  
  $number_of_RHEMs = 0;
  %RHEMs = ();
  $count_sentences_PRED_in_first_or_second = 0;
  $count_tfa_t = 0;
  $count_tfa_c = 0;
  $count_tfa_f = 0;
  
  $count_F_T = 0;
  my $prevsent_last_t_lemma = rand(); 
  my $prevsent_lastbut1_t_lemma = rand(); 
  my $prevsent_lastbut2_t_lemma = rand();

  $count_ACT_at_end = 0;
  $count_SVO = 0;
  $count_OVS = 0;
  $count_enclitic_at_first_position = 0;
  $count_wrong_enclitics_order = 0;
  
  # ===============
  
  my $prev_root;

  my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;

  $number_of_sentences = scalar(@ttrees);
  
  foreach my $t_root (@ttrees) {

#    foreach my $t_node ($t_root->get_descendants({ordered=>1, add_self=>0})) {

    # first features from the a/m-layers
    my $a_root = get_aroot($doc, $t_root);
    my @anodes = grep {$_ ne $a_root} $a_root->get_descendants({ordered=>1, add_self=>0});
    $number_of_words += scalar(@anodes);

    # number of spelling errors
    my $tagger = Treex::Tool::Tagger::MorphoDiTa->new(
      # model => 'data/models/morphodita/cs/czech-morfflex-pdt-131112.tagger-fast',
      model => 'data/models/morphodita/cs/czech-morfflex-pdt-131112.tagger-best_accuracy',
    );
    my @forms = map {$_->form} grep {$_->form} @anodes;
    my $r_guessed = $tagger->is_guessed(\@forms);
    my $number_of_guessed = scalar(grep {$_ eq 1} @$r_guessed);
    # log_info("number of words: $number_of_words, number of guessed: $number_of_guessed\n");
    $number_of_typos+=$number_of_guessed;
    
    my $has_SVO = 0;
    my $has_OVS = 0;
    my $has_wrong_enclitics_order = 0;
    
    foreach my $anode (@anodes) {
    
      my $form = $anode->form;
      if ($form) {
        $length_of_words += length($form);
      }
      
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
      
      my $tag = $anode->tag;
      if ($tag) {
        # pos
        if ($tag =~ /^N/) {
          $number_of_pos_noun++;
        }
        elsif ($tag =~ /^A/) {
          $number_of_pos_adj++;
        } 
        elsif ($tag =~ /^P/) {
          $number_of_pos_pron++;
        } 
        elsif ($tag =~ /^C/) {
          $number_of_pos_num++;
        } 
        elsif ($tag =~ /^V/) {
          $number_of_pos_verb++;
        } 
        elsif ($tag =~ /^D/) {
          $number_of_pos_adv++;
        } 
        elsif ($tag =~ /^R/) {
          $number_of_pos_prep++;
        } 
        elsif ($tag =~ /^J/) {
          $number_of_pos_conj++;
        } 
        elsif ($tag =~ /^T/) {
          $number_of_pos_part++;
        } 
        elsif ($tag =~ /^I/) {
          $number_of_pos_inter++;
        } 
      
        if ($tag =~ /^Z/) {
          $number_of_punctuation_marks++;
        }
        if ($tag =~ /^V/) {
          $number_of_verbs++;
          if ($tag =~ /^Vs/) {
            $number_of_passive_verbs++;
          }
          if ($tag =~ /^Vp/) {
            $number_of_active_verbs++;
          }
          if ($tag =~ /^V.......F/) {
            $number_of_future_tense++;
          }
          if ($tag =~ /^V.......P/) {
            $number_of_present_tense++;
          }
          if ($tag =~ /^V.......R/) {
            $number_of_past_tense++;
          }
          # ==== tfa - count SVO and OVS (incl. VO a OV)
          if ($anode->level eq '1') { # verb as a main predicate
            my $verb_ord = $anode->get_attr('ord');
            my @echildren = $anode->get_echildren({ordered => 1});
            my @subjects_left = grep {$_->get_attr('ord') < $verb_ord} grep {$_->get_attr('afun') and $_->get_attr('afun') eq 'Sb'} @echildren;
            my @objects_left = grep {$_->get_attr('ord') < $verb_ord} grep {$_->get_attr('afun') and $_->get_attr('afun') eq 'Obj'} @echildren;
            my @subjects_right = grep {$_->get_attr('ord') > $verb_ord} grep {$_->get_attr('afun') and $_->get_attr('afun') eq 'Sb'} @echildren;
            my @objects_right = grep {$_->get_attr('ord') > $verb_ord} grep {$_->get_attr('afun') and $_->get_attr('afun') eq 'Obj'} @echildren;
            if (!scalar(@subjects_right) and scalar(@objects_right) and !scalar(@objects_left)) {
              $has_SVO = 1;
            }
            elsif (!scalar(@subjects_left) and !scalar(@objects_right) and scalar(@objects_left)) {
              $has_OVS = 1;
            }
          }
          
          # ====
        }
        
        # case:
        if ($tag =~ /^....1/) {
          $number_of_case_1++;
        }
        elsif ($tag =~ /^....2/) {
          $number_of_case_2++;
        }
        elsif ($tag =~ /^....3/) {
          $number_of_case_3++;
        }
        elsif ($tag =~ /^....4/) {
          $number_of_case_4++;
        }
        elsif ($tag =~ /^....5/) {
          $number_of_case_5++;
        }
        elsif ($tag =~ /^....6/) {
          $number_of_case_6++;
        }
        elsif ($tag =~ /^....7/) {
          $number_of_case_7++;
        }
        
        # number:
        if ($tag =~ /^...S/) {
          $number_of_singular++;
        }
        elsif ($tag =~ /^...P/) {
          $number_of_plural++;
        }
        
        # adjectives:
        if ($tag =~ /^A/) {
          if ($tag = ~ /^A........1/) {
            $number_of_adjectives_degree_1++;
          }
          elsif ($tag = ~ /^A........2/) {
            $number_of_adjectives_degree_2++;
          }
          elsif ($tag = ~ /^A........3/) {
            $number_of_adjectives_degree_3++;
          }
        }
                
        # adverbs:
        if ($tag =~ /^D/) {
          if ($tag = ~ /^D........1/) {
            $number_of_adverbs_degree_1++;
          }
          elsif ($tag = ~ /^D........2/) {
            $number_of_adverbs_degree_2++;
          }
          elsif ($tag = ~ /^D........3/) {
            $number_of_adverbs_degree_3++;
          }
        
        }
        
      }

      my $afun = $anode->get_attr('afun') // '';

      my $form_lc = lc($form // '');
      if ($afun ne 'Pred' and $ha_enclitics{$form_lc}) {
        if ($anode->get_attr('ord') eq 1) {
          $count_enclitic_at_first_position++;
        }
      }

=item

má-li věta více příklonek, jejich pořadí je následující (šlo by sledovat, kolik je v textu vět, kde toto pořadí nesouhlasí):
1. spojka -li
2. pomocné sloveso (jsem, jsi, jsme, jste, bych, bys, by, bychom, byste)
3. krátké tvary zvratných zájmen (si, se)
4. krátké tvary osobních zájmen v dativu (mi, ti, mu)
5. krátké tvary osobních zájmen v akuzativu (mě, tě, ho, tu, to)
- příklady na pořadí více příklonek: Já jsem si to myslel. Já jsem mu to dal.

=cut

      if ($afun eq 'Pred' and $anode->level eq 1) { # non-coordinated Predicate of the main sentence
        my @ar_encl_in_main = map {lc($_->get_attr('form'))} grep {$_->get_attr('form') and $ha_enclitics{lc($_->get_attr('form'))}} $anode->get_children({ordered => 1});
        my $encl_in_main = scalar(@ar_encl_in_main);
        if ($encl_in_main > 1) { # at least two enclitics in the main sentence
          for (my $i=0; $i<$encl_in_main-1; $i++) {
            my $order_1 = Treex::PML::Index(\@ar_enclitics, $ar_encl_in_main[$i]); # order in the list of all possible enclitics
            my $order_2 = Treex::PML::Index(\@ar_enclitics, $ar_encl_in_main[$i+1]);
            if ($order_1 > $order_2) {
              $has_wrong_enclitics_order = 1;
            }
          }
        }
      }
      
    }


    $count_SVO++ if ($has_SVO);
    $count_OVS++ if ($has_OVS);
    $count_wrong_enclitics_order++ if ($has_wrong_enclitics_order);
    
    # then t-layer and discourse features
    
    my @nodes = $t_root->get_descendants({ordered=>1, add_self=>0});

    my $has_PRED = 0;
    my $has_PRED_in_first_or_second = 0;
    my $depth = 0;
    foreach my $node (@nodes) {
    
      my $level = $node->get_depth();
      if ($level > $depth) {
        $depth = $level;
      }
      if ($level == 1) {
        $level_1_number_of_nodes++;
      }
      elsif ($level == 2) {
        $level_2_number_of_nodes++;
      }
      elsif ($level == 3) {
        $level_3_number_of_nodes++;
      }
      elsif ($level == 4) {
        $level_4_number_of_nodes++;
      }
      elsif ($level == 5) {
        $level_5_number_of_nodes++;
      }
    
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
      if ($functor) {
      
        if ($functor eq 'RHEM') { # tfa
          $number_of_RHEMs++;
          $RHEMs{$t_lemma}++;
        }

        if ($functor eq 'PRED') {
          $number_of_PREDs++;
          $has_PRED = 1;
          if (is_in_first_or_second_position($node)) {
            $has_PRED_in_first_or_second = 1;
          }
        }
        else { # i.e. not PRED; is it a finite verb? If yes, it means a dependent clause                    
          my @anodes = $node->get_anodes();
          my $has_finite = 0;
          foreach my $anode (@anodes) {
            my $tag = $anode->tag;
            if ($tag =~ /^V......[123]/) {
              $has_finite = 1;
              last;
            }
          }
          if ($has_finite) {
            $number_of_dependent_clauses++;
            if ($functor eq 'RSTR') {
              $number_of_dependent_clauses_RSTR++;
            }
            elsif ($functor eq 'PAT') {
              $number_of_dependent_clauses_PAT++;
            }
            elsif ($functor eq 'EFF') {
              $number_of_dependent_clauses_EFF++;
            }
            elsif ($functor eq 'COND') {
              $number_of_dependent_clauses_COND++;
            }
            elsif ($functor eq 'ACT') {
              $number_of_dependent_clauses_ACT++;
            }
            elsif ($functor eq 'CPR') {
              $number_of_dependent_clauses_CPR++;
            }
            elsif ($functor eq 'PAR') {
              $number_of_dependent_clauses_PAR++;
            }
            elsif ($functor eq 'CAUS') {
              $number_of_dependent_clauses_CAUS++;
            }
            elsif ($functor eq 'CNCS') {
              $number_of_dependent_clauses_CNCS++;
            }
            elsif ($functor eq 'TWHEN') {
              $number_of_dependent_clauses_TWHEN++;
            }            
          }
        }
      }

      my $sempos = $node->gram_sempos // '';
      if ($sempos eq 'v') {
        my $verbmod = $node->gram_verbmod();
        if ($verbmod eq 'ind') {
          $number_of_indicative_mood++;
        }
        elsif ($verbmod eq 'cdn' or $verbmod eq 'imp') {
          $number_of_imper_and_cond_mood++;
        }

        my $aspect = $node->gram_aspect();
        if ($aspect eq 'proc') {
          $number_of_proc_aspect++;
        }
        elsif ($aspect eq 'cpl') {
          $number_of_cpl_aspect++;
        }
      }

      my $tfa = $node->get_attr('tfa') // 'none';
      $count_tfa_t++ if ($tfa eq 't');
      $count_tfa_c++ if ($tfa eq 'c');
      $count_tfa_f++ if ($tfa eq 'f');
      
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
      
    }
    if (!$has_PRED) {
      $count_PREDless_sentences++;
    }
    if (!$has_PRED_in_first_or_second) {
      $count_sentences_PRED_in_first_or_second++;
    }
    $number_of_tree_levels += $depth;
    
    # ==== tfa: count sentences where the Focus of the previous sentence becomes the Topic of the current sentence - simply by checking if any of the three first t_lemmas equals to any of the last three t_lemmas of the previous sentence (do not count #PersProns!)
    # This could be improved by using the algorithm for division of the sentence into T and F parts and using coreference relations
    
    my $currentsent_first_t_lemma = $nodes[0] ? $nodes[0]->get_attr('t_lemma') // rand() : rand();
    my $currentsent_second_t_lemma = $nodes[1] ? $nodes[1]->get_attr('t_lemma') // rand() : rand();
    my $currentsent_third_t_lemma = $nodes[2] ? $nodes[2]->get_attr('t_lemma') // rand() : rand();
    
    my $F_T = 0;
    $F_T = 1 if ($currentsent_first_t_lemma eq $prevsent_last_t_lemma or $currentsent_first_t_lemma eq $prevsent_lastbut1_t_lemma or $currentsent_first_t_lemma eq $prevsent_lastbut2_t_lemma);
    $F_T = 1 if ($currentsent_second_t_lemma eq $prevsent_last_t_lemma or $currentsent_second_t_lemma eq $prevsent_lastbut1_t_lemma or $currentsent_second_t_lemma eq $prevsent_lastbut2_t_lemma);
    $F_T = 1 if ($currentsent_third_t_lemma eq $prevsent_last_t_lemma or $currentsent_third_t_lemma eq $prevsent_lastbut1_t_lemma or $currentsent_third_t_lemma eq $prevsent_lastbut2_t_lemma);
    $count_F_T++ if $F_T;
  
    $prevsent_last_t_lemma = $nodes[-1] ? $nodes[-1]->get_attr('t_lemma') // rand() : rand();
    $prevsent_lastbut1_t_lemma = $nodes[-2] ? $nodes[-2]->get_attr('t_lemma') // rand() : rand();
    $prevsent_lastbut2_t_lemma = $nodes[-3] ? $nodes[-3]->get_attr('t_lemma') // rand() : rand();
    
    $prevsent_last_t_lemma = rand() if ($prevsent_last_t_lemma eq '#PersPron');
    $prevsent_lastbut1_t_lemma = rand() if ($prevsent_lastbut1_t_lemma eq '#PersPron');
    $prevsent_lastbut2_t_lemma = rand() if ($prevsent_lastbut2_t_lemma eq '#PersPron');
    
    # ==== tfa: count sentences with main ACT at the last position in the sentence
    
    my $last_node = $nodes[-1];
    my $last_node_functor = $last_node ? $last_node->get_attr('functor') // '' : '';
    if ($last_node_functor eq 'ACT') {
      my @eparents = $last_node->get_eparents();
      if (scalar(@eparents) and $eparents[0]->get_attr('functor') and $eparents[0]->get_attr('functor') eq 'PRED') {
        $count_ACT_at_end++;
      }
    }
    
    # ====

  }

  # Michal's coreference
  
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
  
  # my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
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

  
  # counting features and creating lists of features

  my $features_all = '';
  my $features_spelling = '';
  my $features_morphology = '';
  my $features_vocabulary = '';
  my $features_syntax = '';
  my $features_connectives_quantity = '';
  my $features_connectives_diversity = '';
  my $features_coreference = '';
  my $features_tfa = '';
  
  my $file_name = $doc->full_filename();
  $file_name =~ s/^.+\/([^\/]+)$/$1/;
  # log_info "File name: $file_name\n";

  # spelling:
  
  my $typos_per_100words = ceil(100*$number_of_typos/$number_of_words);
  $features_all .= "$typos_per_100words, ";
  $features_spelling .= "$typos_per_100words, ";
  
  my $punctuation_per_100words = ceil(100*$number_of_punctuation_marks/$number_of_words);
  $features_all .= "$punctuation_per_100words, ";
  $features_spelling .= "$punctuation_per_100words, ";

  # morphology:
  
  my $passive_active_ratio_percent = ceil(100*$number_of_passive_verbs/($number_of_passive_verbs + $number_of_active_verbs + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$passive_active_ratio_percent, ";
  $features_morphology .= "$passive_active_ratio_percent, ";

  my $ind_vs_cdn_and_imp_ratio_percent = ceil(100*$number_of_indicative_mood/($number_of_indicative_mood + $number_of_imper_and_cond_mood + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$ind_vs_cdn_and_imp_ratio_percent, ";
  $features_morphology .= "$ind_vs_cdn_and_imp_ratio_percent, ";

  my $cpl_vs_proc_aspect_ratio_percent = ceil(100*$number_of_cpl_aspect/($number_of_cpl_aspect + $number_of_proc_aspect + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$cpl_vs_proc_aspect_ratio_percent, ";
  $features_morphology .= "$cpl_vs_proc_aspect_ratio_percent, ";

  my $future_tense_percent = ceil(100*$number_of_future_tense/($number_of_verbs+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$future_tense_percent, ";
  $features_morphology .= "$future_tense_percent, ";
  
  my $present_tense_percent = ceil(100*$number_of_present_tense/($number_of_verbs+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$present_tense_percent, ";
  $features_morphology .= "$present_tense_percent, ";
  
  my $past_tense_percent = ceil(100*$number_of_past_tense/($number_of_verbs+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$past_tense_percent, ";
  $features_morphology .= "$past_tense_percent, ";
  
  my $number_of_all_cases = $number_of_case_1 + $number_of_case_2 + $number_of_case_3 + $number_of_case_4 + $number_of_case_5 + $number_of_case_6 + $number_of_case_7; 
  my $case_1_percent = ceil(100*$number_of_case_1/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_1_percent, ";
  $features_morphology .= "$case_1_percent, ";
  my $case_2_percent = ceil(100*$number_of_case_2/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_2_percent, ";
  $features_morphology .= "$case_2_percent, ";
  my $case_3_percent = ceil(100*$number_of_case_3/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_3_percent, ";
  $features_morphology .= "$case_3_percent, ";
  my $case_4_percent = ceil(100*$number_of_case_4/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_4_percent, ";
  $features_morphology .= "$case_4_percent, ";
  my $case_5_percent = ceil(100*$number_of_case_5/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_5_percent, ";
  $features_morphology .= "$case_5_percent, ";
  my $case_6_percent = ceil(100*$number_of_case_6/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_6_percent, ";
  $features_morphology .= "$case_6_percent, ";
  my $case_7_percent = ceil(100*$number_of_case_7/($number_of_all_cases+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$case_7_percent, ";
  $features_morphology .= "$case_7_percent, ";

  my $sing_vs_plural_ratio_percent = ceil(100*$number_of_singular/($number_of_singular + $number_of_plural + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$sing_vs_plural_ratio_percent, ";
  $features_morphology .= "$sing_vs_plural_ratio_percent, ";

  my $adj_degree_1_vs_2_and_3_ratio_percent = ceil(100*$number_of_adjectives_degree_1/($number_of_adjectives_degree_1 + $number_of_adjectives_degree_2 + $number_of_adjectives_degree_3 + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$adj_degree_1_vs_2_and_3_ratio_percent, ";
  $features_morphology .= "$adj_degree_1_vs_2_and_3_ratio_percent, ";

  my $adv_degree_1_vs_2_and_3_ratio_percent = ceil(100*$number_of_adverbs_degree_1/($number_of_adverbs_degree_1 + $number_of_adverbs_degree_2 + $number_of_adverbs_degree_3 + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$adv_degree_1_vs_2_and_3_ratio_percent, ";
  $features_morphology .= "$adv_degree_1_vs_2_and_3_ratio_percent, ";

  my $number_of_all_pos = $number_of_pos_noun + $number_of_pos_adj + $number_of_pos_pron + $number_of_pos_num + $number_of_pos_verb + $number_of_pos_adj + $number_of_pos_prep + $number_of_pos_conj + $number_of_pos_part + $number_of_pos_inter; 
  my $pos_noun_percent = ceil(100*$number_of_pos_noun/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_noun_percent, ";
  $features_morphology .= "$pos_noun_percent, ";
  my $pos_adj_percent = ceil(100*$number_of_pos_adj/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_adj_percent, ";
  $features_morphology .= "$pos_adj_percent, ";
  my $pos_pron_percent = ceil(100*$number_of_pos_pron/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_pron_percent, ";
  $features_morphology .= "$pos_pron_percent, ";
  my $pos_num_percent = ceil(100*$number_of_pos_num/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_num_percent, ";
  $features_morphology .= "$pos_num_percent, ";
  my $pos_verb_percent = ceil(100*$number_of_pos_verb/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_verb_percent, ";
  $features_morphology .= "$pos_verb_percent, ";
  my $pos_adv_percent = ceil(100*$number_of_pos_adv/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_adv_percent, ";
  $features_morphology .= "$pos_adv_percent, ";
  my $pos_prep_percent = ceil(100*$number_of_pos_prep/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_prep_percent, ";
  $features_morphology .= "$pos_prep_percent, ";
  my $pos_conj_percent = ceil(100*$number_of_pos_conj/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_conj_percent, ";
  $features_morphology .= "$pos_conj_percent, ";
  my $pos_part_percent = ceil(100*$number_of_pos_part/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_part_percent, ";
  $features_morphology .= "$pos_part_percent, ";
  my $pos_inter_percent = ceil(100*$number_of_pos_inter/($number_of_all_pos+0.01)); # +0.01 to avoid division by 0
  $features_all .= "$pos_inter_percent, ";
  $features_morphology .= "$pos_inter_percent, ";

  # vocabulary:
  
  if (!$t_lemmas_per_100_t_lemmas) { # not set yet, i.e. there have been only less than 100 t_lemmas in total  
    $t_lemmas_per_100_t_lemmas = scalar (keys (%t_lemmas_counts_corrected)); # take only the number of so far observed different t_lemmas (do not normalize to 100 observed t_lemmas)
    # print STDERR "There have not been 100 t_lemmas in the text - counting only so far observed different t_lemmas (in $number_of_t_lemmas): $t_lemmas_per_100_t_lemmas.\n";
  }
  
  $features_all .= ceil($t_lemmas_per_100_t_lemmas) . ', ';
  $features_vocabulary .= ceil($t_lemmas_per_100_t_lemmas) . ', ';
  
  my $simpson_index = get_simpson_index();
  $features_all .= "$simpson_index, ";
  $features_vocabulary .= "$simpson_index, ";
  
  my $yule_index = get_george_udny_yule_index();
  $features_all .= "$yule_index, ";
  $features_vocabulary .= "$yule_index, ";

  my $avg_length_of_words = ceil($length_of_words / $number_of_words);
  $features_all .= "$avg_length_of_words, ";
  $features_vocabulary .= "$avg_length_of_words, ";
  
  # syntax:
  
  my $avg_words_per_sentence = ceil($number_of_words/$number_of_sentences);
  $features_all .= "$avg_words_per_sentence, ";
  $features_syntax .= "$avg_words_per_sentence, ";

  my $avg_PREDless_per_100sent = ceil(100*$count_PREDless_sentences/$number_of_sentences);
  $features_all .= "$avg_PREDless_per_100sent, ";
  $features_syntax .= "$avg_PREDless_per_100sent, ";

  my $dependent_vs_sentences_ratio_percent = ceil(100*$number_of_dependent_clauses/($number_of_dependent_clauses + $number_of_sentences + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$dependent_vs_sentences_ratio_percent, ";
  $features_syntax .= "$dependent_vs_sentences_ratio_percent, ";

  my $PREDs_per_100sent = ceil(100*$number_of_PREDs/$number_of_sentences);
  $features_all .= "$PREDs_per_100sent, ";
  $features_syntax .= "$PREDs_per_100sent, ";
  
  my $dependent_clauses_RSTR_percent = ceil(100*$number_of_dependent_clauses_RSTR/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_RSTR_percent, ";
  $features_syntax .= "$dependent_clauses_RSTR_percent, ";
  my $dependent_clauses_PAT_percent = ceil(100*$number_of_dependent_clauses_PAT/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_PAT_percent, ";
  $features_syntax .= "$dependent_clauses_PAT_percent, ";
  my $dependent_clauses_EFF_percent = ceil(100*$number_of_dependent_clauses_EFF/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_EFF_percent, ";
  $features_syntax .= "$dependent_clauses_EFF_percent, ";
  my $dependent_clauses_COND_percent = ceil(100*$number_of_dependent_clauses_COND/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_COND_percent, ";
  $features_syntax .= "$dependent_clauses_COND_percent, ";
  my $dependent_clauses_ACT_percent = ceil(100*$number_of_dependent_clauses_ACT/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_ACT_percent, ";
  $features_syntax .= "$dependent_clauses_ACT_percent, ";
  my $dependent_clauses_CPR_percent = ceil(100*$number_of_dependent_clauses_CPR/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_CPR_percent, ";
  $features_syntax .= "$dependent_clauses_CPR_percent, ";
  my $dependent_clauses_PAR_percent = ceil(100*$number_of_dependent_clauses_PAR/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_PAR_percent, ";
  $features_syntax .= "$dependent_clauses_PAR_percent, ";
  my $dependent_clauses_CAUS_percent = ceil(100*$number_of_dependent_clauses_CAUS/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_CAUS_percent, ";
  $features_syntax .= "$dependent_clauses_CAUS_percent, ";
  my $dependent_clauses_CNCS_percent = ceil(100*$number_of_dependent_clauses_CNCS/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_CNCS_percent, ";
  $features_syntax .= "$dependent_clauses_CNCS_percent, ";
  my $dependent_clauses_TWHEN_percent = ceil(100*$number_of_dependent_clauses_TWHEN/($number_of_dependent_clauses + 0.01));
  $features_all .= "$dependent_clauses_TWHEN_percent, ";
  $features_syntax .= "$dependent_clauses_TWHEN_percent, ";

  my $avg_tree_levels = ceil($number_of_tree_levels/$number_of_sentences);
  $features_all .= "$avg_tree_levels, ";
  $features_syntax .= "$avg_tree_levels, ";
  
  my $level_1_avg_branching = ceil($level_2_number_of_nodes/($level_1_number_of_nodes + 0.01));
  $features_all .= "$level_1_avg_branching, ";
  $features_syntax .= "$level_1_avg_branching, ";

  my $level_2_avg_branching = ceil($level_3_number_of_nodes/($level_2_number_of_nodes + 0.01));
  $features_all .= "$level_2_avg_branching, ";
  $features_syntax .= "$level_2_avg_branching, ";

  my $level_3_avg_branching = ceil($level_4_number_of_nodes/($level_3_number_of_nodes + 0.01));
  $features_all .= "$level_3_avg_branching, ";
  $features_syntax .= "$level_3_avg_branching, ";

  my $level_4_avg_branching = ceil($level_5_number_of_nodes/($level_4_number_of_nodes + 0.01));
  $features_all .= "$level_4_avg_branching, ";
  $features_syntax .= "$level_4_avg_branching, ";

  # connectives quantity:
  
  my $avg_connective_words_coord_per_100sent = ceil(100*$count_connective_words_coord/$number_of_sentences);
  $features_all .= "$avg_connective_words_coord_per_100sent, ";
  $features_connectives_quantity .= "$avg_connective_words_coord_per_100sent, ";
  
  my $avg_connective_words_subord_per_100sent = ceil(100*$count_connective_words_subord/$number_of_sentences);
  $features_all .= "$avg_connective_words_subord_per_100sent, ";
  $features_connectives_quantity .= "$avg_connective_words_coord_per_100sent, ";
  
  my $avg_connective_words_per_100sent = ceil(100*($count_connective_words_coord+$count_connective_words_subord)/$number_of_sentences);
  $features_all .= "$avg_connective_words_per_100sent, ";
  $features_connectives_quantity .= "$avg_connective_words_per_100sent, ";
  
  my $avg_discourse_intra_per_100sentences = ceil(100*$number_of_discourse_relations_intra/$number_of_sentences);
  $features_all .= "$avg_discourse_intra_per_100sentences, ";
  $features_connectives_quantity .= "$avg_discourse_intra_per_100sentences, ";
  
  my $avg_discourse_inter_per_100sentences = ceil(100*$number_of_discourse_relations_inter/$number_of_sentences);
  $features_all .= "$avg_discourse_inter_per_100sentences, ";
  $features_connectives_quantity .= "$avg_discourse_inter_per_100sentences, ";
  
  my $avg_discourse_per_100sentences = ceil(100*($number_of_discourse_relations_inter + $number_of_discourse_relations_intra)/$number_of_sentences);
  $features_all .= "$avg_discourse_per_100sentences, ";
  $features_connectives_quantity .= "$avg_discourse_per_100sentences, ";
  
  # connectives_diversity:
  
  my $number_of_different_connectives = scalar(keys(%connectives));
  $features_all .= "$number_of_different_connectives, ";
  $features_connectives_diversity .= "$number_of_different_connectives, ";

  my $avg_a_per_100connectives = ceil(100*(scalar($connectives{'a'}) ? scalar($connectives{'a'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_a_per_100connectives, ";
  $features_connectives_diversity .= "$avg_a_per_100connectives, ";
  
  my $avg_ale_per_100connectives = ceil(100*(scalar($connectives{'ale'}) ? scalar($connectives{'ale'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_ale_per_100connectives, ";
  $features_connectives_diversity .= "$avg_ale_per_100connectives, ";
  
  my $avg_protoze_per_100connectives = ceil(100*(scalar($connectives{'protože'}) ? scalar($connectives{'protože'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_protoze_per_100connectives, ";
  $features_connectives_diversity .= "$avg_protoze_per_100connectives, ";

  my $avg_take_taky_per_100connectives = ceil(100*((scalar($connectives{'také'}) or scalar($connectives{'taky'})) ? scalar($connectives{'také'}//0 + $connectives{'taky'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_take_taky_per_100connectives, ";
  $features_connectives_diversity .= "$avg_take_taky_per_100connectives, ";

  my $avg_potom_pak_per_100connectives = ceil(100*((scalar($connectives{'potom'}) or scalar($connectives{'pak'})) ? scalar($connectives{'potom'}//0 + $connectives{'pak'}//0) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_potom_pak_per_100connectives, ";
  $features_connectives_diversity .= "$avg_potom_pak_per_100connectives, ";

  my $avg_kdyz_per_100connectives = ceil(100*(scalar($connectives{'když'}) ? scalar($connectives{'když'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_kdyz_per_100connectives, ";
  $features_connectives_diversity .= "$avg_kdyz_per_100connectives, ";

  my $avg_nebo_per_100connectives = ceil(100*(scalar($connectives{'nebo'}) ? scalar($connectives{'nebo'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_nebo_per_100connectives, ";
  $features_connectives_diversity .= "$avg_nebo_per_100connectives, ";

  my $avg_proto_per_100connectives = ceil(100*(scalar($connectives{'proto'}) ? scalar($connectives{'proto'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_proto_per_100connectives, ";
  $features_connectives_diversity .= "$avg_proto_per_100connectives, ";

  my $avg_tak_per_100connectives = ceil(100*(scalar($connectives{'tak'}) ? scalar($connectives{'tak'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_tak_per_100connectives, ";
  $features_connectives_diversity .= "$avg_tak_per_100connectives, ";

  my $avg_aby_per_100connectives = ceil(100*(scalar($connectives{'aby'}) ? scalar($connectives{'aby'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_aby_per_100connectives, ";
  $features_connectives_diversity .= "$avg_aby_per_100connectives, ";

  my $avg_totiz_per_100connectives = ceil(100*(scalar($connectives{'totiž'}) ? scalar($connectives{'totiž'}) : 0)/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  $features_all .= "$avg_totiz_per_100connectives, ";
  $features_connectives_diversity .= "$avg_totiz_per_100connectives, ";


  my @connective_usages_sorted = sort {$b <=> $a} map {$connectives{$_}} keys (%connectives); # sort numbers of usages of the connectives in the decreasing order (disregard the connectives themselves)
  my $percent_most_frequent_connectives_first = 0;
  if (scalar(@connective_usages_sorted) >= 1) {
    my $most_frequent_connectives_first = $connective_usages_sorted[0];
    $percent_most_frequent_connectives_first = ceil(100*$most_frequent_connectives_first/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  }
  $features_all .= "$percent_most_frequent_connectives_first, ";
  $features_connectives_diversity .= "$percent_most_frequent_connectives_first, ";

  my $percent_most_frequent_connectives_first_and_second = 0;
  if (scalar(@connective_usages_sorted) >= 2) {
    my $most_frequent_connectives_first_and_second = $connective_usages_sorted[0] + $connective_usages_sorted[1];
    $percent_most_frequent_connectives_first_and_second = ceil(100*$most_frequent_connectives_first_and_second/($number_of_discourse_relations_inter + $number_of_discourse_relations_intra + 0.01));
  }
  else {
    $percent_most_frequent_connectives_first_and_second = $percent_most_frequent_connectives_first;
  }
  $features_all .= "$percent_most_frequent_connectives_first_and_second, ";
  $features_connectives_diversity .= "$percent_most_frequent_connectives_first_and_second, ";

  my $percentage_temporal = ceil(100*$count_temporal/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features_all .= "$percentage_temporal, ";
  $features_connectives_diversity .= "$percentage_temporal, ";

  my $percentage_contingency = ceil(100*$count_contingency/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features_all .= "$percentage_contingency, ";
  $features_connectives_diversity .= "$percentage_contingency, ";

  my $percentage_contrast = ceil(100*$count_contrast/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features_all .= "$percentage_contrast, ";
  $features_connectives_diversity .= "$percentage_contrast, ";

  my $percentage_expansion = ceil(100*$count_expansion/($count_temporal + $count_contingency + $count_contrast + $count_expansion + 0.01));
  $features_all .= "$percentage_expansion, ";
  $features_connectives_diversity .= "$percentage_expansion, ";

  # (Michal's) coreference (two parts - PRONOUN and COREFERENCE):

  # PRONOUN FEATURES

  my $prons_a_perc_words = ceil($number_of_words ? 100*$pron_a_count/$number_of_words : 0);
  $features_all .= "$prons_a_perc_words, "; 
  $features_coreference .= "$prons_a_perc_words, ";
  
  my $prons_a_perc_nps = ceil(($pron_a_count+$noun_a_count) ? 100*$pron_a_count/($pron_a_count+$noun_a_count) : 0);
  $features_all .= "$prons_a_perc_nps, "; 
  $features_coreference .= "$prons_a_perc_nps, ";

  foreach my $subpos (@ALL_PRON_SUBPOS) {
    my $subpos_count = $pron_a_subpos_counts{$subpos} // 0;
    my $prons_a_SUBPOS_perc_words = ceil($number_of_words ? 100*$subpos_count/$number_of_words : 0);
    $features_all .= "$prons_a_SUBPOS_perc_words, ";
    $features_coreference .= "$prons_a_SUBPOS_perc_words, ";
  }

  foreach my $subpos (@ALL_PRON_SUBPOS) {
    my $subpos_count = $pron_a_subpos_counts{$subpos} // 0;
    my $prons_a_SUBPOS_perc_prons = ceil($pron_a_count ? 100*$subpos_count/$pron_a_count : 0);
    $features_all .= "$prons_a_SUBPOS_perc_prons, ";
    $features_coreference .= "$prons_a_SUBPOS_perc_prons, ";
  }

  foreach my $subpos (@ALL_PRON_SUBPOS) {
    my $subpos_count = $pron_a_subpos_counts{$subpos} // 0;
    my $prons_a_SUBPOS_perc_nps = ceil(($pron_a_count+$noun_a_count) ? 100*$subpos_count/($pron_a_count+$noun_a_count) : 0);
    $features_all .= "$prons_a_SUBPOS_perc_nps, ";
    $features_coreference .= "$prons_a_SUBPOS_perc_nps, ";
  }
    
  my $prons_a_lemmas_perc_words = ceil($number_of_words ? 100*scalar(keys %pron_a_lemmas)/$number_of_words : 0);
  $features_all .= "$prons_a_lemmas_perc_words, "; 
  $features_coreference .= "$prons_a_lemmas_perc_words, ";
  
  my $prons_a_lemmas_perc_prons = ceil($pron_a_count ? 100*scalar(keys %pron_a_lemmas)/$pron_a_count : 0);
  $features_all .= "$prons_a_lemmas_perc_prons, "; 
  $features_coreference .= "$prons_a_lemmas_perc_prons, ";
  
  my $to_a_perc_prons = ceil($pron_a_count ? 100*$to_a_count/$pron_a_count : 0);
  $features_all .= "$to_a_perc_prons, "; 
  $features_coreference .= "$to_a_perc_prons, ";

  my $prons_t_perc_tnodes = ceil($number_of_t_lemmas ? 100*$pron_t_count/$number_of_t_lemmas : 0);
  $features_all .= "$prons_t_perc_tnodes, "; 
  $features_coreference .= "$prons_t_perc_tnodes, ";
  
  foreach my $sempos (@ALL_PRON_SEMPOS) {
    my $sempos_count = $pron_t_sempos_counts{$sempos} // 0;
    my $prons_t_SEMPOS_perc_prons = ceil($pron_t_count ? 100*$sempos_count/$pron_t_count : 0);
    $features_all .= "$prons_t_SEMPOS_perc_prons, ";
    $features_coreference .= "$prons_t_SEMPOS_perc_prons, ";
  }

  foreach my $tlemma (@ALL_PERSPRON_ACT_T_LEMMAS) {
    my $lemma_count = $perspron_act_t_lemmas{$tlemma} // 0;
    my $perspron_t_LEMMA_perc_persprons = ceil($perspron_act_t_count ? 100*$lemma_count/$perspron_act_t_count : 0);
    $features_all .= "$perspron_t_LEMMA_perc_persprons, ";
    $features_coreference .= "$perspron_t_LEMMA_perc_persprons, ";
  }

  # COREFERENCE FEATURES
  
  # my @ttrees = map { $_->get_tree($self->language, 't', $self->selector) } $doc->get_bundles;
  my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, {ordered => 'deepord'});

  my $chains_perc_words = ceil($number_of_words ? 100*scalar(@chains)/$number_of_words : 0);
  $features_all .= "$chains_perc_words, ";
  $features_coreference .= "$chains_perc_words, ";
    
  my $num_links = (sum(map {scalar(@$_)} @chains) // 0) - scalar(@chains);
  my $links_perc_words = ceil($number_of_words ? 100*$num_links/$number_of_words : 0);
  $features_all .= "$links_perc_words, ";
  $features_coreference .= "$links_perc_words, ";
    
  my %link_lengths;
  $link_lengths{scalar(@$_) < 5 ? scalar(@$_) : 5}++ foreach (@chains);
  foreach my $len (@ALL_CHAIN_LENGTHS) {
    my $chains_len_LENGTH_perc_chains = ceil(scalar(@chains) ? 100*($link_lengths{$len} // 0)/scalar(@chains) : 0);
    $features_all .= "$chains_len_LENGTH_perc_chains, ";
    $features_coreference .= "$chains_len_LENGTH_perc_chains, ";
  }
    
  my $intrasent_links = 0;
  foreach my $chain (@chains) {
    my $prev_sentnum = undef;
    foreach my $mention (@$chain) {
      my $sentnum = $mention->get_bundle->get_position;
      $intrasent_links++ if (defined $prev_sentnum && $sentnum == $prev_sentnum);
      $prev_sentnum = $sentnum;
    }
  }
  my $links_intra_perc_links = ceil($num_links ? 100*$intrasent_links/$num_links : 0);
  $features_all .= "$links_intra_perc_links, ";
  $features_coreference .= "$links_intra_perc_links, ";

  my $avg_lemmas_per_len = 0;
  my $avg_sempos_per_len = 0;
  foreach my $chain (@chains) {
    my $lemmas_per_len = scalar(uniq map {$_->t_lemma} @$chain)/scalar(@$chain);
    my $sempos_per_len = scalar(uniq map {$_->gram_sempos // "undef"} @$chain)/scalar(@$chain);
    $avg_lemmas_per_len += $lemmas_per_len;
    $avg_sempos_per_len += $sempos_per_len;
  }
  $avg_lemmas_per_len = scalar(@chains) ? $avg_lemmas_per_len / scalar(@chains) : 0;
  $avg_sempos_per_len = scalar(@chains) ? $avg_sempos_per_len / scalar(@chains) : 0;
  my $avg_lemma_variety = ceil(100*$avg_lemmas_per_len);
  $features_all .= "$avg_lemma_variety, ";
  $features_coreference .= "$avg_lemma_variety, ";
  my $avg_sempos_variety = ceil(100*$avg_sempos_per_len);
  $features_all .= "$avg_sempos_variety, ";
  $features_coreference .= "$avg_sempos_variety, ";

  # tfa features:
  
  my $RHEMs_per_100words = ceil(100*$number_of_RHEMs/$number_of_words);
  $features_all .= "$RHEMs_per_100words, ";
  $features_tfa .= "$RHEMs_per_100words, ";

  my $number_of_different_RHEMs = scalar(keys(%RHEMs));
  $features_all .= "$number_of_different_RHEMs, ";
  $features_tfa .= "$number_of_different_RHEMs, ";

  my $avg_sent_PRED_in_first_or_second_per_100sent = ceil(100*$count_sentences_PRED_in_first_or_second/$number_of_sentences);
  $features_all .= "$avg_sent_PRED_in_first_or_second_per_100sent, ";
  $features_tfa .= "$avg_sent_PRED_in_first_or_second_per_100sent, ";

  my $tfa_bound_nonbound_ratio_percent = ceil(100*($count_tfa_c + $count_tfa_t)/($count_tfa_c + $count_tfa_t + $count_tfa_f + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$tfa_bound_nonbound_ratio_percent, ";
  $features_tfa .= "$tfa_bound_nonbound_ratio_percent, ";

  my $tfa_contrastive_among_bound_percent = ceil(100*($count_tfa_c)/($count_tfa_c + $count_tfa_t + 0.01)); # +0.01 to avoid division by 0
  $features_all .= "$tfa_contrastive_among_bound_percent, ";
  $features_tfa .= "$tfa_contrastive_among_bound_percent, ";

  my $tfa_F_T_per_100sent = ceil(100*$count_F_T/$number_of_sentences);
  $features_all .= "$tfa_F_T_per_100sent, ";
  $features_tfa .= "$tfa_F_T_per_100sent, ";

  my $tfa_ACT_at_end_per_100sent = ceil(100*$count_ACT_at_end/$number_of_sentences);
  $features_all .= "$tfa_ACT_at_end_per_100sent, ";
  $features_tfa .= "$tfa_ACT_at_end_per_100sent, ";

  my $tfa_SVO_per_100sent = ceil(100*$count_SVO/$number_of_sentences);
  $features_all .= "$tfa_SVO_per_100sent, ";
  $features_tfa .= "$tfa_SVO_per_100sent, ";

  my $tfa_OVS_per_100sent = ceil(100*$count_OVS/$number_of_sentences);
  $features_all .= "$tfa_OVS_per_100sent, ";
  $features_tfa .= "$tfa_OVS_per_100sent, ";

  my $tfa_enclitic_first_per_100sent = ceil(100*$count_enclitic_at_first_position/$number_of_sentences);
  $features_all .= "$tfa_enclitic_first_per_100sent, ";
  $features_tfa .= "$tfa_enclitic_first_per_100sent, ";

  my $tfa_wrong_enclitics_order_per_100sent = ceil(100*$count_wrong_enclitics_order/$number_of_sentences);
  $features_all .= "$tfa_wrong_enclitics_order_per_100sent, ";
  $features_tfa .= "$tfa_wrong_enclitics_order_per_100sent, ";

  
  #my $coherence_mark = get_document_attr('CEFR_coherence');
  #if ($coherence_mark) {
  #  $features_all .= "$coherence_mark";
  #  $features_spelling .= "$coherence_mark";
  #  $features_morphology .= "$coherence_mark";
  #  $features_vocabulary .= "$coherence_mark";
  #  $features_syntax .= "$coherence_mark";
  #  $features_connectives_quantity .= "$coherence_mark";
  #  $features_connectives_diversity .= "$coherence_mark";
  #  $features_coreference .= "$coherence_mark";
  #}
  #else {
    $features_all .= "?";
    $features_spelling .= "?";
    $features_morphology .= "?";
    $features_vocabulary .= "?";
    $features_syntax .= "?";
    $features_connectives_quantity .= "?";
    $features_connectives_diversity .= "?";
    $features_coreference .= "?";
    $features_tfa .= "?";
  #}

  # the output in the arff format:
  my $arff_all = get_weka_header('all') . $features_all . "\n";
  my $arff_spelling = get_weka_header('spelling') . $features_spelling . "\n";
  my $arff_morphology = get_weka_header('morphology') . $features_morphology . "\n";
  my $arff_vocabulary = get_weka_header('vocabulary') . $features_vocabulary . "\n";
  my $arff_syntax = get_weka_header('syntax') . $features_syntax . "\n";
  my $arff_connectives_quantity = get_weka_header('connectives_quantity') . $features_connectives_quantity . "\n";
  my $arff_connectives_diversity = get_weka_header('connectives_diversity') . $features_connectives_diversity . "\n";
  my $arff_coreference = get_weka_header('coreference') . $features_coreference . "\n";
  my $arff_tfa = get_weka_header('tfa') . $features_tfa . "\n";

  log_info("Training values - all features:\t$file_name\t$features_all\n");
  log_info("Training values - spelling features:\t$file_name\t$features_spelling\n");
  log_info("Training values - morphology features:\t$file_name\t$features_morphology\n");
  log_info("Training values - vocabulary features:\t$file_name\t$features_vocabulary\n");
  log_info("Training values - syntax features:\t$file_name\t$features_syntax\n");
  log_info("Training values - connectives_quantity features:\t$file_name\t$features_connectives_quantity\n");
  log_info("Training values - connectives_diversity features:\t$file_name\t$features_connectives_diversity\n");
  log_info("Training values - coreference features:\t$file_name\t$features_coreference\n");
  log_info("Training values - tfa features:\t$file_name\t$features_tfa\n");
  
  log_info("Arff - all features:\n\n$arff_all\n");
  log_info("Arff - spelling features:\n\n$arff_spelling\n");
  log_info("Arff - morphology features:\n\n$arff_morphology\n");
  log_info("Arff - vocabulary features:\n\n$arff_vocabulary\n");
  log_info("Arff - syntax features:\n\n$arff_syntax\n");
  log_info("Arff - connectives_quantity features:\n\n$arff_connectives_quantity\n");
  log_info("Arff - connectives_diversity features:\n\n$arff_connectives_diversity\n");
  log_info("Arff - coreference features:\n\n$arff_coreference\n");
  log_info("Arff - tfa features:\n\n$arff_tfa\n");

  # store it in the document to be available for the subsequent Treex module(s)
  $doc->{'coherence_weka_arff_all'} = $arff_all;
  $doc->{'coherence_weka_arff_spelling'} = $arff_spelling;
  $doc->{'coherence_weka_arff_morphology'} = $arff_morphology;
  $doc->{'coherence_weka_arff_vocabulary'} = $arff_vocabulary;
  $doc->{'coherence_weka_arff_syntax'} = $arff_syntax;
  $doc->{'coherence_weka_arff_connectives_quantity'} = $arff_connectives_quantity;
  $doc->{'coherence_weka_arff_connectives_diversity'} = $arff_connectives_diversity;
  $doc->{'coherence_weka_arff_coreference'} = $arff_coreference;
  $doc->{'coherence_weka_arff_tfa'} = $arff_tfa;
  
} # process_document


sub get_weka_header {
  my ($set) = @_;
  
  my $header = '@RELATION Evald' . "\n\n";

  if ($set =~ /(all|spelling)/) {
    $header .= '@ATTRIBUTE typos_per_100words  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE punctuation_per_100words  NUMERIC' . "\n";
  }

  if ($set =~ /(all|morphology)/) {
    $header .= '@ATTRIBUTE passive_vs_active_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE ind_vs_cdn_and_imp_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE cpl_vs_proc_aspect_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE future_tense_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE present_tense_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE past_tense_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_1_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_2_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_3_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_4_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_5_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_6_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE case_7_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE sing_vs_plural_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE adj_degree_1_vs_2_and_3_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE adv_degree_1_vs_2_and_3_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_noun_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_adj_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_pron_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_num_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_verb_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_adv_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_prep_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_conj_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_part_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE pos_inter_percent  NUMERIC' . "\n";
  }

  if ($set =~ /(all|vocabulary)/) {
    $header .= '@ATTRIBUTE different_t_lemmas_per_100t_lemmas  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE simpson_index  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE george_udny_yule_index  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_length_of_words  NUMERIC' . "\n";
  }

  if ($set =~ /(all|syntax)/) {
    $header .= '@ATTRIBUTE avg_words_per_sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_PREDless_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_vs_sentences_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE PREDs_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_RSTR_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_PAT_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_EFF_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_COND_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_ACT_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_CPR_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_PAR_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_CAUS_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_CNCS_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE dependent_clauses_TWHEN_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_tree_levels  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE level_1_avg_branching  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE level_2_avg_branching  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE level_3_avg_branching  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE level_4_avg_branching  NUMERIC' . "\n";
  }

  
  if ($set =~ /(all|connectives_quantity)/) {
    $header .= '@ATTRIBUTE avg_connective_words_coord_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_connective_words_subord_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_connective_words_per_100sent  NUMERIC' . "\n";
    
    $header .= '@ATTRIBUTE avg_intra_per_100sent   NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_inter_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_discourse_per_100sent   NUMERIC' . "\n";
  }
  
  if ($set =~ /(all|connectives_diversity)/) {
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
  }
  
  if ($set =~ /(all|coreference)/) {

    # Note:
    # @ALL_PRON_SUBPOS = qw/0 1 4 5 6 7 8 9 D E H J K L O P Q S W Y Z/;
    # @ALL_PRON_SEMPOS = qw/n.pron.def.pers n.pron.indef adj.pron.indef n.pron.def.demon adj.pron.def.demon adv.pron.def adv.pron.indef/;
    # @ALL_CHAIN_LENGTHS = 2 .. 5;
    # @ALL_PERSPRON_ACT_T_LEMMAS = qw/já jeho můj on se svůj tvůj ty undef/;
  
    $header .= '@ATTRIBUTE prons_a_perc_words  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE prons_a_perc_nps  NUMERIC' . "\n";

    foreach my $subpos (@ALL_PRON_SUBPOS) {
      $header .= '@ATTRIBUTE prons_a_' . $subpos . '_perc_words  NUMERIC' . "\n";
    }
    
    foreach my $subpos (@ALL_PRON_SUBPOS) {
      $header .= '@ATTRIBUTE prons_a_' . $subpos . '_perc_prons  NUMERIC' . "\n";
    }

    foreach my $subpos (@ALL_PRON_SUBPOS) {
      $header .= '@ATTRIBUTE prons_a_' . $subpos . '_perc_nps  NUMERIC' . "\n";
    }

    $header .= '@ATTRIBUTE prons_a_lemmas_perc_words  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE prons_a_lemmas_perc_prons  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE to_a_perc_prons  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE prons_t_perc_tnodes  NUMERIC' . "\n";

    foreach my $sempos (@ALL_PRON_SEMPOS) {
      $header .= '@ATTRIBUTE prons_t_' . $sempos . '_perc_prons  NUMERIC' . "\n";
    }
    
    foreach my $tlemma (@ALL_PERSPRON_ACT_T_LEMMAS) {
      $header .= '@ATTRIBUTE perspron_t_' . $tlemma . '_perc_persprons  NUMERIC' . "\n";
    }

    $header .= '@ATTRIBUTE chains_perc_words  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE links_perc_words  NUMERIC' . "\n";
    
    foreach my $len (@ALL_CHAIN_LENGTHS) {
      $header .= '@ATTRIBUTE chains_len_' . $len . '_perc_chains  NUMERIC' . "\n";
    }
    
    $header .= '@ATTRIBUTE links_intra_perc_links  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_lemma_variety  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE avg_sempos_variety  NUMERIC' . "\n";
    
  }
  
  if ($set =~ /(all|tfa)/) {
    $header .= '@ATTRIBUTE tfa_RHEMs_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_different_RHEMs  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_avg_sent_PRED_in_first_or_second_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_bound_vs_nonbound_ratio_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_contrastive_among_bound_percent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_F_T_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_ACT_at_end_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_SVO_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_OVS_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_enclitic_first_per_100sent  NUMERIC' . "\n";
    $header .= '@ATTRIBUTE tfa_wrong_enclitics_order_per_100sent  NUMERIC' . "\n";
  }


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


=item

  The function checks whether the given verb node is on the first or second position in the clause.
  If yes, it returns 1; otherwise 0.

=cut

sub is_in_first_or_second_position {
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
} # is_in_first_or_second_position




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


