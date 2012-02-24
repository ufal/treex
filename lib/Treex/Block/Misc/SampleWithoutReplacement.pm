package Treex::Block::Misc::SampleWithoutReplacement;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'test_percentage'     => ( is => 'rw', isa => 'Int', default  => 10 );
has 'tune_percentage'     => ( is => 'rw', isa => 'Int', default  => 10 );
has 'train_percentage'     => ( is => 'rw', isa => 'Int', default  => 80 );

my $train_size=0;
my $test_size=0;
my $tune_size=0;
my $train_count=0;
my $test_count=0;
my $tune_count=0;
my $test_range;
my $tune_range;
my $total_size;
my $main_zone;
sub BUILD {
  my ($self) = @_;
  $test_range=$self->test_percentage;
  $tune_range=$test_range+$self->tune_percentage;
  return;
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  

  
  my $tree_root = $bundle->get_tree( $self->language, 'a');
  $main_zone=$bundle->get_zone($self->language);
  $total_size= scalar ($bundle->get_document()->get_bundles());
  $train_size=$total_size*$self->train_percentage/100;
  $test_size=$total_size*$self->test_percentage/100;
  $tune_size=$total_size*$self->tune_percentage/100;

 write_sentence($self,$bundle);
    
 
}

sub write_sentence{
  my ( $self, $bundle ) = @_;
  my $random_number = int(rand($total_size));
  
  if($random_number<$test_range and $test_count<$test_size){
    my $zone = $main_zone->copy("test");
    $bundle->create_tree($self->language ,'a', "tune" );
    $bundle->create_tree($self->language ,'a', "train" );
    $test_count++;
  }
  elsif($random_number<$tune_range and $tune_count<$tune_size){
    my $zone = $main_zone->copy("tune");
    $bundle->create_tree($self->language ,'a', "test" );
    $bundle->create_tree($self->language ,'a', "train" );
    $tune_count++;
  }
  elsif ($train_count<$train_size){
    my $zone = $main_zone->copy("train");
    $bundle->create_tree($self->language ,'a', "tune" );
    $bundle->create_tree($self->language ,'a', "test" );
    $train_count++;
  }
  else{
  write_sentence($self,$bundle);
  }
  
  
}
1;

=head1 NAME

Treex::Block::Misc::Sample;

=head1 DESCRIPTION

Randomle sample sentences into training, tuning, and test sets

=head1 AUTHOR

Nathan Green

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
