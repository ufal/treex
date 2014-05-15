package Treex::Block::A2T::SK::SetDiathesis;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::CS::SetDiathesis';

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

Treex::Block::A2T::SK::SetDiathesis

=head1 DESCRIPTION

The attribute C<gram/diathesis> of Slovak verb t-nodes is filled
with one of the following values:
  act - active diathesis
  pas - passive diathesis
  deagent - deagentive diathesis

This is just a wrapper over the Czech block, L<Treex::Block::A2T::CS::SetDiathesis>.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
