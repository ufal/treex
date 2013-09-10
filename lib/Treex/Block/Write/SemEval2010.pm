package Treex::Block::Write::ConllLike;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value

has '+language' => ( required => 1 );

has '+extension' => ( default => '.conll' );

has '_entity_ids' => ( is => 'rw', isa => 'HashRef', builder => sub {{}} );

around 'process_document' => sub {
    my ($orig, $self, $doc) = @_;
    print {$self->_file_handle} "#begin document " . $doc->full_filename . "\n";
    $self->$orig($doc);
    print {$self->_file_handle} "#end document " . $doc->full_filename . "\n";
};

sub process_atree {
    my ($self, $atree) = @_;
    my @nodes = $atree->get_descendants({ordered => 1});

    my @data = $self->_extract_data(\@nodes);
   
    my $str = join "\n", (map {join "\t", @$_} @data);
    print { $self->_file_handle } "$str\n";
}

sub _extract_data_node {
    my ($self, $anode) = @_;

    my $parent_ord = !$anode->is_root ? $anode->get_parent->ord : 0;

    my @cols = (
        $anode->ord,        # Col 1     ID: word identifiers in the sentence
        $anode->form,       # Col 2     TOKEN: word forms
        $anode->lemma,      # Col 3     LEMMA: word lemmas (gold standard manual annotation)
        $NOT_SET,           # Col 4     PLEMMA: word lemmas predicted by an automatic analyzer
        $anode->tag,        # Col 5     POS: coarse part of speech
        $NOT_SET,           # Col 6     PPOS same as 5 but predicted by an automatic analyzer
        $NOT_SET,           # Col 7     FEAT: morphological features (part of speech type, number, gender, case, tense, aspect, degree of comparison, etc., separated by the character "|")
        $NOT_SET,           # Col 8     PFEAT: same as 7 but predicted by an automatic analyzer
        $parent_ord,        # Col 9     HEAD: for each word, the ID of the syntactic head ('0' if the word is the root of the tree)
        $NOT_SET,           # Col 10    PHEAD: same as 9 but predicted by an automatic analyzer 
        $anode->afun,       # Col 11    DEPREL: dependency relation labels corresponding to the dependencies  described in 9
        $NOT_SET,           # Col 12    PDEPREL: same as 11 but predicted by an automatic analyzer
        $NOT_SET,           # Col 13    NE: named entities
        $NOT_SET,           # Col 14    PNE: same as 13 but predicted by a named entity recognizer
        $NOT_SET,           # Col 15    PRED: predicates are marked and annotated with a semantic class label 
        $NOT_SET,           # Col 16    PPRED: Same as 13 but predicted by an automatic analyzer
                            # Col *     APREDs: N columns, one for each predicate in 15, containing the semantic roles/dependencies of each particular predicate
                            # Col *     PAPREDs: M columns, one for each predicate in 16, with the same information as APREDs but predicted with an automatic analyzer
        $coref,             # Col -1    COREF: coreference annotation in open-close notation, using "|" to separate multiple annotations
    );

}

sub _extract_coref {
    my ($self, $aroot) = @_;

    my $troot = $aroot->get_zone->get_ttree;
    my @coref_tnodes = grep {} $troot->get_descendants({ordered => 1})

}

sub _extract_data {
    my ($self, $nodes) = @_;

    foreach my $node (@$nodes) {

    }

}

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
