package Treex::Block::T2TAMR::AmrConvertor;
# usage: treex Read::Treex from=csen.merged.treex.gz T2TAMR::AmrConvertor language=cs rules_file=corpus.tamr.gz [verbalization_file=N_V.txt] Write::Treex to=csen.merged.with_tamr.treex.gz

use Moose;
use Treex::Core::Common;
use Unicode::Normalize;

use File::Slurp;

extends 'Treex::Core::Block';

has 'rules_file' => ( isa => 'Maybe[Str]', is => 'ro' );

has 'verbalization_file' => ( isa => 'Maybe[Str]', is => 'ro' );

has 'verb_rules' => ( is => 'ro', isa => 'Maybe[HashRef]', builder => '_load_verbalization', lazy => 1);

has 'rules' => ( is => 'ro', isa => 'Treex::Core::Document', builder => '_load_rules', lazy => 1 );

has '+language'       => ( required => 1 );
has '+selector'       => ( required => 1, isa => 'Str', default => 'amrClonedFromT' );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

# TODO: copy attributes in a cleverer way
my @ATTRS_TO_COPY = qw(ord t_lemma functor);

my $active_rule_label = qw(active_query);
  # simply use the following in place of AMR modifier
my %modifier_is_ftor = map {($_, 1)} qw(COORD APOS PAR DENOM VOCAT);
  # deterministically map the following
my %modifier_from_ftor = qw(
ACT  	ARG0
PAT  	ARG1
ADDR 	ARG2
ORIG 	ARG3
EFF  	ARG4
TWHEN	time
THL  	duration
DIR1 	source
DIR3 	direction
DIR2 	location
LOC  	location
BEN  	beneficiary
ACMP 	accompanier
MANN 	manner
AIM  	purpose
CAUS 	cause
MEANS	instrument
APP  	poss
CMP  	compared-to
RSTR 	mod
EXT  	scale
);
# TODO: Move this list of rule ids and mapping rule ids to corresponding rule tamr tree to another file
my @rules_ids = qw (
001a
001b
001c
001d
001e
002a
002b
002c
003a
003b
004a
004b
005a
005b
006a
006b
007a
007b
007c
007d
008a
008b
009a
009b
010a
010b
011a
011b
012a
012b
012c
013a
013b
014a
015a
016a
017a
017b
017c
018a
019a
019b
020a
020b
020c
021a
021b
021c
022a
022b
022c
022d
023a
023b
024a
024b
025a
025b
026a
027a
028a
028b
029a
029b
030a
030b
031a
031b
032a
032b
033a
033b
034a
034b
035a
035b
036a
036b
037a
037b
037c
038a
039a
040a
041a
042a
043a
044a
045a
045b
046a
047a
048a
048b
049a
049b
050a
051a
051b
052a
052b
053a
053b
053c
053d
053e
054a
054b
055a
055b
056a
057a
058a
058b
059a
060a
061a
062a
063a
064a
065a
065b
066a
066b
067a
067b
067c
068a
069a
069b
069c
070a
070b
070c
070d
071a
071b
072a
073a
074a
075a
076a
077a
078a
078b
079a
080a
080b
081a
081b
082a
082b
083a
083b
083c
084a
085a
085b
086a
087a
087b
087c
088a
088b
088c
089a
089b
089c
090a
091a
092a
092b
092c
093a
094a
095a
096a
097a
098a
099a
100a
101a
102a
103a
104a
105a
106a
107a
108a
109a
110a
110b
111a
112a
113a
113b
113c
114a
114b
115a
115b
115c
116a
116b
117a
117b
118a
118b
119a
119b
120a
120b
121a
122a
123a
124a
125a
126a
127a
128a
129a
130a
131a
131b
132a
133a
134a
135a
136a
137a
138a
138b
139a
139b
140a
140b
141a
142a
143a
144a
145a
146a
147a
148a
148b
149a
150a
151a
152a
153a
154a
155a
156a
157a
157b
158a
159a
160a
161a
162a
163a
163b
164a
164b
164c
165a
165b
166a
167a
168a
169a
169b
169c
170a
171a
172a
173a
173b
174a
174b
175a
176a
177a
178a
179a
180a
181a
182a
183a
184a
184b
184c
185a
185b
186a
187a
187b
188a
189a
189b
189c
189d
190a
190b
191a
192a
193a
194a
195a
196a
196b
197a
197b
197c
198a
198b
199a
200a
200b
201a
202a
203a
204a
205a
206a
206b
207a
208a
209a
210a
211a
211b
212a
213a
213b
214a
215a
216a
216b
217a
217b
217c
217d
218a
219a
219b
220a
220b
221a
221b
221c
222a
223a
224a
225a
226a
227a
228a
229a
230a
230b
231a
232a
233a
233b
234a
235a
236a
237a
237b
237c
238a
238b
239a
240a
241a
242a
243a
244a
245a
245b
245c
245d
246a
247a
247b
248a
249a
250a
251a
252a
253a
254a
254b
254c
255a
255b
256a
257a
258a
259a);


sub _load_verbalization {
    my ($self) = @_;
    my $result = {};
    if ( defined($self->verbalization_file) ) {
        open(my $fh, '<', $self->verbalization_file);
        while (<$fh>) {
            my @line = split(' ', $_);
            if ($line[1]) {
                my $rule = {};
                $line[3] =~ s/\-\d+//;
                $rule->{'new_lemma'} = $line[3];
                if ($line[4]) {
                    print STDERR "4: " . $line[4] . "\n";
                    $rule->{'add_modifier'} = $line[4];
                    $line[5] =~ s/\-\d+//;
                    print STDERR "5: " . $line[5] . "\n";
                    $rule->{'add_lemma'} = $line[5];
                }
                $result->{$line[1]} = $rule;
            }
        }
    }
    return $result;
}

sub _load_rules {
    
    my ($self) = @_;
    
    if ( !defined($self->rules_file) ){
        log_fatal('\'rules_file\' must be defined!');
    }
    
    my $doc = Treex::Core::Document->new( { filename => $self->rules_file } );
    return $doc;
}


sub _build_source_selector {
    my ($self) = @_;
    return $self->selector;
}

sub _build_source_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->source_language && $self->selector eq $self->source_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

my %rules2ttrees;

sub process_document {
    my ( $self, $document ) = @_;

    # the forward links (from source to target nodes) must be kept so that coreference links are copied properly
    my %src2tgt;
    # mapping rule ids to corresponding tamr trees
    my $count = 0;
    foreach my $bundle ($self->rules->get_bundles()){
      my ($current_num) = $rules_ids[$count] =~ /(\d+)/;
      if (!$current_num){
        last;
      }
      my ($running_num) = $rules_ids[$count] =~ /(\d+)/;
      print STDERR "Current num $current_num\n";
      my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
      my $source_root = $source_zone->get_ttree;
      while ($rules_ids[$count] && ($current_num eq $running_num)) {
        print STDERR "Mapping rule " . ($count + 1) . " to id " . $rules_ids[$count] . "\n";
        $rules2ttrees{$rules_ids[$count]} = $source_root;
        $count++;
        ($running_num) = $rules_ids[$count] =~ /(\d+)/;
      }
    }

    foreach my $bundle ( $document->get_bundles() ) {
        print STDERR "Converting sentence ", $bundle->id(), "\n";
        $src2tgt{'varname_used'} = undef; # fresh namespace
        my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
        my $source_root = $source_zone->get_ttree;

        my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
        my $target_root = $target_zone->create_ttree( { overwrite => 1 } );
        
        copy_subtree( $source_root, $target_root, \%src2tgt, $self->verb_rules);
        $target_root->set_src_tnode($source_root);
    }
    # look for all nodes, marked for deletion
    foreach my $bundle ( $document->get_bundles() ) {
        print STDERR "Copying coref for ", $bundle->id(), "\n";
        my $target_zone = $bundle->get_zone( $self->language, $self->selector );
        my $target_root = $target_zone->get_ttree();
        foreach my $target_node ($target_root->get_descendants ) {
            if (defined $target_node->wild->{'special'} && $target_node->wild->{'special'}  eq 'Delete'){
                # move all its children to its parent
                my $parent_node = $target_node->get_parent();
                foreach my $child_node ($target_node->get_children){
                    $child_node->set_parent($parent_node);
                }
                print STDERR "Delete " . $target_node->t_lemma . "\n";
                #$target_node->remove();
            }
        }
    }

    # copying coreference links
    foreach my $bundle ( $document->get_bundles() ) {
        print STDERR "Copying coref for ", $bundle->id(), "\n";
        my $target_zone = $bundle->get_zone( $self->language, $self->selector );
        my $target_root = $target_zone->get_ttree();
        foreach my $t_node ( $target_root->get_descendants ) {
            my $src_tnode  = $t_node->src_tnode;
            next if !defined $src_tnode;
              # can happen for e.g. the generated polarity node
            my $coref_gram = $src_tnode->get_deref_attr('coref_gram.rf');
            my $coref_text = $src_tnode->get_deref_attr('coref_text.rf');
            my @nodelist = ();
            if ( defined $coref_gram ) {
                push @nodelist, map { $src2tgt{'nodemap'}->{$_} } @$coref_gram;
            }
            if ( defined $coref_text ) {
                push @nodelist, map { $src2tgt{'nodemap'}->{$_} } @$coref_text;
            }
            $t_node->set_deref_attr( 'coref_text.rf', \@nodelist )
              if 0< scalar(@nodelist);
        }
    }
 
}

sub copy_subtree {
    my ( $source_root, $target_root, $src2tgt, $verb_rules) = @_;

    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my $target_node = $target_root->create_child();

        $src2tgt->{'nodemap'}->{$source_node} = $target_node;

        # copying attributes
        # t_lemma gets assigned a unique variable name
        my $tlemma = $source_node->get_attr('t_lemma');

        # check verbalization dictionary
        if (defined $verb_rules->{$tlemma}->{'new_lemma'}){
           $tlemma = $verb_rules->{$tlemma}->{'new_lemma'};
        }

        my $varname = firstletter($tlemma);
        if (defined $src2tgt->{'varname_used'}->{$varname}) {
          $src2tgt->{'varname_used'}->{$varname}++;
          $varname .= $src2tgt->{'varname_used'}->{$varname};
        } else {
          $src2tgt->{'varname_used'}->{$varname} = 1;
        }
        $target_node->set_attr('t_lemma', $varname."/".$tlemma);

        my $source_tlemma = $source_node->get_attr('t_lemma');

        #add new nodes from verbalization rules
        if (defined $verb_rules->{$source_tlemma}->{'add_lemma'}){
            $varname = firstletter($verb_rules->{$source_tlemma}->{'add_lemma'});
            if (defined $src2tgt->{'varname_used'}->{$varname}) {
                $src2tgt->{'varname_used'}->{$varname}++;
                $varname .= $src2tgt->{'varname_used'}->{$varname};
            } else {
                $src2tgt->{'varname_used'}->{$varname} = 1;
            }
            print STDERR "Added node " . $verb_rules->{$source_tlemma}->{'add_lemma'} . " for $source_tlemma\n";
            # adding new node with appropriate modifier
            my $added_node = $target_node->create_child();
            $added_node->set_attr('t_lemma', $varname."/".$verb_rules->{$source_tlemma}->{'add_lemma'});
            $added_node->wild->{'modifier'} = $verb_rules->{$source_tlemma}->{'add_modifier'};
        }

        #Searching for specific rules to apply
        my $flag_found = 0;
	if ($source_node->wild->{'query_label'}) {
	  foreach my $query (keys %{$source_node->wild->{'query_label'}}) {
            # if we have an active rule, disabled for now, cause we don't have applied rule disambiguator
            if (1 || $active_rule_label ~~ @{$source_node->wild->{'query_label'}->{$query}}){
              if ($query =~ /^#?([^-]+)/) {
                print STDERR "Query $query \n";
                print STDERR "Active rule id $1\n";
                my $active_rule_id = $1;
                my $node_rule_id = ${$source_node->wild->{'query_label'}->{$query}}[0];
                # if node rule id is marked with "_DEL", remove the mark from node rule id and mark the node for deletion
                if ($node_rule_id =~ /_DEL/){
                  print STDERR "Fixing $node_rule_id ";
                  $node_rule_id = $node_rule_id =~ s/\_DEL//; 
                  print STDERR "with $node_rule_id\n";
                  $target_node->wild->{'special'} = 'Delete';
                }
                # fixing the "w_word_01" or "w_word" to "word"
                if ($node_rule_id =~ /_/) {
                  print STDERR "Strange node rule id $node_rule_id\n";
                  my @temp_array = split ('_', $node_rule_id);
                  if (defined $temp_array[1]) { 
                      $node_rule_id = $temp_array[1];
                      print STDERR "New node rule id $node_rule_id\n";
                  } 
                }
                print STDERR "Applying rule-id $node_rule_id\n";
                # searching tamr rule trees for found rule
                if (my $rule_tree = $rules2ttrees{$active_rule_id}) {
                  # searching for node with lemma corresponding to nodes rule-id
                  foreach my $rule_node ($rule_tree->get_descendants()){
                    # if we've found the node in tamr rule tree, which corresponds to our node
                    if ($rule_node->t_lemma =~ /$node_rule_id/i ) {
                      print STDERR "Rule node id $node_rule_id is found in $active_rule_id, in the node " . $rule_node->t_lemma . "\n";
                      $flag_found = 1;
                      # the logic is:
                      # if the source node has no modifier or "root" modifier, then copy modifier from rule node to target node and rehang it
                      # else if rule nodes' modifier is "root", then do nothing
                      # else output an error
                      if ((!$source_node->wild->{'modifier'} || $source_node->wild->{'modifier'} eq 'root')) {
                        # if rule node isn't root, copy modifier and rehang it
                        if ($rule_node->wild->{'modifier'} ne "root"){
                          $target_node->wild->{'modifier'} = $rule_node->wild->{'modifier'};
                          my $rule_node_parent = $rule_node->get_parent();
                          # look in the whole tree
                          foreach my $target_tree_node ($target_node->get_root()->get_descendants()) {
                            # for a node with the same rule $query and rule-id corresponding to rule node parents' lemma
                            if ($rule_node_parent->t_lemma =~ /{$target_tree_node->wild->{'query_label'}->{$query}}[0]/i) {
                              $target_node->set_parent($target_tree_node);
                            }
                          }
                        }
                      } else {
                        # warn of an error
                        if (($rule_node->wild->{'modifier'} ne "root")  && ($source_node->wild->{'modifier'} ne $rule_node->wild->{'modifier'})){
                          print "Node " . $source_node->id . " has 2 conflicting modifiers: " . $source_node->wild->{'modifier'} . " and " . $rule_node->wild->{'modifier'} . " from rule " . $query;
                        }
                      }
                    }
                  }
                  if (!$flag_found) {
                    print "Rule-id $node_rule_id wasn't found in $query\n";
                  }
                } else {
                  print "Rule $active_rule_id wasn't found. Original query is $query \n";
                }
              }
            }
          }
        }
        # if we didn't find any rule
	if (!$flag_found) {
          # applying default rule
          # the original functor serves as 
          $target_node->wild->{'modifier'} = make_default_modifier($source_node);

          $target_node->set_src_tnode($source_node);
          $target_node->set_t_lemma_origin('clone');

          # create polarity - for negated nodes
          my $neg = $source_node->get_attr('gram/negation');
          if (defined $neg && $neg eq "neg1") {
            # create AMR auxiliary node indicating negation
            my $negnode = $target_node->create_child();
            $negnode->set_attr('t_lemma', "-");
            $negnode->wild->{'modifier'} = "polarity";
          }
        }

        copy_subtree( $source_node, $target_node, $src2tgt, $verb_rules);
    }
}

sub make_default_modifier {
  # given a t-node, maps its functor to the AMR modifier using Zdenka's
  # heuristics
  my $node = shift;
  my $ftor = $node->get_attr('functor');

  # don't translate some functors
  return $ftor if $modifier_is_ftor{$ftor};

  if ($node->get_attr('is_member')) {
    # this should be an op1, op2, ...
    # process the whole coordination at once
    my $parent = $node->parent;
    if (!defined $node->wild->{'AMR_op_number'}) {
      # walk all members in the coord
      my $i = 1;
      foreach my $sibl ($parent->get_coap_members({direct_only=>1, ordered=>1})) {
        $sibl->wild->{'AMR_op_number'} = $i;
        $i++;
      }
    }
    my $opnr = $node->wild->{'AMR_op_number'};
    return "op".$opnr;
  }

  my $modif = $modifier_from_ftor{$ftor};
  return $modif if defined $modif; # use the default mapping

  # final options
  return "time" if $ftor =~ /^T/;
  return "ARGm";
}


sub firstletter {
  my $str = shift;
  $str = NFD( $str );   ##  decompose
  $str =~ s/\pM//g;         ##  strip combining characters
  $str =~ tr/ıł/il/;  ## other chars I spotted
  $str =~ s/[“”«»]/"/g; ## simplify quotes
  $str =~ s/[’]/'/g; ## simplify apostrophes
  $str =~ s/[—]/-/g; ## simplify dashes
  $str =~ s/±/+-/g; ## simplify plusminus
  # skip non-letters
  $str =~ s/^[^[:alpha:]]*//;
  return "X" if $str eq "";
  return lc(substr($str, 0, 1));
}


1;

=over

=item Treex::Block::T2TAMR::CopyTtree

This block copies tectogrammatical tree into another zone and 
Attributes 'a/lex.rf' and 'a/aux.rf' are not copied within the nodes.

=back

=cut

# Copyright 2014

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
