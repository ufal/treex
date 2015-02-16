package Treex::Block::A2T::EN::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetSentmod';

override 'is_imperative' => sub {
    my ( $self, $tnode, $anode ) = @_;

    # technically, imperatives should be VB, not VBP,
    # but the tagger often gets this wrong...
    return 0 if not $anode or $anode->tag !~ /^VBP?$/;

    # but still, the form and lemma of an imperative should be equal
    return 0 if lc( $anode->form ) ne lc( $anode->lemma );

    # rule out expressions with (preceding) modals and auxiliaries or infinitives
    return 0 if ( grep { $_->tag =~ /^(MD|VB[DZ]|TO)$/ and $_->precedes($anode) } $tnode->get_aux_anodes() );

    # imperatives do not usually take subordinate conjunctions
    # -- but still from the data it seems that they do more often than not
    # next if grep { $_->afun eq 'AuxC' } $tnode->get_aux_anodes;

    # imperatives have no subjects (on the surface)
    return 0 if grep { $_->formeme eq "n:subj" } $tnode->get_echildren();

    return 1;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

English-specific detection of imperatives.

=head1 SEE ALSO

L<Treex::Block::A2T::SetSentmod>

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague