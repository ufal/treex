package Treex::Block::A2A::TrainingData;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';
has 'trees' => ( is => 'rw', isa => 'Str', required => 1 );
has 'language' => ( is => 'rw', isa => 'Str', default =>'en');

my $do_once="false";
sub BUILD {
  my ($self) = @_;
  
  return;  
}


#Weight edge depending on the POS
sub process_tree {
  my ( $root) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  my $i =0;
  foreach my $node (@todo) {
    print $node->selector . "\t" . $node->tag . "\t". find_bucket($i,scalar @todo). "\t". scalar @todo . "\n";
  $i++;
  }  
}

#return quartile (1=0.. .25    2 = .25 ... .5)
sub find_bucket{
my ($index,$length) = @_;

my $percent = $index/$length;

if($percent < .25){
return 1;
}
elsif ($percent <.5){
return 2;
}
elsif ($percent <.75){
  return 3;
}
return 4;
}
sub process_bundle {
  my ( $self, $bundle ) = @_;
  if($do_once eq "false"){
  my @zones = $bundle->get_all_zones();
  my %use_tree = ();
  my @trees_to_process = split( "~", $self->trees );
  foreach my $tree (@trees_to_process) {
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  
  foreach my $zone (@zones) {
    if($zone->get_atree()->language eq $self->language){
       if (exists $use_tree{ $zone->get_atree()->selector } ) {
	process_tree( $zone->get_atree());
	   
     }
  }
  }
  #$do_once="true";
  }
}




1;
__END__

=pod

=head1 NAME

Treex::Block::A2A::TrainingData

=head1 DESCRIPTION

Create training data from multiple A-trees to be used for a classifier


=head1 AUTHORS

Nathan Green
