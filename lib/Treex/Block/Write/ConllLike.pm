package Treex::Block::Write::ConllLike;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value
Readonly my $NO_NUMBER => -1;     # CoNLL-ST format: undefined integer value
Readonly my $FILL      => "_";    # CoNLL-ST format: "fill predicate"
Readonly my $TAG_FEATS => {
    "SubPOS" => 1,
    "Gen"    => 2,
    "Num"    => 3,
    "Cas"    => 4,
    "PGe"    => 5,
    "PNu"    => 6,
    "Per"    => 7,
    "Ten"    => 8,
    "Gra"    => 9,
    "Neg"    => 10,
    "Voi"    => 11,
    "Var"    => 14
};    # tag positions and their meanings
Readonly my $TAG_NOT_SET => "-";    # tagset: undefined value

has '+language' => ( required => 1 );

# MAIN
sub process_ttree {
    my ( $this, $t_root ) = @_;
    my @data;

    # Get all needed informations for each node
    my @nodes = $t_root->get_descendants( { ordered => 1 } );
    foreach my $node (@nodes) {
        push( @data, get_node_info($node) );
    }

    # print the results
    foreach my $line (@data) {
        $this->_print_st($line);
    }
    print { $this->_file_handle } ("\n");
    return 1;
}

# Retrieves all the information needed for the conversion of each node and
# stores it as a hash.
sub get_node_info {

    my ($t_node) = @_;
    my $a_node = $t_node->get_lex_anode();
    my %info;

    $info{"ord"}     = $t_node->ord;
    $info{"head"}    = $t_node->get_parent() ? $t_node->get_parent()->ord : 0;
    $info{"functor"} = $t_node->functor ? $t_node->functor : $NOT_SET;
    $info{"lemma"}   = $t_node->t_lemma;

    if ($a_node) {    # there is a corresponding node on the a-layer
        $info{"tag"}  = $a_node->tag;
        $info{"form"} = $a_node->form;
        $info{"afun"} = $a_node->afun;
    }
    else {            # generated node
        $info{"tag"}  = $NOT_SET;
        $info{"afun"} = $NOT_SET;
        $info{"form"} = $info{"lemma"};
    }

    # initialize aux-info
    $info{"aux_forms"}  = "";
    $info{"aux_lemmas"} = "";
    $info{"aux_pos"}    = "";
    $info{"aux_subpos"} = "";
    $info{"aux_afuns"}  = "";

    # get all aux-info nodes
    my @aux_anodes = $t_node->get_aux_anodes( { ordered => 1 } );

    # fill in the aux-info
    for my $aux_anode (@aux_anodes) {
        $info{"aux_forms"}  .= "|" . $aux_anode->form;
        $info{"aux_lemmas"} .= "|" . lemma_proper( $aux_anode->lemma );
        $info{"aux_pos"}    .= "|" . substr( $aux_anode->tag, 0, 1 );
        $info{"aux_subpos"} .= "|" . substr( $aux_anode->tag, 1, 1 );
        $info{"aux_afuns"}  .= "|" . $aux_anode->afun;
    }

    $info{"aux_forms"}  = $info{"aux_forms"}  eq "" ? $NOT_SET : substr( $info{"aux_forms"},  1 );
    $info{"aux_lemmas"} = $info{"aux_lemmas"} eq "" ? $NOT_SET : substr( $info{"aux_lemmas"}, 1 );
    $info{"aux_pos"}    = $info{"aux_pos"}    eq "" ? $NOT_SET : substr( $info{"aux_pos"},    1 );
    $info{"aux_subpos"} = $info{"aux_subpos"} eq "" ? $NOT_SET : substr( $info{"aux_subpos"}, 1 );
    $info{"aux_afuns"}  = $info{"aux_afuns"}  eq "" ? $NOT_SET : substr( $info{"aux_afuns"},  1 );

    return \%info;
}

# Prints a data line in the pseudo-CoNLL-ST format:
#     ID, FORM, LEMMA, (nothing), PoS, (nothing), PoS Features, (nothing),
#     HEAD, (nothing), FUNCTOR, (nothing), Y, (nothing),
#     AFUN, AUX-FORMS, AUX-LEMMAS, AUX-POS, AUX-SUBPOS, AUX-AFUNS
sub _print_st {
    my ( $this, $line )  = @_;
    my ( $pos,  $pfeat ) = $this->_analyze_tag( $line->{"tag"} );

    print { $this->_file_handle } (
        join(
            "\t",
            (
                $line->{ord}, $line->{"form"}, $line->{"lemma"}, $NOT_SET,
                $pos, $NOT_SET, $pfeat, $NOT_SET,
                $line->{"head"}, $NO_NUMBER, $line->{"functor"}, $NOT_SET,
                $FILL, $NOT_SET, $line->{"afun"}, $line->{"aux_forms"},
                $line->{"aux_lemmas"}, $line->{"aux_pos"}, $line->{"aux_subpos"}, $line->{"aux_afuns"}
                )
            )
    );
    print { $this->_file_handle } ("\n");
    return;
}

# Given a tag, returns the PoS and PoS-Feat values for Czech, just the tag and "_" for any other
# language; or double "_", given an unset tag value.
sub _analyze_tag {

    my ( $this, $tag ) = @_;

    if ( $tag eq $NOT_SET ) {
        return ( $NOT_SET, $NOT_SET );
    }
    if ( $this->language ne "cs" ) {
        return ( $tag, $NOT_SET );
    }

    my $pos = substr( $tag, 0, 1 );
    my $pfeat = "";

    foreach my $feat ( keys %{$TAG_FEATS} ) {
        my $idx = $TAG_FEATS->{$feat};
        my $val = substr( $tag, $idx, 1 );

        if ( $val ne $TAG_NOT_SET ) {
            $pfeat .= $pfeat eq "" ? "" : "|";
            $pfeat .= $feat . "=" . $val;
        }
    }
    return ( $pos, $pfeat );
}

# Given a PDT-style morphological lemma, returns just the "lemma proper" part without comments, links, etc.
sub lemma_proper {
    my ($lemma) = @_;
    $lemma =~ s/(_;|_:|_,|_\^|`).*$//;
    return $lemma;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::ConllLike

=head1 DESCRIPTION

Prints out all t-trees in a text format similar to CoNLL (with no APREDs and some different values
relating to auxiliary a-nodes instead).

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 TODO

Parametrize, so that the true CoNLL output as well as this extended version is possible.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
