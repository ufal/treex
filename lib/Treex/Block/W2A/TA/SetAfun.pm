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
    foreach my $c ( $node->get_children( { ordered => 1 } ) ) {
    	if ($c) {
			$c->set_afun(get_afun($c));
			process_subtree($c);    		
    	}
    }
}


sub get_afun {
	my ($node) = @_;
	
	# assign afun to nodes that can be easily determined by POS alone
	# AuxP
	return 'AuxP' if $node->tag =~ /^PP/;
	
	# AuxZ
	# 
	if (($node->form =~ /^(மட்டு|\N{U+0BA4}\N{U+0BBE}\N{U+0BA9})/) && ($node->tag =~ /^Tg/)) {
		return 'AuxZ';
	}
	
	
	
	# 1. Pred
	if ($node->get_root() == $node->get_parent()) {
		return 'Pred' if $node->tag =~ /^V/;
	}
	
	# 2. Sb
	if ($node->get_parent() != $node->get_root()) {
		my $p = $node->get_parent();
		if ($p->afun eq 'Pred') {
			return 'Sb' if $node->tag =~ /^(N...N|RpASN)/;
		}
	}
	
	# 3. Obj
	if ($node->get_parent() != $node->get_root()) {
		my $p = $node->get_parent();
		if ($p->afun eq 'Pred') {
			return 'Obj' if $node->tag =~ /^(N...A|RpASA)/;
		}
	}
	
	# 4. Adv

		
	return 'Atr';
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