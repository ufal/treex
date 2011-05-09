package Treex::Block::A2A::CS::FixSubjectPredicateAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ($en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb' && $g->{tag} =~ /^VB/ && $d->{tag} =~ /^[NP][^D]/ && ( $d->{case} eq '1') && $g->{num} ne $d->{num}) {
    my ($enDep, $enGov, $enD, $enG) = $self->get_pair($en_counterpart{$dep});
    if ($en_counterpart{$gov} && $enGov && $en_counterpart{$gov}->id ne $enGov->id) {
        return;
    }
    
	my $num = $d->{num};
	$g->{tag} =~ s/^(...)./$1$num/;
	if ($d->{tag} =~ /^.......([123])/) {
	    my $person = $1;
	    $g->{tag} =~ s/^(.......)./$1$person/;
	}
	$self->logfix1($dep, "SubjectPredicateAgreement");
	$self->regenerate_node($gov, $g->{tag});
	$self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixSubjectPredicateAgreement

Fixing agreement between subject and predicate.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
