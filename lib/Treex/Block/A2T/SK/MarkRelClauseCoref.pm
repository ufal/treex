package Treex::Block::A2T::SK::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::CS::MarkRelClauseCoref';

override '_get_lex_anode_tag' => sub {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();
    return '' if ( !$anode );
    return $anode->wild->{tag_cs_pdt} // '';
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SK::MarkRelClauseCoref

=head1 DESCRIPTION

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in Slovak t-trees
and stored into the C<coref_gram.rf> attribute.

This is just a thin wrapper over the Czech coreference detector, 
L<Treex::Block::A2T::CS::MarkRelClauseCoref>, compensating for tagset differences.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
