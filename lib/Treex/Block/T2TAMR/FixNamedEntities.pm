package Treex::Block::T2TAMR::FixNamedEntities;

use Moose;
use Treex::Core::Common;
use Treex::Block::T2TAMR::CopyTtree;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has '+selector' => ( isa => 'Str', default => 'amrConvertedFromT' );

sub process_ttree {

    my ( $self, $troot ) = @_;

    my $src_troot = $troot->src_tnode;
    return if ( !defined $src_troot or !$src_troot->get_zone()->has_ntree() );
    my $nroot = $src_troot->get_zone()->get_ntree();
    return if ( !defined $nroot );

    # remember used AMR variables
    my $used_vars = $self->_check_used_vars($troot);

    # find t-nodes pertaining to each of the NEs and group them under a node of the desired type
    # (using outermost named entities only)
    foreach my $nnode ( $nroot->get_children() ) {

        # find the t-nodes
        my @tnodes = uniq
            sort { $a->ord <=> $b->ord }
            map { $_->get_referencing_nodes( 'src_tnode.rf', $self->language, $self->selector ) }
            map { $_->get_referencing_nodes('a/lex.rf') }
            $nnode->get_anodes();

        # skip weird cases where there are no t-nodes corresponding to the NE
        next if ( !@tnodes );

        # select the topmost one
        my %depth_to_node = map { $_->get_depth() => $_ } @tnodes;
        my $min_depth     = min keys %depth_to_node;
        my $ttop          = $depth_to_node{$min_depth};

        # create a new NE head AMR node + a new “name” node
        my $tparent  = $ttop->get_parent();
        my $tne_head = $tparent->create_child();
        $tne_head->wild->{modifier} = $ttop->wild->{modifier};
        $tne_head->set_functor( $ttop->functor );
        $tne_head->set_t_lemma( $self->_create_lemma( $nnode->ne_type, $used_vars ) );
        $tne_head->shift_before_node($ttop);
        my $tne_name = $tne_head->create_child();
        $tne_name->wild->{modifier} = 'name';
        $tne_name->set_t_lemma( Treex::Block::T2TAMR::CopyTtree::create_amr_lemma( 'name', $used_vars ) );
        $tne_name->shift_after_node($tne_head);

        # store links to src-tnodes and the n-node
        $tne_head->set_src_tnode($ttop->src_tnode);
        $tne_head->wild->{src_nnode} = $nnode->id;
        $tne_head->wild->{src_tnodes} = [ map { $_->id } grep { defined($_) } map { $_->src_tnode } @tnodes ];
        $tne_head->wild->{is_ne_head} = 1;
        $tne_name->wild->{is_ne_subnode} = 1;

        # remove original t-nodes belonging to the named entity
        foreach my $tnode (@tnodes) {

            # rehang their children under the NE head
            map { $_->set_parent($tne_head) } $tnode->get_children();

            # redirect coreference to NE head
            my $head_var = $tne_head->t_lemma;
            $head_var =~ s/\/.*//;
            map {
                $_->remove_coref_nodes($tnode);
                $_->add_coref_gram_nodes($tne_head);
                $_->set_t_lemma($head_var);
            } $tnode->get_referencing_nodes('coref_gram.rf');
            map {
                $_->remove_coref_nodes($tnode);
                $_->add_coref_text_nodes($tne_head);
                $_->set_t_lemma($head_var);
            } $tnode->get_referencing_nodes('coref_text.rf');

            # delete the original node
            $tnode->remove();
        }

        # introduce new t-nodes corresponding to individual tokens
        my $order = 1;
        foreach my $ne_word ( split / /, $nnode->normalized_name ) {
            my $tnew = $tne_name->create_child(
                t_lemma => '"' . $ne_word . '"',
                functor => 'op' . $order++,
            );
            $tnew->wild->{is_ne_subnode} = 1;
            $tnew->shift_after_subtree($tne_name);
        }
    }

    return;
}

# check if one set is a subset of another one
sub _is_subset {
    my ( $littleSet, $bigSet ) = @_;
    my %hash;

    undef @hash{@$littleSet};    # add a hash key for each element of @$littleSet
    delete @hash{@$bigSet};      # remove all keys for elements of @$bigSet
    return !%hash;               # return false if any keys are left in the hash
}

# keep track of all used AMR variables
sub _check_used_vars {
    my ( $self, $troot ) = @_;
    my %used = ();
    foreach my $tnode ( $troot->get_descendants() ) {
        my ( $var, $number ) = ( $tnode->t_lemma =~ /^([a-zX])([0-9]*)/ );
        $used{$var} = max( $used{$var} // 0, ( $number || 1 ) );
    }
    return \%used;
}

my $NE_2_WORD = {
    'a' => 'address',
    'c' => 'bibliographic',
    'g' => 'geographical',
    'i' => 'institution',
    'm' => 'medium',
    'n' => 'number',
    'o' => 'product',
    'p' => 'person',
    'q' => 'number',
    't' => 'time',
};

# create an AMR-style lemma for the NE head node (find a general name for the
# entity type, deal with variable names)
sub _create_lemma {
    my ( $self, $ne_type, $used_vars ) = @_;
    my $word_id = lc $ne_type;    # allow BBN long NE types

    if ( length $ne_type <= 2 ) { # backoff to two-letter CNEC NE types
        $word_id = $NE_2_WORD->{$ne_type} // $NE_2_WORD->{ substr $ne_type, 0, 1 };
    }

    return Treex::Block::T2TAMR::CopyTtree::create_amr_lemma( $word_id, $used_vars );
}

1;

=head1 NAME

Treex::Block::T2TAMR::FixNamedEntities

=head1 DESCRIPTION

Converting named entities into AMR-like format (using n-tree links).

Prerequisities: Nested NE nodes that always must have links to a-nodes
(run A2N::FixMissingLinks and A2N::NestEntities after NER and before this block).


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
