package Treex::Block::W2A::TA::SetAfun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_atree {
    my ( $self, $a_root ) = @_;    
	process_subtree($a_root);
}

sub process_subtree {
	my ($node) = @_;
	
	# initial labeling	
    foreach my $c ( $node->get_children( { ordered => 1 } ) ) {
    	if ($c) {
			$c->set_afun(get_afun($c));
			process_subtree($c);    		
    	}
    }
    
    
}


sub get_afun {
	my ($node) = @_;
	
	my $p = $node->get_parent();
	my $gp = $p->get_parent();
	
	# assign afun to nodes that can be easily determined by POS alone

	# punctuations 
	# AuxX, AuxG, AuxK
	return 'AuxX' if $node->form eq ',';
	
	if ($p == $node->root) {
		return 'AuxK' if $node->form =~ /\p{IsP}/;		
	}
	else {
		return 'AuxG' if $node->form =~ /\p{IsP}/;
	}
	
	# Coord
	return 'Coord' if $node->form eq 'மற்றும்';

	# AuxP
	return 'AuxP' if $node->tag =~ /^PP/;
	
	# AuxZ
	# 
	if (($node->form =~ /^(மட்டு|\N{U+0BA4}\N{U+0BBE}\N{U+0BA9})/) && ($node->tag =~ /^Tg/)) {
		return 'AuxZ';
	}
	
	# Adv
	return 'Adv' if ($node->tag =~ /^AA/);
	
	# AuxC
	return 'AuxC' if ($node->form eq 'என்று');
	
	
	
	# 1. Pred	
	if ($node->get_root() == $p) {
		return 'Pred' if $node->tag =~ /^V/;
	}
	

	
	# 2. Sb
	if ($p != $node->get_root()) {
		if (($p->afun eq 'Pred') || ($p->tag =~ /^V/)) {
			return 'Sb' if $node->tag =~ /^(N...N|RpASN)/;
			return 'Sb' if $node->tag =~ /^(VzN.N)/;
			return 'Sb' if $node->tag =~ /^(QQ..N)/;
		}
		# TODO: try subject first, this can also be an object 
		if ($p->form =~ /^என்பது/) {
			return 'Sb' if $node->tag =~ /^V/;
		}						
	}
	
	# 3. Obj
	if ($p != $node->get_root()) {
		if (($p->afun eq 'Pred') || ($p->tag =~ /^V/)) {
			return 'Obj' if $node->tag =~ /^([NR]...[AD])/;
		}
	}
	
	# 4. Adv
	# postpositional phrases under verbs should be marked with 'Adv'
	if (($p != $node->get_root()) && ($gp != $node->get_root())) {
		if (($p->afun eq 'AuxP') && ($gp->tag =~ /^V/)) {
			return 'Adv';
		}
	}
	if ($p != $node->get_root()) {
		# verbal participles attaching to verbs
		if (($node->tag =~ /^Vt/) && ($p->tag =~ /^V/)) {
			return 'Adv';
		}	
		# locatives 
		if (($node->tag =~ /^(N...L)/) && ($p->tag =~ /^V/)) {
			return 'Adv';
		}	
		# parent is AuxC
		return 'Adv' if $p->afun eq 'AuxC';
		
		# sociative
		if (($p->afun eq 'Pred') || ($p->tag =~ /^V/)) {
			return 'Adv' if $node->tag =~ /^([NRQ]...S)/;
		}		
		# lower level verbs get 'Adv' if the parent is also a verb
		if ($p->tag =~ /^V[rR]/) {
			return 'Adv' if $node->tag =~ /^V/;
		}		
	}
	
	# 5. Atr
	if ( ($node->tag =~ /((^DD)|(^NO)|(^JJ)|(^N...[NG])|(^U[noc])|(^Vd))/) ) {
		return 'Atr';
	}	
	
	if (($p != $node->get_root()) && ($node->tag =~ /^N/) && ($p->tag =~ /^N/)) {
		return 'Atr';
	}
		
	return 'NR';
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::SetAfun - Sets afun attribute

=head1 DESCRIPTION

For reasonable accuracy on setting afun attribute, the a-tree must have been already tagged and structurally annotated. 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.