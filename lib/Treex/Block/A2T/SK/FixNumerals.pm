package Treex::Block::A2T::SK::FixNumerals;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS::Numerals;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode;

    if ( $anode and Treex::Tool::Lexicon::CS::Numerals::is_noncongr_numeral( $anode->lemma, $anode->tag ) ) {

        # more coordinated numerals (all members of a coordination)
        if ( $tnode->is_member ) {

            my $tparent  = $tnode->get_parent();
            my @tmembers = $tnode->get_parent->get_coap_members();
            my @amembers = map { $_->get_lex_anode } @tmembers;

            if ( ( grep { Treex::Tool::Lexicon::CS::Numerals::is_noncongr_numeral( $_->lemma, $_->tag ) } @amembers ) > 1 ) {

                my @tsiblings = grep { !$_->is_member() } $tparent->get_children();

                # test the first following non-member child
                my ($echild) = grep { $_->ord > $tnode->ord } @tsiblings;

                if ( $echild and _is_genitive_attribute($echild) ) {

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

            if ( $tchild and _is_genitive_attribute($tchild) ) {
                _rehang( $tnode, $tchild );
                _rehang_aux_nodes( $tnode, $tchild );
            }
        }

    }

    return;
}

# Return 1 if the given node is a genitive (or 'X'-case) attribute, or coordination of such children
sub _is_genitive_attribute {

    my ($tnode) = @_;

    if ( $tnode->is_coap_root() ) {
        my @members = $tnode->get_coap_members();
        if ( scalar( grep { _is_pure_genitive($_) } @members ) == scalar(@members) ) {
            return 1;
        }
    }
    elsif ( _is_pure_genitive($tnode) ) {
        return 1;
    }
    return 0;
}

# Return 1 if the given t-node's a-node is a pure genitive (or 'X') with no prepositions
sub _is_pure_genitive {

    my ($tnode) = @_;
    my $anode   = $tnode->get_lex_anode();
    my $tlemma  = $tnode->t_lemma;

    return 0 if ( $anode->tag !~ m/^....[2X]/ );

    my @auxs = grep {
        my $lemma = $_->lemma;
        $_->tag !~ /^[VZ]/ and $tlemma !~ /(^|_)$lemma(_|$)/
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

1;
