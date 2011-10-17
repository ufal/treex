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
my $model                 = "/net/work/people/green/LanguageModels/pos.lm";
my @nodes;
my $root = 0;

sub BUILD {
  my ($self) = @_;
  if ( !$LM ) {
    $LM = Treex::Tool::LanguageModel::KenLM->new(
    { language_model => $model } );
  }
  return;
}

sub process_atree {
  my ( $self, $root ) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  @nodes            = ();
  @current_sentence = @todo;
  my $sentence = "";
  my $tag      = "";
  $current_sentence_size = scalar @todo;
  foreach my $node (@todo) {
    push( @nodes, $node->tag );
  }
  
  #set default indices
  set_indices();
  
  #remove punct
  pop @nodes;
  
  #Process by looking at the token that causes the least harm when removed
  process_tree_min_harm( \@nodes );
  
  #print results
  print_heads();
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
  $indices{ $indices_offset{$max_index} } =
  $indices_offset{$max_bigram_index};
  if ( $indices_offset{$max_index} == $indices_offset{$max_bigram_index} ) {
    $indices{ $indices_offset{$max_index} } = -1;
    $indices{ $current_sentence_size - 1 } = $indices_offset{$max_index};
  }
  update_indices($max_index);
  splice( @temp, $max_index, 1 );
  
  if ( scalar @temp > 0 ) {
    process_tree_min_harm( \@temp );
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

1;

__END__
