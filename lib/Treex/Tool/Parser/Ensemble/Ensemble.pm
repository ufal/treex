package Treex::Tool::Parser::Ensemble::Ensemble;

use Moose;

has edges => (
isa      => 'HashRef',
	     is       => 'rw',
	     required => 1,
	     default  => 'null'
	     );
		      
	      sub BUILD {
		my ( $self, $params ) = @_;
		print self->edges;
	      }
	      
	      sub add_child {
		my ( $self, $child ) = @_;
	#	push @{ $self->children }, $child;
	      }
	      
	      sub get_type {
		my ($self) = @_;
	#	return $self->{term};
	      }
	      
	      1;
	      __END__
	      
	      