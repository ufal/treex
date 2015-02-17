package Treex::Block::T2A::NL::Alpino::MarkStype;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::NL::Pronouns;
use Treex::Tool::Lexicon::NL::VerbformOrder;

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # looking for the main verb of the clause
    return if ( !$tnode->is_clause_head );

    # get the finite verb
    my ($top_anode) = Treex::Tool::Lexicon::NL::VerbformOrder::normalized_verbforms($tnode);
    next if ( !$top_anode or !$top_anode->match_iset( 'verbform' => 'fin' ) );

    # mark its sentence type according to the sentmod attribute
    my $stype = $self->_get_stype( $tnode, ( $tnode->sentmod // '' ) );
    if ($stype) {
        $top_anode->wild->{stype} = $stype;
    }
}

sub _get_stype {
    my ( $self, $tvfin, $sentmod ) = @_;

    return 'declarative' if ( $sentmod eq 'enunc' );
    return 'imparative'  if ( $sentmod eq 'imper' );    # ("imp*a*rative" is not a typo)

    if ( $sentmod eq 'inter' ) {
        return 'whquestion' if any { Treex::Tool::Lexicon::NL::Pronouns::is_wh_pronoun( $_->t_lemma ) } $tvfin->get_clause_descendants();
        return 'ynquestion';
    }

    return;                                             # we don't know
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::MarkStype

=head1 DESCRIPTION

Marking sentence type for Alpino according to the sentmod grammateme and the presence
of wh-pronouns in the sentence.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
