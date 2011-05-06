package Treex::Block::A2A::CS::FixVerbAuxBeAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ($dep->afun eq 'AuxV' && $g->{tag} =~ /^Vf/ && $d->{tag} =~ /^VB/) {
	my $subject;
	foreach my $child ($gov->get_children()) {
	    $subject = $child if $child->afun eq 'Sb';
	}
	return if !$subject;
	my $sub_num = substr($subject->tag, 3, 1);
	if ($sub_num ne $d->{num}) {
	    $d->{tag} =~ s/^(...)./$1$sub_num/;

	    $self->logfix1($dep, "VerbAuxBeAgreement");
	    $self->regenerate_node($dep, $d->{tag});
	    $self->logfix2($dep);
	}
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixVerbAuxBeAgreement

Fixing agreement between verb and auxiliary 'to be'.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
