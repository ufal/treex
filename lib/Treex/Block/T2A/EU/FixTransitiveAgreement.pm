package Treex::Block::T2A::EU::FixTransitiveAgreement;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();
    
    return if ((not $anode) || ($anode->lemma ne "ukan" && $anode->lemma ne "izan"));

    $anode->iset->set_verbtype("aux");
    
    if ($anode->lemma eq "ukan" && 
	(($anode->iset->absperson || "") eq ""
	 || ($anode->iset->absnumber || "") eq "")) {

	$anode->iset->set_absperson("3");
	$anode->iset->set_absnumber("sing");

	### erg
	my ($child) = grep {($_->formeme || "") =~ /(n|a):\[abs\]/} $tnode->get_children();
	if ($child) {
	    my $formeme=($child->formeme || "");
	    $formeme =~ s/\[abs\]/[erg]/;
	    $child->set_formeme($formeme);
	}
    }

    if (($anode->lemma eq "izan") &&
	(($anode->iset->absperson || "") ne ""
	 || ($anode->iset->absnumber || "") ne "")) {

	$anode->iset->set_absperson("");
	$anode->iset->set_absnumber("");

        ### abs
	my ($child) = grep {($_->formeme || "") =~ /(n|a):\[erg\]/} $tnode->get_children();
	if ($child) {
	    my $formeme=($child->formeme || "");
	    $formeme =~ s/\[erg\]/[abs]/;
	    $child->set_formeme($formeme);
	}
    }
    
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::FixTransitiveAgreement

=head1 DESCRIPTION

Fix transitive agreement, went verb tense need for 

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
