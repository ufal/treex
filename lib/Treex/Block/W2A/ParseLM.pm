package Treex::Block::W2A::ParseLM;
use Moose;
use Treex::Core::Common;
use Treex::Tool::LanguageModel::KenLM;
extends 'Treex::Core::Block';

my $LM;
my %scores;
my %indices;
my %indices_offset;
my $current_sentence_size = 0;
my @current_sentence      = ();
my $model                 = "/net/work/people/green/LanguageModels/en-pos.lm";
my @nodes;
my $root = 0;
my $root_node;
my $POPPED;
my @tag_sentence;
my $language;
has 'fold'     => ( is => 'ro', isa => 'Str' );
has 'language' => ( is => 'ro', isa => 'Str' );

sub BUILD {
  my ($self) = @_;
  $model =
  "/net/work/people/green/LanguageModels/" . $self->language . "-pos.lm";
  $language = $self->language;
  if ( !$LM ) {
    $LM = Treex::Tool::LanguageModel::KenLM->new(
    { language_model => $model } );
  }
  return;
}

sub process_atree {
  my ( $self, $root ) = @_;
  $root_node = $root;
  my @todo = $root->get_descendants( { ordered => 1 } );
  @nodes            = ();
  @current_sentence = @todo;
  my $sentence = "";
  my $tag      = "";
  $current_sentence_size = scalar @todo;
  
  # Delete old topology (so no cycles will be introduced during the parsing)
  foreach my $a_node (@current_sentence) {
    $a_node->set_parent($root_node);
  }
  
  foreach my $node (@todo) {
    push( @nodes, $node->tag );
  }
  @tag_sentence = @nodes;
  
  #set default indices
  set_indices();
  
  if ( $self->fold eq "left" ) {
  #  fold_sequences_furthest_left();
  fold_sequences_left();
  
  }
  elsif ( $self->fold eq "right" ) {
    #fold_sequences_furthest_right();
    fold_sequences_right();
  }
  
  if (   $current_sentence[ $current_sentence_size - 1 ]->tag eq "."
    or $current_sentence[ $current_sentence_size - 1 ]->tag eq ":"
    or $current_sentence[ $current_sentence_size - 1 ]->tag eq "IP"
    or $current_sentence[ $current_sentence_size - 1 ]->tag eq "Fp"
    or $current_sentence[ $current_sentence_size - 1 ]->tag eq "\$." )
  {
    $POPPED = "TRUE";
    
    pop @nodes;
  }
  else {
    
    #    print $current_sentence[$current_sentence_size-1]->tag;
    #    print "\n";
    $POPPED = "FALSE";
  }
  
  #Process by looking at the token that causes the least harm when removed
  #process_tree_min_harm( \@nodes );
  
  process_tree_adjacency( \@nodes );
  
  #print results
  # print_heads();
  save_tree();
  %indices        = ();
  %indices_offset = ();
  %scores         = ();
  
  return;
}

sub rank_segment {
  my $phrase = $_[0];
  my $value  = 0;
  if ( length($phrase) > 0 ) {
    $value = $LM->query($phrase);
  }
  $scores{$phrase} = $value;
  return $phrase;
}

sub set_indices {
  my $i = 0;
  while ( $i < $current_sentence_size + 1 ) {
    $indices_offset{$i} = $i;
    $i++;
  }
}

sub update_indices {
  my $index = $_[0];
  while ( $index < $current_sentence_size ) {
    $indices_offset{$index} = $indices_offset{ $index + 1 };
    $index++;
  }
  
}

sub populate_ngrams {
  my $sentence = $_[0];
  
  # print "$sentence\n";
  my @tokens = split " ", $sentence;
  my $size   = scalar @tokens;
  my $i      = 0;
  my @t;
  
  #left side
  while ( $i < $size ) {
    @t = @tokens;
    rank_segment( join( " ", splice( @t, 0, $i ) ) );
    $i++;
  }
  
  #right side
  my $j = 0;
  while ( $j < $size ) {
    @t = @tokens;
    rank_segment( join( " ", splice( @t, $j ) ) );
    $j++;
  }
  
  # whole sentence without token (hidden value)
    my $k = 0;
    while ( $k < $size ) {
      @t = @tokens;
      splice( @t, $k, 1 );
      rank_segment( join( " ", @t ) );
      $k++;
      
    }
    rank_segment($sentence);
}

sub process_tree_min_harm {
  my $t     = $_[0];
  my @terms = @{$t};
  
  populate_ngrams( join( " ", @terms ) );
  my $array_size = scalar @terms;
  my $counter    = 0;
  my @temp       = @terms;
  my $max_score  = -10000;
  my $max_index  = 0;
  while ( $counter < $array_size ) {
    my $tok = $terms[$counter];
    my $leftside = join( " ", splice( @temp, 0, $counter ) );
    @temp = @terms;
    my $rightside = join( " ", splice( @temp, $counter ) );
    @temp = @terms;
    splice( @temp, $counter, 1 );
    my $hidden         = join( " ", @temp );
    my $hidden_score   = $scores{$hidden};
    my $sentence_score = $scores{ join( " ", @terms ) };
    my $left_score     = $scores{$leftside};
    my $right_score    = $scores{$rightside};
    
    if ( $hidden_score > $max_score ) {
      $max_index = $counter;
      $max_score = $hidden_score;
    }
    $counter++;
    @temp = @terms;
  }
  
  #found the term that harms the sentence the least by removing
  #find the top bigram
  my $internal_loop    = 0;
  my $max_bigram       = -10000;
  my $max_bigram_index = $root;
  @temp = @terms;
  while ( $internal_loop < $array_size ) {
    
    # print "MAX INDEX: $max_index\n";
    if ( $internal_loop < $max_index ) {
      
      #check bigrams
      rank_segment( $temp[$internal_loop] . " " . $temp[$max_index] );
      
      if ( $scores{ $temp[$internal_loop] . " " . $temp[$max_index] } >=
	$max_bigram )
      {
	$max_bigram =
	$scores{ $temp[$internal_loop] . " " . $temp[$max_index] };
	$max_bigram_index = $internal_loop;
      }
    }
    elsif ( $internal_loop > $max_index ) {
      rank_segment( $temp[$max_index] . " " . $temp[$internal_loop] );
      if ( $scores{ $temp[$max_index] . " " . $temp[$internal_loop] } >
	$max_bigram )
      {
	$max_bigram =
	$scores{ $temp[$max_index] . " " . $temp[$internal_loop] };
	$max_bigram_index = $internal_loop;
      }
    }
    $internal_loop++;
  }
  if ( $indices_offset{$max_index} == $indices_offset{$max_bigram_index} ) {
    $indices{ $indices_offset{$max_index} } = -1;
    $indices{ $current_sentence_size - 1 } = $indices_offset{$max_index};
  }
  else {
    $indices{ $indices_offset{$max_index} } =
    $indices_offset{$max_bigram_index};
  }
  update_indices($max_index);
  splice( @temp, $max_index, 1 );
  
  if ( scalar @temp > 0 ) {
    process_tree_min_harm( \@temp );
  }
  
}

sub save_tree {
  foreach ( sort { $a <=> $b } keys(%indices) ) {
    
    #  print $_ ."->".$indices{$_}."\n";
    if ( $indices{$_} == -1 ) {
      $current_sentence[$_]->set_parent($root_node);
    }
    else {
      
      #print $current_sentence[$_]->tag."->".$current_sentence[$indices{$_}]->tag."\n";
      $current_sentence[$_]
      ->set_parent( $current_sentence[ $indices{$_} ] );
    }
  }
}

sub print_heads {
  foreach ( sort { $a <=> $b } keys(%indices) ) {
    print "Index:\t"
    . ( $_ + 1 )
    . "\tHead:\t"
    . ( $indices{$_} + 1 ) . "\t"
    . $current_sentence[$_]->tag;
    print "\n";
  }
  print "\n";
}

sub percent_change {
  my $orig = $_[0];
  my $new  = $_[1];
  if ( $orig > 0 ) {
    return ( ( $new - $orig ) / $orig ) * 100;
  }
  else {
    return ( ( $new - $orig ) / $orig ) * 100 * (-1);
  }
}

#Adjacency algorithm
sub process_tree_adjacency {
  my $t     = $_[0];
  my @terms = @{$t};
  
  populate_ngrams( join( " ", @terms ) );
  my $array_size = scalar @terms;
  my $counter    = 0;
  my @temp       = @terms;
  
  my $max_score = -100;
  my $max_index = 0;
  while ( $counter < $array_size ) {
    my $tok = $terms[$counter];
    my $leftside = join( " ", splice( @temp, 0, $counter ) );
    @temp = @terms;
    my $rightside = join( " ", splice( @temp, $counter ) );
    @temp = @terms;
    splice( @temp, $counter, 1 );
    my $hidden         = join( " ", @temp );
    my $hidden_score   = $scores{$hidden};
    my $sentence_score = $scores{ join( " ", @terms ) };
    my $left_score     = $scores{$leftside};
    my $right_score    = $scores{$rightside};
    
    #print "".($counter+1).":$tok: $hidden_score\t".percent_change($sentence_score,$hidden_score)."\n";
    if ( $hidden_score > $max_score ) {
      $max_index = $counter;
      $max_score = $hidden_score;
    }
    $counter++;
    @temp = @terms;
  }
  
  #found the term that harms the sentence the least by removing
  #find the top bigram
  my $internal_loop    = 0;
  my $max_bigram       = -100;
  my $max_bigram_index = $root;
  @temp = @terms;
  my $direction = "RIGHT";
  my $left      = "";
  my $right     = "";
  
  #If array size is 1, it is root
  if ( scalar @temp == 1 ) {
    $indices{ $indices_offset{$max_index} } = -1;
    
    #set punct
    if ( $POPPED eq "TRUE" ) {
      
      if ( $language eq "cs" ) {
	$indices{ $current_sentence_size - 1 } = -1;
    }
    else {
      $indices{ $current_sentence_size - 1 } =
      $indices_offset{$max_index};
    }
  }
  else {
    
    # print join (" ",@tag_sentence)."\tPunct NOT POPPED\n";
  }
  $direction = "ROOT";
  
  #remove punct
  #     if($current_sentence[$current_sentence_size-1]->tag eq "."){
      #       print "Punc\n";
      #       if($indices{$current_sentence_size-1}!=-1){
      #       $indices{$current_sentence_size-1}=$indices_offset{0};
      #       }
      #     }
      
}
else {
  
  #if Max Index is furthest right.
  if ( ( scalar @temp ) - 1 == $max_index ) {
    $direction = "LEFT";
  }
  else {
    
    #IF Max Inde is Furthest LEft
    if ( $max_index > 0 ) {
      
      #rank_whole_sentence($temp[$max_index-1]." ".$temp[$max_index]);
      rank_segment(
      $temp[$max_index] . " " . $temp[ $max_index - 1 ] );
      rank_segment(
      $temp[$max_index] . " " . $temp[ $max_index + 1 ] );
      $left =
      $scores{ $temp[$max_index] . " " . $temp[ $max_index - 1 ] };
      $right =
      $scores{ $temp[$max_index] . " " . $temp[ $max_index + 1 ] };
      if ( $left > $right ) {
	$direction = "LEFT";
      }
    }
    else {
      $direction = "RIGHT";
    }
  }
}

if ( $direction eq "RIGHT" ) {
  $indices{ $indices_offset{$max_index} } =
  $indices_offset{ $max_index + 1 };
}
elsif ( $direction eq "LEFT" ) {
  $indices{ $indices_offset{$max_index} } =
  $indices_offset{ $max_index - 1 };
}

splice( @temp, $max_index, 1 );
update_indices($max_index);
if ( scalar @temp > 0 ) {
  process_tree_adjacency( \@temp );
}

}

sub fold_sequences {
  my $i         = 0;
  my $fold_size = $current_sentence_size;
  while ( $i < $fold_size - 1 ) {
    
    #      print $tokens[$i]."->".$tokens[$i+1]."\n";
    if ( $nodes[$i] eq $nodes[ $i + 1 ] ) {
      $indices{ $indices_offset{$i} } = $indices_offset{ $i + 1 };
      
      update_indices($i);
      splice( @nodes, $i, 1 );
      $fold_size--;
    }
    $i++;
  }
}

sub fold_sequences_furthest_right {
  my $i         = 0;
  my $fold_size = $current_sentence_size;
  while ( $i < $fold_size - 1 ) {
    
    #  print "$i\t".($fold_size-1)."\n";
    if ( $nodes[$i] eq $nodes[ $i + 1 ] ) {
      my $j = $i + 1;
      while ( $j < $current_sentence_size and $nodes[$i] eq $nodes[$j] ) {
	
	#print "J=$j\t$nodes[$i]\t$nodes[$j]\n";
	$j++;
      }
      $j--;
      
      #print "i=$i\tj=$j\n";
      #print "i=$indices_offset{$i}\tj=$indices_offset{$j}\n";
      $indices{ $indices_offset{$i} } = $indices_offset{$j};
      update_indices($i);
      splice( @nodes, $i, 1 );
      $fold_size--;
    }
    $i++;
  }
}
sub fold_sequences_right {
  my $i         = 0;
  my $fold_size = $current_sentence_size;
  while ( $i < $fold_size - 1 ) {
    
    #  print "$i\t".($fold_size-1)."\n";
    if ( $nodes[$i] eq $nodes[ $i + 1 ] ) {
      my $j = $i + 1;
       $indices{ $indices_offset{$i} } = $indices_offset{$j};
      update_indices($i);
      splice( @nodes, $i, 1 );
      $fold_size--;
    }
    $i++;
  }
}
sub fold_sequences_furthest_left {
  my $i         = $current_sentence_size - 1;
  my $fold_size = $current_sentence_size;
  while ( $i > 0 ) {
    
    #print "$i\t".($fold_size-1)."\n";
    if ( $nodes[$i] eq $nodes[ $i - 1 ] ) {
      my $j = $i - 1;
      while ( $j > -1 and $nodes[$i] eq $nodes[$j] ) {
	
	#print "J=$j\t$nodes[$i]\t$nodes[$j]\n";
	$j--;
      }
      $j++;
      
      #print "i=$i\tj=$j\n";
      #print "i=$indices_offset{$i}\tj=$indices_offset{$j}\n";
      $indices{ $indices_offset{$i} } = $indices_offset{$j};
      update_indices($i);
      splice( @nodes, $i, 1 );
      $fold_size--;
    }
    $i--;
  }
}
sub fold_sequences_left {
  my $i         = $current_sentence_size - 1;
  my $fold_size = $current_sentence_size;
  while ( $i > 0 ) {
    
    #print "$i\t".($fold_size-1)."\n";
    if ( $nodes[$i] eq $nodes[ $i - 1 ] ) {
      my $j = $i - 1;
      
      #print "i=$i\tj=$j\n";
      #print "i=$indices_offset{$i}\tj=$indices_offset{$j}\n";
      $indices{ $indices_offset{$i} } = $indices_offset{$j};
      update_indices($i);
      splice( @nodes, $i, 1 );
      $fold_size--;
    }
    $i--;
  }
}
1;

__END__
