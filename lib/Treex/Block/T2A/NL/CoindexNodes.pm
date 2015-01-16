package Treex::Block::T2A::NL::CoindexNodes;

use Moose::Role;

sub add_coindex_node {
    my ( $self, $averb, $asubj, $afun ) = @_;

    my $acoindex = $averb->create_child(
        {   'lemma'         => '',
            'form'          => '',
            'afun'          => $afun,
            'clause_number' => $averb->clause_number
        }
    );
    $acoindex->wild->{coindex} = $asubj->id;

    # coindex with the subject leaf node or its "whole phrase" node
    if ( !$asubj->is_leaf ) {
        $asubj->wild->{coindex_phrase} = $asubj->id;
    }
    else {
        $asubj->wild->{coindex} = $asubj->id;
    }
    return $acoindex;
}


1;