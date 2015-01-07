package Treex::Block::T2A::NL::FixFormalSubjectsAlpinoStyle;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    return if ( ( $tnode->formeme !~ /^v:(.*+)?fin$/ ) or ( $tnode->t_lemma ne 'zijn' ) );
    my @tchildren = $tnode->get_children();

    my $tformal_subj = first { $self->_is_formal_subject($_) } @tchildren;
    return if ( !$tformal_subj );

    my $tinf_clause = first { $_->formeme eq 'v:om_te+inf' } @tchildren;
    return if ( !$tinf_clause );

    my $aformal_subj = $tformal_subj->get_lex_anode();
    my $ainf_clause = first { $_->lemma eq 'om' } $tinf_clause->get_anodes( { ordered => 1 } );
    return if ( !$ainf_clause );

    $ainf_clause->wild->{adt_rel} = 'su';
    $aformal_subj->wild->{adt_rel} = 'sup';

    return;
}

sub _is_formal_subject {
    my ( $self, $tnode ) = @_;

    return 0 if ( $tnode->formeme ne 'n:subj' );
    my $anode = $tnode->get_lex_anode() or return 0;
    return $anode->lemma eq 'het';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::FixFormalSubjectsAlpinoStyle

=head1 DESCRIPTION

Fix formal subjects of infinitive clauses, e.g., "Het[sup] is goed om[su] te gaan."

Will mark the formal subject and the "real" subject -- the head of the infinitive
clause -- with the ADT relations they should receive (in the "adt_rel" wild attribute). 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    
