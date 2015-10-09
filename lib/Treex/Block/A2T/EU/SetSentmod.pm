package Treex::Block::A2T::EU::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetSentmod';

override 'is_question' => sub {
    my ( $self, $t_node, $a_node ) = @_;
    my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } );
    return 0 if ( !$t_parent->is_root );
    return 0 if any { $_->is_clause_head and $t_node->precedes($_) } $t_parent->get_echildren();

    my $a_root = $t_parent->get_zone->get_atree();
    return 0 if ( !$a_root );

    my ( $last_token, @toks ) = reverse $a_root->get_descendants( { ordered => 1 } );

    foreach my $t (@toks) {
	return 1 if ($t->lemma =~ /^(ba|al)$/);
    }

    if ( @toks && $last_token->afun eq 'AuxG' ) {
        $last_token = shift @toks;
    }
    if ( $last_token && $last_token->form eq '?' ) {
        return 1;
    }
    return 0;
};


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EU::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

T-layer sentmod attribute is filled based on punctuation tokens ("¿", "?", "¡" and "!").

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
