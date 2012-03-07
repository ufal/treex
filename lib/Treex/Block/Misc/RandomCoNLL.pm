package Treex::Block::Misc::RandomCoNLL;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'sentences'     => ( is => 'rw', isa => 'Int', default  => 10 );


my $total_size;
my $main_zone;
my $count=0;
my @bundles;
my $total_processed=0;
my $first_time="true";
sub BUILD {
  my ($self) = @_;
  return;
}

sub process_document{
  my ($self, $document ) = @_;
  
  @bundles=$document->get_bundles();
  $total_size= scalar @bundles;
  if($first_time eq "false"){
    remove_trees($self);
  }
  else{
  $first_time="false";
  }
  my $random_number=0;
  while ($count<($self->sentences)){
    $random_number=int(rand(scalar @bundles));
    my $b=$bundles[$random_number];
    $main_zone=$b->get_zone($self->language);
    $main_zone->copy("random");
    #remove from choices
    splice(@bundles, $random_number, 1);
    $count++;
  }
  
  #add blank tree in all other bundles
  foreach my $blank (@bundles){
    $blank->create_tree($self->language ,'a', "random" );
  }
  
}

sub remove_trees{
my ($self)=@_;  
foreach my $b (@bundles){
  $b->remove_zone($self->language,"random");
}
}

1;

=head1 NAME

Treex::Block::Misc::Sample;

=head1 DESCRIPTION

Select a set of sentences 

=head1 AUTHOR

Nathan Green

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
