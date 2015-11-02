package Treex::Block::W2A::CS::FixReflexiveTantum;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::CS::Reflexivity;

extends 'Treex::Core::Block';

sub process_anode {

    my ( $self, $anode ) = @_;
    my ($refl) = grep { $_->afun eq 'AuxT' } $anode->get_children();

    return if ( !$refl );

    my $tantum_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $anode->lemma, 1 ) . '_' . lc( $refl->form );

    # the particle 'se/si' is marked as reflexive tantum, but that's not possible with the given verb
    if ( !Treex::Tool::Lexicon::CS::Reflexivity::is_possible_tantum($tantum_lemma) ) {

        # make an adverbial ("free dative") out of it, if the particle is 'si' and there is another object besides it
        if ( $refl->form eq 'si' and any { $_->afun eq 'Obj' } $anode->get_echildren( { or_topological => 1 } ) ) {
            $refl->set_afun('Adv');
        }

        # make an object out of it, if the verb is in 1st or 2nd person, is an infinitive or the particle is 'si'
        # (i.e. all cases where a reflexive passive is unlikely)
        elsif ( $anode->tag =~ m/^V(......[12]|f)/ or $refl->form eq 'si' ) {
            $refl->set_afun('Obj');
        }

        # otherwise make a reflexive passive marker out of it
        else {
            $refl->set_afun('AuxR');
        }
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CS::FixReflexiveTantum

=head1 DESCRIPTION

This makes sure that any reflexive tantum particle "se/si" as marked by the parser (C<AuxT>) hangs under an actual
reflexive tantum verb (or deverbative noun or adjective).

If not, the C<afun> of the reflexive particle  is converted to C<AuxR>, C<Obj> or C<Adv>.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
