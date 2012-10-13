package Treex::Block::A2A::CS::FixPrepositionNounAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    #    if ( $gov->afun eq 'AuxP' && $dep->afun =~ /^(Atr)$/ && $g->{tag} =~ /^R/ && $d->{tag} =~ /^N/ && $g->{case} ne $d->{case} ) {
    if ( $gov->afun eq 'AuxP'
	 && $g->{tag} =~ /^R/
	 && $d->{tag} =~ /^[NA]/
	 && $g->{case} ne $d->{case}
	) {
	
	if ( $gov->ord < $dep->ord ) {
	    # preposition is before noun, that is good
	    
	    #    if ( $gov->afun eq 'AuxP' && $g->{tag} =~ /^R/ && $g->{case} ne $d->{case} ) {
	    my $doCorrect;
	    
	    #if there is an EN counterpart for $dep but its eparent is not a preposition,
	    #it means that the CS tree is probably incorrect
	    #and the $gov prep does not belong to this $dep at all
	    if ( $en_counterpart{$dep} ) {
		my ( $enDep, $enGov, $enD, $enG ) = $self->get_pair( $en_counterpart{$dep} );
		if ( $enGov and $enDep and $enGov->afun eq 'AuxP' ) {
		    $doCorrect = 1;    #en_counterpart's parent is also a prep
		}
		else {
		    $doCorrect = 0;    #en_counterpart's parent is not a prep
		}
	    }
	    else {
		$doCorrect = 1;        #no en_counterpart
	    }
	    if ($doCorrect) {
		
		my $case = $g->{case};
		$d->{tag} =~ s/^(....)./$1$case/;
		$d->{tag} = $self->try_switch_num( $dep->form, $dep->lemma, $d->{tag} );
		
		$self->logfix1( $dep, "PrepositionNounAgreement" );
		$self->regenerate_node( $dep, $d->{tag} );
		$self->logfix2($dep);
	    }    #else do not correct
	}
	else {
	    # preposition is AFTER the noun -> rehang
	    log_warn "TODO: The noun is hanging under an incorrect preposition!";
	}
    }

    return;
}

1;

=over

=item Treex::Block::A2A::CS::FixPrepositionNounAgreement

Fixing agreement between preposition and noun.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
