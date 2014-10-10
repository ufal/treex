package Treex::Block::T2A::NL::MoveVerbsToClauseEnd;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode() or return;

    # move all auxiliaries; move the finite verb if not in main clause
    if ( $tnode->formeme =~ /^v.*fin$/ and any { $_->afun =~ /^(AuxV|Obj)$/ } $tnode->get_aux_anodes() ) {
        my @anodes = grep { $_->afun =~ /^(AuxV|Obj)/ } $tnode->get_aux_anodes();
        if ( $tnode->formeme ne 'v:fin' ) {
            unshift @anodes, $anode;
        }
        my ($last_in_clause) = $self->get_last_in_clause($anode);
        foreach my $aaux ( reverse @anodes ) {
            $aaux->shift_after_node( $last_in_clause, { without_children => 1 } );
        }
    }

    # move infinitives after their subtrees within the same clause (?)
    elsif ( $tnode->formeme =~ /^v:inf/ ) {
        my ($last_in_clause) = $self->get_last_in_clause($anode);
        my ($last_in_subtree) = $anode->get_descendants( { last_only => 1 } );
        $anode->shift_after_node( $last_in_clause->ord < $last_in_subtree->ord ? $last_in_clause : $last_in_subtree, { without_children => 1 } );
    }

    # TODO move finite main clause verb to 2nd position !!!
    return;
}

sub get_last_in_clause {
    my ( $self, $anode ) = @_;
    my ($last_in_clause) = first { $_->clause_number == $anode->clause_number } reverse $anode->get_root->get_descendants( { ordered => 1 } );
    return $last_in_clause;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::NL::MoveVerbsToClauseEnd

=head1 DESCRIPTION

Move all dependent parts of the verbal complex, as well as infinitives and main verb in 
dependent clauses, to the end of the clause.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
