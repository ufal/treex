package Treex::Block::Util::Eval;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has 'foreach' => (
    is=>'ro',
    required => 1,
    );

has 'code' => (
    is => 'ro',
    required => 1,
    );
    


sub BUILD {
    my ($self) = @_;

#    print "CODE ".$self->code."\n";

    if ($self->foreach !~ /^(document|bundle|zone|[atnp](tree|node))$/) {
	log_fatal "Unacceptable value of the 'foreach' argument: ".$self->foreach;
    }

    my $processing_method = "sub process_".$self->foreach." {\nmy (\$self) = \@_;\n ".$self->code."\n}\n";

    eval $processing_method;

}



1;

=over

=item Treex::Block::Devel::Eval

Run-time creation of blocks with proces_[foreach] method
with code [code] inside. $self will be filled according to the type of 
[foreach]. ??? blee, better formulation needed


PARAMETERS:
    foreach
    code

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
