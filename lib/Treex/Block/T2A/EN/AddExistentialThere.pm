package Treex::Block::T2A::EN::AddExistentialThere;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # find finite verb "be" with no subject and an object, not an imperative
    return if ( $tnode->t_lemma ne 'be' or $tnode->formeme !~ /^v.*fin$/ );
    return if ( ( $tnode->sentmod // '' ) eq 'imper' );
    return if ( any { $_->formeme eq 'n:subj' } $tnode->get_echildren( { or_topological => 1 } ) );
    
    my $anode = $tnode->get_lex_anode() or return;
    return if ( any { ( $_->afun // '' ) eq 'Sb' } $anode->get_echildren( { or_topological => 1 } ) );

    my $tobj = first { $_->formeme eq 'n:obj' } $tnode->get_echildren( { or_topological => 1 } );
    return if !$tobj;

    # create the node
    my $athere = $anode->create_child(
        {
            'lemma'         => 'there',
            'form'          => 'there',
            'tag'           => 'EX',
            'afun'          => 'Sb',  # TODO is it a real subject ??
            'morphcat/pos'  => '!',
            'morphcat/person'  => '3',
            'clause_number' => $anode->clause_number,
        }
    );
    # place it right before the verb
    $athere->shift_before_node($anode);

    # set fake morphcat number according to the object, so that subject-predicate agreement works
    if ( $tobj->gram_number eq 'pl' or $tobj->is_member ) {
        $athere->set_morphcat_number('P');
    }
    elsif ( $tobj->gram_number eq 'sg' ) {
        $athere->set_morphcat_number('S');
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddExistentialThere

=head1 DESCRIPTION

Adding the existential "there" (as in "There is a party") with a subject afun.

This should be called *before* imposing subject-predicate agreement since morphcat_number
of "there" simulates the number of the (formal) object.

The new "there" is not added to any a/aux.rf (TODO fix?).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
