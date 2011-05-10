package Treex::Block::A2A::CS::FixSubject;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ($self, $dep, $gov, $d, $g, $en_hash) = @_;
    my %en_counterpart = %$en_hash;

#    if ($en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb' && $d->{case} ne '1') {
#    if ($dep->afun eq 'Sb' && $d->{case} ne '1') {
#    if ($dep->afun eq 'Sb' && $d->{case} ne '1' && $dep->ord < $gov->ord) {
    if ($dep->afun eq 'Sb' && $d->{case} ne '1' && $d->{case} ne '-' && $en_counterpart{$dep} && $en_counterpart{$dep}->afun eq 'Sb') {
	
	my $case = '1';
	$d->{tag} =~ s/^(....)./$1$case/;
    
    if ($d->{num} eq 'S') { # maybe correct form, only incorrectly tagged
        my $num='P';
    	my $new_tag = $d->{tag}; #do not change $d->{tag}
    	$new_tag =~ s/^(...)./$1$num/;
    	my $old_form = $dep->form;
        my $new_form = $self->get_form( $dep->lemma, $new_tag );
        if ( lc($old_form) eq lc($new_form) ) {
        	$d->{tag} =~ s/^(...)./$1$num/; #error in number, not in form
        } #else change only case
    } #else change only case
    
    $self->logfix1($dep, "Subject");
	$self->regenerate_node($dep, $d->{tag});
	$self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixSubject

Fixing Subject case and number.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
