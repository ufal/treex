package Treex::Block::T2T::SetAClauseNumber;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

### marks clausenum with the finite verb's clausenum
sub set_aclause_num {
    my ( $node, $clausenum, $p_vlist ) = @_;
    if ( $node->nodetype eq "coap" ) {
        foreach my $child ( $node->get_children( { ordered => 1 } ) ) {
            if ( grep { $_ eq $child } @$p_vlist ) {
                $clausenum = ($child->clause_number < $clausenum) ? $child->clause_number : $clausenum;
            }
        }
    }
    elsif ( grep { $_ eq $node } @$p_vlist ) {
        $clausenum = $node->clause_number;
    }
    $node->set_clause_number($clausenum);
    foreach my $child ( $node->children ) {
        set_aclause_num( $child, $clausenum, $p_vlist );
    }
}

sub set_aclause_num_root {
    my ( $root ) = @_;

#     my @vlist = grep { $_->gram_tense =~ /^(sim|ant|post)/ or $_->functor =~ /^(PRED|DENOM)$/ } $root->get_descendants();
    my @vlist = grep { $_->is_clause_head } $root->get_descendants();
    if ( not @vlist ) {
        @vlist = $root->get_children( { ordered => 1 } );
    }
    @vlist = sort { $a->wild->{doc_ord} <=> $b->wild->{doc_ord} } @vlist;
    for ( my $i = 0; $i < @vlist; $i++ ) {
        $vlist[$i]->set_clause_number($i+1);
    }
    set_aclause_num($root, 0, \@vlist);
    return $#vlist + 1;
}

### looks for finite verbs, sorts them by doc_ord and marks their clausenum with their ord; returns the number of finite verbs
sub process_zone {
    my ( $self, $zone ) = @_;
    foreach my $root ( $zone->get_ttree ) {
        set_aclause_num_root( $root );
    }
    return;
}

1;

=over

=item Treex::Block::T2T::SetAClauseNumber

Every t-node becomes a clause number according to the order of the clause in the surface sentence.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky, Nguy Giang Linh
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
