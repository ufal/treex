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
    # check if the subject is already a part of a coindex chain; if so, use the coindex chain id 
    my $coindex_id = $asubj->wild->{coindex_phrase} // $asubj->wild->{coindex};

    # if not, make a new coindex chain: connect the new node with the subject leaf node or its 
    # non-terminal node
    if ( !$coindex_id ){
        $coindex_id = $asubj->id;
        if ( !$asubj->is_leaf ) {
            $asubj->wild->{coindex_phrase} = $coindex_id;
        }
        else {
            $asubj->wild->{coindex} = $coindex_id;
        }
    }
    $acoindex->wild->{coindex} = $coindex_id;
        
    return $acoindex;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::CoindexNodes

=head1 DESCRIPTION

A Moose role for adding co-indexed subjects, used by C<FixAuxVerbsAlpinoStyle>,
C<FixCoindexSubjectsAlpinoStyle>, and C<FixQuestionsAlpinoStyle>.

It checks whether the target subject is already a part of a coindex chain, so
multiple blocks using this role may be combined.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
