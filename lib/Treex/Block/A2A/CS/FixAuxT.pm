package Treex::Block::A2A::CS::FixAuxT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ( ( $dep->{form} eq 'se' || $dep->{form} eq 'si' ) && $d->{tag} =~ /^P/) {
       if ($g->{tag} =~ /^V/ || $g->{tag} =~ /^A[GC]/) {
           return;
       } #else: parent is not a verb => is an error
	    #log1
	    $self->logfix1($dep, "AuxT");
	    #move children under parent
	    my $parent = $dep->get_parent;
	    foreach my $child ($dep->get_children) {
            $child->set_parent($parent);
	    }
	    #remove alignment
    	if ($en_counterpart{$dep}) {
    	   $en_counterpart{$dep}->set_attr( 'alignment', undef );
    	}
	    #remove
	    $dep->remove;
	    #log2
	    $self->logfix2(undef);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixAuxT

Fixing reflexive tantum ("se", "si").

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
