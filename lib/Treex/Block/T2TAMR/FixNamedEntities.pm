package Treex::Block::T2TAMR::FixNamedEntities;

use Moose;
use Treex::Core::Common;
use Treex::Block::T2TAMR::CopyTtree;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has '+selector'       => ( isa => 'Str', default => 'amrClonedFromT' );


sub process_ttree {
    
    my ( $self, $troot ) =  @_;

    my $src_troot = $troot->src_tnode;
    return if (!defined $src_troot);
    my $nroot = $src_troot->get_zone()->get_ntree();
    return if (!defined $nroot);

    # remember used AMR variables
    my $used_vars = $self->_check_used_vars($troot);

    # get top-level NEs (skip sub-NEs embedded in them, note that this embedding is not reflected in the n-tree shape)
    # TODO this needs fixing, everything is now a single NE ?!
    my %nodes_aspans = map { $_->id => [ $_->get_anodes ] } $nroot->get_descendants();
    my (@nnodes) = grep {
        my $id = $_->id;
        not any { $_ ne $id and _is_subset( $nodes_aspans{$id}, $nodes_aspans{$_} ) } keys %nodes_aspans;
    } $nroot->get_descendants();

    # find t-nodes pertaining to each of the NEs and group them under a node of the desired type
    foreach my $nnode (@nnodes){
        # find the t-nodes
        my @tnodes = uniq 
                sort { $a->ord <=> $b->ord }
                map { $_->get_referencing_nodes( 'src_tnode.rf', $self->language, $self->selector ) }
                map { $_->get_referencing_nodes('a/lex.rf') } 
                map { $_->get_anodes() } 
                @nnodes;
        # select the topmost one
        my %depth_to_node = map { $_->get_depth() => $_ } @tnodes;
        my $min_depth = min keys %depth_to_node;
        my $ttop = $depth_to_node{$min_depth};

        # create a new NE head AMR node + a new “name” node, rehang everything under them
        my $tparent = $ttop->get_parent();
        my $tne_head = $tparent->create_child();
        $tne_head->wild->{modifier} = $ttop->wild->{modifier};
        $tne_head->set_functor( $ttop->functor );
        $tne_head->set_t_lemma( $self->_create_lemma( $nnode->ne_type, $used_vars )  );
        $tne_head->shift_before_node($ttop);
        my $tne_name = $tne_head->create_child();
        $tne_name->wild->{modifier} = 'name';
        $tne_name->set_t_lemma( Treex::Block::T2TAMR::CopyTtree::create_amr_lemma( 'name', $used_vars ) );
        $tne_name->shift_after_node($tne_head);
        
        # change the individual NE element nodes to constants with modifier opX
        # + rehang their children under the NE head
        my $order = 1;
        map { 
            $_->set_parent($tne_name); 
            $_->wild->{modifier} = 'op' . ($order++);
            my $lemma = $_->t_lemma;
            $lemma =~ s/.*\///;
            $_->set_t_lemma('"' . $lemma . '"');
            map { $_->set_parent($tne_head) } $_->get_children();
        } @tnodes;
    }

    return;
}

# check if one set is a subset of another one
sub _is_subset {
    my ($littleSet, $bigSet) = @_;
    my %hash;
       
    undef @hash{@$littleSet};  # add a hash key for each element of @$littleSet
    delete @hash{@$bigSet};    # remove all keys for elements of @$bigSet
    return !%hash;             # return false if any keys are left in the hash
}

# keep track of all used AMR variables
sub _check_used_vars {
    my ( $self, $troot ) = @_;
    my %used = ();
    foreach my $tnode ($troot->get_descendants()){
        my ($var, $number) = ($tnode->t_lemma =~ /^([a-zX])([0-9]*)/);
        $used{$var} = max( $used{$var} // 0, ($number || 1) );
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

    my $word_id = $NE_2_WORD->{$ne_type} // $NE_2_WORD->{substr $ne_type, 0, 1};
    return Treex::Block::T2TAMR::CopyTtree::create_amr_lemma($word_id, $used_vars); 
}


1;

=head1 NAME

Treex::Block::T2TAMR::FixNamedEntities

=head1 DESCRIPTION

Converting named entities into AMR-like format (using n-tree links).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
