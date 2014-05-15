package Treex::Block::A2T::CS::FixNumerals;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::CS::Numerals;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode;

    if ( $anode and $self->_check_noncongr_numeral($anode) ) {

        # more coordinated numerals (all members of a coordination)
        if ( $tnode->is_member ) {

            my $tparent  = $tnode->get_parent();
            my @tmembers = $tnode->get_parent->get_coap_members();
            my @amembers = map { $_->get_lex_anode } @tmembers;

            if ( ( grep { $self->_check_noncongr_numeral($_) } @amembers ) > 1 ) {

                my @tsiblings = grep { !$_->is_member() } $tparent->get_children();

                # test the first following non-member child
                my ($echild) = grep { $_->ord > $tnode->ord } @tsiblings;

                if ( $echild and $self->_is_genitive_attribute($echild) ) {

                    # rehang the other non-member children under the first one
                    my @keep_up = grep { $_ != $echild } @tsiblings;
                    map { $_->set_parent($echild) } @keep_up;

                    # swap the coordinated numerals with the first non-member child
                    _rehang( $tparent, $echild );

                    # rehang aux nodes from the numerals themselves
                    map { _rehang_aux_nodes( $_, $echild ) } @tmembers;
                }
            }
        }

        # just a single numeral
        else {

            # more children are generally an error - use the first one always
            my $tchild = $tnode->get_children( { following_only => 1, first_only => 1 } );

            if ( $tchild and $self->_is_genitive_attribute($tchild) ) {
                _rehang( $tnode, $tchild );
                _rehang_aux_nodes( $tnode, $tchild );
            }
        }

    }

    return;
}

# Return 1 if the given node is a genitive (or 'X'-case) attribute, or coordination of such children
sub _is_genitive_attribute {

    my ( $self, $tnode ) = @_;

    if ( $tnode->is_coap_root() ) {
        my @members = $tnode->get_coap_members();
        if ( scalar( grep { $self->_is_pure_genitive($_) } @members ) == scalar(@members) ) {
            return 1;
        }
    }
    elsif ( $self->_is_pure_genitive($tnode) ) {
        return 1;
    }
    return 0;
}

# Return 1 if the given t-node's a-node is a pure genitive (or 'X') with no prepositions
sub _is_pure_genitive {

    my ( $self,      $tnode )   = @_;
    my ( $lex_lemma, $lex_tag ) = $self->_lemma_and_tag( $tnode->get_lex_anode() );
    my $tlemma = $tnode->t_lemma;

    return 0 if ( $lex_tag !~ m/^....[2X]/ );

    my @auxs = grep {
        my ( $lemma, $tag ) = $self->_lemma_and_tag($_);
        $tag !~ /^[VZ]/ and $tlemma !~ /(^|_)$lemma(_|$)/
    } $tnode->get_aux_anodes();

    return ( !@auxs );
}

# Turn the parent-child relation around, move coordination membership, not aux nodes
sub _rehang {
    my ( $parent, $child ) = @_;

    $child->set_parent( $parent->parent );
    $parent->set_parent($child);
    $child->set_is_member( $parent->is_member );
    $parent->set_is_member();

    return;
}

# Rehang all the aux nodes from one node to the other (check for duplicates)
sub _rehang_aux_nodes {
    my ( $from, $to ) = @_;

    $to->add_aux_anodes( $from->get_aux_anodes() );
    $from->set_aux_anodes();

    return;
}

# This returns the lemma-tag pair of a given a-node.
# This method is only introduced in order to be overridden by the corresponding Slovak block.
sub _lemma_and_tag {
    my ( $self, $anode ) = @_;
    return ( Treex::Tool::Lexicon::CS::truncate_lemma( $anode->lemma, 1 ), $anode->tag );
}

# Checking for an incongruent numeral type.
# This method is only introduced in order to be overridden by the corresponding Slovak block.
sub _check_noncongr_numeral {
    my ( $self, $anode ) = @_;
    return Treex::Tool::Lexicon::CS::Numerals::is_noncongr_numeral( $anode->lemma, $anode->tag );
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::FixNumerals

=head1 DESCRIPTION

Swap all incongruent numerals with their "genitive attribute" which in fact is their parent on the t-layer.

The Czech cardinal numerals starting with 5 and indefinite numerals such as "kolik" ("how many") behave syntactically like
nouns in nominative and accusative. The entity whose amount they specify is then expressed in a genitive attribute,
which is fine on the a-layer, but on the t-layer, it should govern the numeral. This block turns the relation so that
it corresponds to the t-layer specifications.

=head1 TODO

=over

=item *

This should probably be extended to nested coordinations involving incongruent numerals (a very rare occurrence, though).

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
