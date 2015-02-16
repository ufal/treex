package Treex::Block::A2T::EN::MarkClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkClauseHeads';

# zatim nejake rozbite, znackuje to i infinitivy

override 'is_clause_head' => sub {
    my ( $self, $t_node ) = @_;
    my $lex_a_node = $t_node->get_lex_anode() or return 0;
    return 0 if $lex_a_node->tag !~ /^V/;

    my @anodes = $t_node->get_anodes( { ordered => 1 } );
    my @tags  = map { $_->tag } @anodes;
    my @forms = map { lc $_->form } @anodes;

    # Rule 1: verb forms containing 3rd person singular are certainly finite
    return 1 if grep {/^(VBZ|MD)$/} @tags;

    # Rule 2: verb forms containing the following modal and auxiliary tokens are certainly finite
    return 1 if grep {/^(is|was|were|had|did|do|am|are|will|wo|n't|'ll|'re|'[mds])$/i} @forms;

    # Rule 3: verb forms containing 'to' before the first verb token are certainly non-finite
    A_NODE:
    foreach my $index ( 0 .. $#anodes ) {
        last A_NODE if $tags[$index] =~ /^V/;
        return 0 if $forms[$index] eq 'to';
    }

    # Rule 4: verb forms for with a subject are (likely to be) finite
    if ( grep {/^(VB|VBD|VBN|VBP)$/} @tags ) {
        return 1 if
            any { $_->afun eq 'Sb' }
            map { $_->get_echildren( { or_topological => 1 } ) }
                grep { $_->tag =~ /^V/ } @anodes;

        #my @leftchildren = map { $_->get_echildren( { or_topological => 1, preceding_only => 1 } ) }
        #    grep { $_->tag =~ /^V/ } @anodes;
        #for my $child (@leftchildren) {
        #    return 1 if is_possible_subject($child);
        #}
    }
    
    # Present with no modals, prepositions etc., are likely to be finite imperatives
    # TODO: how about no auxiliaries? Can imperatives ever have them?
    if ( $lex_a_node->tag =~ /^VBP?$/ and not grep { $_->tag =~ /^(MD|VB[DZ]|TO)$/ and $_->precedes($lex_a_node) } @anodes ){
        return 1;
    }

    # Otherwise: non-finite
    return 0;
};

#sub is_possible_subject {
#    my ($a_node) = @_;
#    return 0 if $a_node->tag  =~ /^(RB[SR]?|IN|\(|\)|:|\$|MD|POS|PRP\$|RP|SYM|TO|WH\$|WRB)$/;
#    return 0 if $a_node->form =~ /^(be|have|[,;()'`:-])$/;
#    return 1;
#}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkClauseHeads

=head1 DESCRIPTION

T-nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

The English implementation uses various heurstics over lemmas and Penn-Treebank-style tags.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

