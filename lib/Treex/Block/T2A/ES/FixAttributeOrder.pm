package Treex::Block::T2A::ES::FixAttributeOrder;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

#### TODO: Exceptions


sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $parent = $tnode->get_parent;
    ### Most adjectives should be also reordered, need to distinguiss which of them
    #$tnode->gram_sempos
    if (( ($tnode->formeme || "" ) =~ /^n:de\+X/ or 
	  (($tnode->formeme || "" ) =~ /^adj:attr$/ and ($tnode->gram_sempos || "") !~ /^n.pron.indef|n.quant.def$/ )
	) and
	(( $parent->functor || "" ) !~ /^(CONJ|COORD)$/ ) and
	(( $parent->formeme || "" ) =~ /^n:/ ) and
	$tnode->precedes($parent)) {

	$tnode->shift_after_node($parent);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::ES::FixAttributeOrder

=head1 DESCRIPTION



=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA Group, University of the Basque Country (UPV/EHU)
