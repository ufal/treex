package Treex::Block::T2A::NL::MoveFiniteVerbs;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode() or return;

    # only heads of finite clauses with no subordinating conjunction
    if ( $tnode->formeme eq 'v:fin' and $tnode->get_clause_root() eq $tnode ) {
        # find 1st child of this clause, skippng "ja" and "nee"
        my ($first) = grep { $_->lemma !~ /^(ja|nee)$/ } $anode->get_clause_root()->get_echildren( { ordered => 1 } );        

        # if there is only the verb in the clause, there's nowhere to move it :-)
        return if (!defined $first);
        
        # coordinated clauses with non-member 1st effective child: avoid skipping coordination parts 
        # for other members than the 1st, move to the beginning of their own coordination part
        if ( $first->get_parent() != $anode and $anode->is_member and $first->clause_number != $anode->clause_number ){
            ($first) = $anode->get_clause_root()->get_children( { ordered => 1 } );
            return if (!defined $first); # again, if there is only the verb, do nothing 
            $anode->shift_before_subtree( $first, { without_children => 1 } );            
        }
        # 1st position: imperative, question (except after a dependent clause)
        elsif ($first->clause_number == $anode->clause_number and ($tnode->sentmod // '') =~ /^(imper|inter)$/){
            $anode->shift_before_subtree( $first, { without_children => 1 } );
        }
        # 2nd position: indicative (after a dependent clause or subject)
        else {
            $anode->shift_after_subtree( $first, { without_children => 1 } );
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::NL::MoveFiniteVerbs

=head1 DESCRIPTION

Move finite verbs in main clauses to 2nd or 1st position.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

