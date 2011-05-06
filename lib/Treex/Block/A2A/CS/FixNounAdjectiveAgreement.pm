package Treex::Block::A2A::CS::FixNounAdjectiveAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

    if ($dep->afun eq 'Atr' && $g->{tag} =~ /^N/ && $d->{tag} =~ /^A/ && $gov->ord > $dep->ord && ($g->{gen}.$g->{num}.$g->{case} ne $d->{gen}.$d->{num}.$d->{case})) {
	my $new_gnc = $g->{gen}.$g->{num}.$g->{case};
	$d->{tag} =~ s/^(..).../$1$new_gnc/;
	$self->logfix1($dep, "NounAdjectiveAgreement");
	$self->regenerate_node($dep, $d->{tag});
	$self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixNounAdjectiveAgreement

Fixing agreement between noun and adjective.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
