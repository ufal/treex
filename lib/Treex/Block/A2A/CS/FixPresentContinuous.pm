package Treex::Block::A2A::CS::FixPresentContinuous;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ($dep->{lemma} eq 'být' && $d->{tag} =~ /^VB/ && $g->{tag} =~ /^VB/ && $en_counterpart{$gov} && $en_counterpart{$gov}->{form} =~ /ing$/) {
	my $doCorrect;
	if ($en_counterpart{$dep}) {
	    my ($enDep, $enGov, $enD, $enG) = $self->get_pair($en_counterpart{$dep}
		);
	    if ($enGov and $enDep and $enGov->{form} =~ /ing$/) {
		$doCorrect = 1;
	    } else {
		$doCorrect = 0;
	    }
	} else {
	    $doCorrect = 1;
	}
	if ($doCorrect) {
	    #log1
	    $self->logfix1($dep, "PresentContinuous");
	    #set gov's tag to dep's tag (preserve negation)
	    my $negation;
	    if( substr ($g->{tag}, 10, 1) eq 'N' or substr ($d->{tag}, 10, 1) eq 'N' ) {
		$negation = 'N';
	    } else {
		$negation = 'A';
	    }
	    my $tag = substr ($d->{tag}, 0, 10) . $negation . substr ($d->{tag}, 11);
	    $self->regenerate_node($gov, $tag);
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
	    $self->logfix2(($parent->get_children)[0]); #makes at least a little sense
	}
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixPresentContinuous

Fixing Present Continuous ("is working" translated as "je pracuje" and similar).

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
