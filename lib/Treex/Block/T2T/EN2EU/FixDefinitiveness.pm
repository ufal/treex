package Treex::Block::T2T::EN2EU::FixDefinitiveness;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $src_t_node = $t_node->src_tnode;

    my $lex_anode = $src_t_node->get_lex_anode() if ($src_t_node) ;

    #izen bereziei ez aldatu.agian ez da modu egokiena baina anode eskuratuz egin da.
    #inglesez definiteness ez badago definituta baina hala bada, gazteleraz ezaugarria gehitzen da
    if (defined($src_t_node) && 
	($src_t_node->gram_sempos || "") =~ /n.denot/ and 
	!(defined($src_t_node->gram_definiteness)) and
	$lex_anode->get_iset('nountype') ne 'prop' and
	$t_node->formeme eq 'n:subj'
	)
    {
	$t_node->set_gram_definiteness('definite');
    }
}
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2EU::FixDefinitiveness

=head1 DESCRIPTION

Sometimes non-definite English subjects are definite on Spanish. For example:

Students arrived on time -> IkasleAK orduan iritsi ziren.

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
