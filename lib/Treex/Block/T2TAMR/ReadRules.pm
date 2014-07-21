package Treex::Block::T2TAMR::ReadRules;

use Moose;
use Treex::Core::Common;
use Unicode::Normalize;


use feature qw(switch);
use File::Slurp;

extends 'Treex::Core::Block';

has 'rules_file' => ( isa => 'Maybe[Str]', is => 'ro' );

has 'lexicalization_dir' => ( isa => 'Maybe[Str]', is => 'ro' );

sub open_rules {
    my $doc = Treex::Core::Document->new;
    my $rules_file = shift;
    my $h;
    open($h, $rules_file);
    my $currentState = 'Void';
    my $bundle = $doc->create_bundle;
    my $zone = $bundle->create_zone('en', 'tamrRules');
    my $tree = $zone->create_ttree();
    my $text = '';
    while (my $line = <$h>) {
        my $firstchar = substr( $line, 0, 1 );
        given ($firstchar) {
            when ('*'){
              if ($currentState eq 'AMR'){
                  add_amr($tree, $text);
                  $bundle = $doc->create_bundle;
                  $zone = $bundle->create_zone('en', 'tamrRules');
                  $tree = $zone->create_ttree();
              }
              $currentState = 'Void';
            }
            when ('#'){
                my $secondchar = substr( $line, 1, 1 );
                if ($secondchar ne '#'){
                    $currentState = 'New query';
                    $line =~ s/^#//;
                    $text = $line;
                }
            }
            when ('('){
                if ($currentState eq 'PMLTQ rule'){
                    $currentState = 'AMR';
                    $text = $line;
                } else {
                    $text .= $line;
                }
            }
            default {
                given ($currentState) {
                    when ('AMR'){
                        $text .= $line;
                    }
                    when ('New query'){
                        # Here we will probably add some handler for different lexicalization dictionaries. 
                        # I think, that we'll just search for some {{DICTIONARY_FILENAME}} mask and add that filename to this same hash with some key
                        $tree->wild->{'pmltq-rules'}->{$text}->{'query_text'} = $line;
                        $currentState = 'PMLTQ rule';
                    }
                }
            }
        }
    }
    close $h;
    return $doc;
}

sub add_amr{
    my ($tree, $text) = @_;
    $text =~ s/[\n|\s]+/ /g;
    my @chars = split ('', $text);


    my $state = 'Void';
    my $value = '';
    my $lemma = '';
    my $word = '';
    my $modifier = '';
    my $param = '';
    my %param2id;
    my $ord = 0;
    my $brackets_match = 0;
    my $currentNode;
    foreach my $arg (@chars) {
       given($arg) {
           when ('(') {
               if ($state eq 'Void') {
                   undef %param2id;
                   $currentNode = $tree->create_child({ord => $ord});
                   $currentNode->wild->{modifier} = 'root';
                   $ord++;
               }
               $state = 'Param';
               $value = '';
               $brackets_match++;
           }
    
           when('/') {
               if ($state eq 'Param' && $value) {
                   $param = $value;
                   $state = 'Word';
               }
               $value = '';
           }
    
           when(':') {
               if ($state eq 'Word' && $value) {
                   $lemma = '';
                   $word = $value;
                   if ($param) {
                       $lemma = $param;
                   }
                   if ($lemma) {
                       $lemma .= '/' . $word;
                   } else {
                       $lemma = $word;
                   }
                   if ($lemma) {
                       $currentNode->set_attr('t_lemma', $lemma);
                   }
                   if ($param) {
                       if (exists($param2id{$param})) {
                           $currentNode->add_coref_text_nodes($currentNode->get_document()->get_node_by_id($param2id{$param}));
                       } else {
                           $param2id{$param} = $currentNode->get_attr('id');
                       }
                   }
                   $param = '';
                   $word = '';
                   $value = '';
               }
               if ($state eq 'Param' && $value) {
                   $param = $value;
                   if ($param) {
                       $currentNode->set_attr('t_lemma', $param);
                   }
                   if (exists($param2id{$param})) {
                       $currentNode->add_coref_text_nodes($currentNode->get_document()->get_node_by_id($param2id{$param}));
                   } else {
                       $param2id{$param} = $currentNode->get_attr('id');
                   }
                   $currentNode = $currentNode->get_parent();
                   $param = '';
                   $word = '';
                   $value = '';
               }
               $state = 'Modifier';
           }
           when(' ') {
               if ($state eq 'Modifier' && $value) {
                   $modifier = $value;
                   my $newNode = $currentNode->create_child({ord => $ord});
                   $ord++;
                   $currentNode = $newNode;
                   if ($modifier) {
                       $currentNode->wild->{modifier} = $modifier;
                       $modifier = '';
                   }
                   $value = '';
                   $state = 'Param';
               }
           }
    
           when('"') {
               if ($state eq 'Word' && $value) {
                   $currentNode->{t_lemma} = $value;
                   $value = '';
                   $currentNode = $currentNode->get_parent();
               }
               if ($state eq 'Param') {
                   $state = 'Word';
               }
          }
    
          when(')') {
              $lemma = '';
              if ($state eq 'Param') {
                 $param = $value;
              }
              if ($state eq 'Word') {
                  $word = $value;
              }
              $lemma = $param;
              if ($word) {
                  $lemma .= ($lemma?'/':'') . $word;
              }
              if ($lemma) {
                  $currentNode->set_attr('t_lemma', $lemma);
              }
              if ($param) {
                  if (exists($param2id{$param})) {
                      $currentNode->add_coref_text_nodes($currentNode->get_document()->get_node_by_id($param2id{$param}));
                  } else {
                      $param2id{$param} = $currentNode->get_attr('id');
                  }
              }

              $currentNode = $currentNode->get_parent();
              $value = '';
              $word = '';
              $param = '';
              $brackets_match--;
              if ($brackets_match eq 0) {
                  $state = 'Void';
                  $ord = 0;
              }
          }
    
           default {
              $value .= $arg;
          }
       }
    }
  return;
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
