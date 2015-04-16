package Treex::Block::T2A::BG::MoveDefiniteness;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
	my ($self, $anode) = @_;
	
	my $definiteness = $anode->iset->definiteness();
	return if !defined $definiteness;
	
	if ($definiteness eq 'def'){
		my ($first_adjective) = grep {$_->is_adjective} $anode->get_children({preceding_only=>1});
		return if !$first_adjective;
		
		$first_adjective->iset->set_definiteness('def');
		$anode->iset->set_definiteness(undef);		
	}
	return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::BG::MoveDefiniteness

=head1 DESCRIPTION

TODO

=head1 AUTHORS 

Lubomir Zlatkov (lyubo@webmail.bultreebank.org)

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
