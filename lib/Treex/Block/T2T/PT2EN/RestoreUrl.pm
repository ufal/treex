package Treex::Block::T2T::PT2EN::RestoreUrl;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $t_node ) = @_;

    my $src_t_node = $t_node->src_tnode;

    if ($src_t_node and $src_t_node->t_lemma =~ /^\@/) {
    	my $src_lex_anode = $src_t_node->get_lex_anode;
    	if ($src_lex_anode) {
    		$t_node->set_t_lemma($src_lex_anode->form);	
    		$t_node->set_formeme('x');
    	}
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PT2EN::RestoreUrl

=head1 DESCRIPTION

Fix the 'there is/are'

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

