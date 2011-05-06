package Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ($en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb' && $g->{tag} =~ /^Vp/ && $d->{tag} =~ /^[NP]/ && $dep->form !~ /^[Tt]o/ && ($g->{gen}.$g->{num} ne $self->gn2pp($d->{gen}.$d->{num}))) {
	my $new_gn = $self->gn2pp($d->{gen}.$d->{num});
	$g->{tag} =~ s/^(..)../$1$new_gn/;

	$self->logfix1($dep, "SubjectPastParticipleAgreement");
	$self->regenerate_node($gov, $g->{tag});
	$self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement

Fixing agreement between subject and past participle.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
