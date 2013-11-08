package Treex::Block::A2A::EN::RehangPPAttachment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
	my ($self, $node) = @_;
	
	if (($node->afun eq 'AuxP') && ($node->tag eq 'IN')) {
		if ($node->get_parent()) {
			my $p = $node->get_parent();
			while (!$p->is_root) {
				if ($p->tag =~ /^V/) {
					$node->set_parent($p);
					last;
				}
				else {
					if ($p->get_parent()) {
						$p = $p->get_parent();	
					}
					else {
						last;
					}					
				}
			}
		}
	}	
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::A2A::EN::RehangPPAttachment - Rehangs the PP to the nearest verb

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.