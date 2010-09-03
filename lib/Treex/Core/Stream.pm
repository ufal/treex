package Treex::Core::Stream;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;


has current_document => (is => 'rw',
                         writer => 'set_current_document',
                         reader => 'get_current_document',
                         trigger => sub {
                             my $self = shift;
                             $self->set_document_number(($self->get_document_number||0)+1);
#                             print "Document number: ".$self->get_document_number."\n";

                         },
                     );

has document_number => (is=>'rw',
                        default => 0,
                    );


__PACKAGE__->meta->make_immutable;

1;
