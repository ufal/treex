package Treex::Block::Misc::SampleWithoutReplacement;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'test_percentage'     => ( is => 'rw', isa => 'Int', default  => 10 );
has 'tune_percentage'     => ( is => 'rw', isa => 'Int', default  => 10 );
has 'train_percentage'     => ( is => 'rw', isa => 'Int', default  => 80 );
sub BUILD {
  my ($self) = @_;
  
  return;
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  
  my $test_range=$self->test_percentage;
  my $tune_range=$test_range+$self->tune_percentage;
  
  my $tree_root = $bundle->get_tree( $self->language, 'a');
  my $main_zone=$bundle->get_zone($self->language);
  my $total_size= scalar ($bundle->get_document()->get_bundles());
  my $random_number = int(rand($total_size));
    
  if($random_number<$test_range){
  my $zone = $main_zone->copy("test");
  $bundle->create_tree($self->language ,'a', "tune" );
  $bundle->create_tree($self->language ,'a', "train" );
  }
  elsif($random_number<$tune_range){
    my $zone = $main_zone->copy("tune");
    $bundle->create_tree($self->language ,'a', "test" );
    $bundle->create_tree($self->language ,'a', "train" );
  }
  else{
    my $zone = $main_zone->copy("train");
    $bundle->create_tree($self->language ,'a', "tune" );
    $bundle->create_tree($self->language ,'a', "test" );
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
