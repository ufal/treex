package Treex::Block::T2A::AddAppositionPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent();
    return if $parent->is_root();

    if ( $self->is_apposition( $tnode, $parent ) ) {

        my $anode = $tnode->get_lex_anode;

        # first comma separating the two apposited members
        my $left_comma = add_comma_node( $anode->get_parent );
        $left_comma->shift_before_subtree($anode);

        # another comma added after the second apposited member only
        # if there is no other punctuation around
        if ( defined $anode ) {

            my $rightmost_descendant = $anode->get_descendants( { last_only => 1, add_self => 1 } );
            my $after_rightmost = $rightmost_descendant->get_next_node;

            if ( defined $after_rightmost ) {    # not the end of the sentence
                if ( !grep { $_->get_attr('morphcat/pos') eq 'Z' } ( $rightmost_descendant, $after_rightmost ) ) {
                    my $right_comma = add_comma_node( $anode->get_parent );
                    $right_comma->shift_after_subtree($anode);
                }
            }
        }
    }
    return;
}

sub add_comma_node {
    my ($parent) = @_;
    return $parent->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
}

# To be overridden in derived classes
sub is_apposition {
    my ($tnode, $tparent) = @_;
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddAppositionPunct

=head1 DESCRIPTION

Add commas in apposition constructions such as "John, my best friend, ...".

This block contains the language-independent part of the code (the actual adding of punctuation),
detecting the punctuation is done in language-specific derived classes.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
