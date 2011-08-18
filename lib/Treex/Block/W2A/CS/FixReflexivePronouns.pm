package Treex::Block::W2A::CS::FixReflexivePronouns;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {

    my ( $self, $anode ) = @_;

    return if ( $anode->is_root );

    # fix the reflexive pronoun based on parser output
    if ( $anode->form eq 'se' and $anode->tag =~ m/^RV/ and $anode->afun =~ m/^(AuxT|AuxR|Obj)$/ ) {
        $anode->set_lemma('se_^(zvr._zájmeno/částice)');
        $anode->set_tag('P7-X4----------');
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::CS::FixReflexivePronouns

=head1 DESCRIPTION

Changes the tag of the word 'se' from 'RV' to 'P7' if the afun assigned by the parser makes it clear that it is
a reflexive pronoun, not a preposition.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
