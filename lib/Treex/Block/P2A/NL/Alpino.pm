package Treex::Block::P2A::NL::Alpino;
use Moose;
use Treex::Core::Common;
use utf8;

use tagset::nl::cgn;

#use Treex::Block::HamleDT::NL::Harmonize;

extends 'Treex::Core::Block';

#has '_harmonizer' => ( isa => 'Treex::Block::HamleDT::NL::Harmonize',
#'is' => 'ro',
#lazy_build => 1,
#builder => '_build_harmonizer',
#reader => '_harmonizer',
#);

#sub _build_harmonizer {
#my ($self) = @_;
#return Treex::Block::HamleDT::NL::Harmonize->new();
#}

has '_processed_nodes' => ( isa => 'HashRef', 'is' => 'rw' );
has '_nodes_to_remove' => ( isa => 'HashRef', 'is' => 'rw' );

my %HEAD_SCORE = (
    'hd'    => 6,
    'crd'   => 4,
    'cmp'   => 5,
    'dlink' => 3,
    'rhd'   => 2,    # relative clause head
    'tag'   => 2,    # discourse tag "He said that..."
    'whd'   => 1,    # wh-question head
    'rhd'   => 1,
    'nucl'  => 1,    # main clause (against "als"-clause)
);

my %DEPREL_CONV = (
    'su'     => 'Sb',
    'sup'    => 'Sb',
    'pobj1'  => 'Obj',
    'se'     => 'Obj',     # reflexive
    'obj2'   => 'Obj',
    'me'     => 'Obj',     # adverbial complement
    'ld'     => 'Obj',     # ditto
    'predc'  => 'Pnom',    # predicative complement
    'vc'     => 'Obj',     # verbal complement (?)
    'obcomp' => 'Obj',     # comparative complement of an adjective
    'pc'     => 'Obj',     # prepositional object
    'predm'  => 'Adv',
    'cmp'    => 'AuxC',
    'crd'    => 'Coord',
    'app'    => 'Atr',     # 'hoofstad Luxembourg[app]', 'heer Sleiffer[app]', 'opus 93[app]' etc.
    'se'     => 'AuxT',
    'hdf'    => 'AuxP',    # closing element of a circumposition
);

# convert original deprels (stored as conll_deprel) to PDT-style afuns
sub convert_deprel {
    my ( $self, $node ) = @_;

    my $deprel = $node->conll_deprel // '';
    my $afun = $DEPREL_CONV{$deprel};

    # override Afun for prepositions, except in separable verbal prefixes
    $afun = 'AuxP' if ( $node->is_adposition and $deprel ne 'svp' );   
    
    if ( !$afun ) {
        # obj1 defaults to 'Obj' but we need a special treatment for prepositional phrases
        if ( $deprel eq 'obj1' ){
            my $parent = $node->get_parent();
            if ( $parent and $parent->is_adposition ){
                my $grandpa = $parent->get_parent();
                if ( ( $parent->conll_deprel // '' ) eq 'mod' ){
                    $afun = 'Atr' if ( $grandpa and ( $grandpa->is_noun or $grandpa->is_adjective ) );
                    $afun = 'Adv' if ( !$afun );
                }
            }
            $afun = 'Obj' if ( !$afun );
        }
        # attributes (or adverbials)
        elsif ( $deprel eq 'mod' ) {
            my $parent = $node->get_parent();
            $afun = 'Atr' if ( $parent and $parent->is_noun or $parent->is_adjective );
            $afun = 'Neg' if ( $node->lemma eq 'niet' );
            $afun = 'Adv' if ( !$afun );
        }
        # AuxA is much narrower than Alpino's det 
        elsif ( $deprel eq 'det' ) {
            $afun = $node->match_iset( 'prontype' => 'art' ) ? 'AuxA' : 'Atr';
        }
        # This is everything hanging under the root
        elsif ( $deprel eq '--' ) {
            $afun = 'Pred' if ( $node->is_verb );
            $afun = 'AuxK' if ( $node->lemma =~ /[\.!?]/ );
            $afun = 'AuxX' if ( $node->lemma eq ',' );
            $afun = 'AuxG' if ( !$afun );
        }
        # multi-word names have no sense of Afuns internally
        elsif ( $deprel eq 'mwp' ) {
            $afun = 'AuxP' if ( $node->is_adposition );
            $afun = 'AuxC' if ( $node->is_conjunction );
            $afun = 'AuxA' if ( !$afun and $node->match_iset( 'prontype' => 'art' ) );
            $afun = 'NR'   if ( !$afun );
        }
        # separable verbal parts
        elsif ( $deprel eq 'svp' ) {
            $afun = 'AuxV' if ( $node->is_adposition or $node->is_adverb );
            $afun = 'Obj' if ( !$afun );
        }
        else {
            $afun = 'NR';    # keep unselected
        }
    }
    $node->set_afun($afun);
}

sub convert_pos {
    my ( $self, $node, $postag ) = @_;

    # convert to Interset (TODO would need CoNLL encoding capability to set CoNLL POS+feat)
    my $iset = tagset::nl::cgn::decode($postag);
    $node->set_iset($iset);
}

# given a non-terminal, return the word-order value of the leftmost terminal node governed by it
sub _leftmost_terminal_ord {
    my ($p_node) = @_;
    my @desc = grep { defined( $_->form ) and defined( $_->wild->{pord} ) } $p_node->get_descendants( { add_self => 1 } );
    return min( map { $_->wild->{pord} } @desc );
}

sub create_subtree {

    my ( $self, $p_root, $a_root ) = @_;

    my @children = sort { ( $HEAD_SCORE{ $b->wild->{rel} } || 0 ) <=> ( $HEAD_SCORE{ $a->wild->{rel} } || 0 ) } grep { !defined $_->form || $_->form !~ /^\*\-/ } $p_root->get_children();

    # log_info( 'CH:' . join( ' ', map { $_->form // $_->phrase . '=' . $_->wild->{rel} } @children ) );

    # no coordination head -> insert commas from those attached to sentence root
    if ( $p_root->phrase eq 'conj' and not any { $_->wild->{rel} eq 'crd' } @children ) {

        # find a punctuation node just before the last coordination member
        my ($last_child) = sort { _leftmost_terminal_ord($b) <=> _leftmost_terminal_ord($a) } @children;
        my $needed_ord = _leftmost_terminal_ord($last_child) - 1;
        my ($punct_node) = grep { ( $_->wild->{pord} // -1 ) == $needed_ord } $p_root->get_root()->get_children();

        # punctuation node has been found -- use it as the coordination head
        if ($punct_node) {
            $punct_node->wild->{rel} = 'crd';
            unshift @children, $punct_node;

            # an a-node for the same p-node has already been created -> mark it for deletion
            if ( $self->_processed_nodes->{$punct_node} ) {
                $self->_nodes_to_remove->{$punct_node} = $self->_processed_nodes->{$punct_node};
            }

            # remember that we created an a-node for this p-node
            $self->_processed_nodes->{$punct_node} = $a_root;
        }
    }

    # process the node: fill the attributes or recurse into subtrees
    my $head = $children[0];
    foreach my $child (@children) {

        # give the deprel of the whole phrase to its head, so that we don't lose this information
        if ( $child->wild->{rel} eq 'hd' ) {
            $child->wild->{rel} = $p_root->wild->{rel};
        }

        my $new_node;
        if ( $child == $head ) {
            $new_node = $a_root;
        }
        else {
            $new_node = $a_root->create_child();
        }
        
        if ( defined $child->form ) {    # the node is terminal
            $self->fill_attribs( $child, $new_node );
        }
        elsif ( defined $child->phrase ) {    # the node is nonterminal
            $self->create_subtree( $child, $new_node );
        }

    }
}

# fill newly created node with attributes from source
sub fill_attribs {
    my ( $self, $source, $new_node ) = @_;

    $new_node->set_terminal_pnode($source);
    $new_node->set_form( $source->form );
    $new_node->set_lemma( $source->lemma );
    $new_node->set_tag( $source->tag );
    $new_node->set_attr( 'ord', $source->wild->{pord} );
    $new_node->set_conll_deprel( $source->wild->{rel} );
    $self->convert_pos( $new_node, $source->wild->{postag} );
    foreach my $attr ( keys %{ $source->wild } ) {
        next if $attr =~ /^(pord|rel)$/;
        $new_node->wild->{$attr} = $source->wild->{$attr};
    }
    $self->convert_deprel($new_node);
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $p_root = $zone->get_ptree;
    my $a_root = $zone->create_atree();

    $self->_set_processed_nodes( {} );
    $self->_set_nodes_to_remove( {} );
    foreach my $child ( $p_root->get_children() ) {

        # skip nodes already attached to coordination
        next if ( $self->_processed_nodes->{$child} );

        my $new_node = $a_root->create_child();

        if ( $child->phrase ) {
            $self->create_subtree( $child, $new_node );
        }
        else {
            $self->fill_attribs( $child, $new_node );

            # remember that we created an a-node for this p-node (likely punctuation)
            # so it gets deleted if we use the p-node as coordination head
            $self->_processed_nodes->{$child} = $new_node;
        }
    }

    # remove doubly created punctuation nodes (keep coord heads)
    foreach my $node ( values %{ $self->_nodes_to_remove } ) {
        $node->remove();
    }

    # setting coordination members
    # TODO shared modifiers
    $self->set_coord_members($a_root);

    # post-processing
    $self->rehang_wh_clauses($a_root);    # rehang relative clauses and wh-questions
    $self->rehang_aux_verbs($a_root);
    $self->fix_mwu($a_root);
    $self->rehang_prec($a_root);
}

sub set_coord_members {
    my ( $self, $a_root ) = @_;
    foreach my $a_node ( $a_root->get_descendants() ) {
        $a_node->set_is_member(1) if ( ( $a_node->parent->afun // '' ) =~ /^(Coord|Apos)$/ );
    }
}

# Rehang relative clauses/wh-questions so the predicate of the clause governs it, not the WH-word
# TODO: coordinated verbs in the clause?
sub rehang_wh_clauses {
    my ( $self, $a_root ) = @_;

    foreach my $anode ( grep { $_->conll_deprel =~ /^(rhd|whd)$/ } $a_root->get_descendants() ) {
        my ($clause) = grep { $_->conll_deprel eq 'body' } $anode->get_children();
        next if ( !$clause );
        my $parent = $anode->get_parent();
        $clause->set_parent($parent);
        $anode->set_parent($clause);
        $anode->set_afun( $anode->is_preposition ? 'AuxP' : ( $anode->is_adverb ? 'Adv' : 'Obj' ) );
        $clause->set_afun( $parent->is_root ? 'Pred' : 'Atr' );
        $clause->set_is_member( $anode->is_member );
        $anode->set_is_member(undef);
    }
    return;
}


# Rehang auxiliaries under main verb: zullen (+infinitive), worden hebben zijn (+participle)
# TODO: other combinations (gaan+inf, zijn+inf)?
sub rehang_aux_verbs {
    my ( $self, $a_root ) = @_;

    foreach my $aux_verb ( grep { $_->lemma =~ /^(zullen|worden|hebben|zijn)$/ } $a_root->get_descendants( { ordered => 1 } ) ) {

        # find full verbs hanging on the auxiliary
        my $full_verbform = $aux_verb->lemma eq 'zullen' ? 'inf' : 'part';
        my @full_verbs = grep { $_->match_iset( 'verbform' => $full_verbform ) } $aux_verb->get_echildren( { or_topological => 1 } );
        my $verb_head;

        # avoid coordinations where some members are full verbs and some aren't
        if ( any { $_->is_member } @full_verbs ) {
            my ($coap_root) = map { $_->get_parent } first { $_->is_member } @full_verbs;
            my %eq = map { $_ => 1 } @full_verbs;
            $eq{$_} -= 1 foreach ( $coap_root->get_coap_members );
            return if ( any { $_ != 0 } values %eq );
        }

        # find where to rehang (under full verb or its coordination head if more full verbs
        if ( @full_verbs > 1 and $full_verbs[0]->is_member ) {
            $verb_head = $full_verbs[0]->parent;
        }
        elsif (@full_verbs) {
            $verb_head = $full_verbs[0];
        }

        # rehang (including children of the auxiliary), update afuns
        if ($verb_head) {
            $verb_head->set_parent( $aux_verb->get_parent );
            $verb_head->set_is_member( $aux_verb->is_member );
            $aux_verb->set_is_member(undef);
            $aux_verb->set_parent($verb_head);
            map { $_->set_parent($verb_head) } $aux_verb->get_children();
            map { $_->set_afun( $aux_verb->afun ) } @full_verbs;
            $aux_verb->set_afun('AuxV');
        }
    }
    return;
}

# Heuristics for fixing multi-word units: rehanging everything under the last part of the MWU
sub fix_mwu {
    my ( $self, $a_root ) = @_;
    my %mwus = ();

    # find MWUs in a tree
    foreach my $mwu_member ( grep { $_->conll_deprel eq 'mwp' } $a_root->get_descendants( { ordered => 1 } ) ) {
        my ($mwu_id) = $mwu_member->get_terminal_pnode->get_parent->id;
        if ( !$mwus{$mwu_id} ) {
            $mwus{$mwu_id} = [];
        }
        push @{ $mwus{$mwu_id} }, $mwu_member;
        $mwu_member->wild->{mwu_id} = $mwu_id;
    }

    # process each MWU separately
    foreach my $mwu ( values %mwus ) {

        my $sig = join( '_', map { _get_mwu_part_type($_) } @$mwu );

        # skip MWUs that should not be rehanged
        next if ( scalar(@$mwu) == 2 and $sig =~ /(adp|subord)_(adj|noun|adv|verb)/ );

        # set afun := AuxP for MW prepositions (adp + noun + adp, adp + noun + adv with er/daar-)
        if ( $sig =~ /^adp_noun_adp$/ ) {
            map { $_->set_afun('AuxP') } @$mwu;
        }
        elsif ( $sig =~ /^adp_noun_adv$/ and $mwu->[-1]->lemma =~ /^(er|daar)/ ) {
            $mwu->[1]->set_afun('AuxP');
        }

        # find out which mwu member hangs the highest
        my ($mwu_top) = sort { $a->get_depth() <=> $b->get_depth() } @$mwu;

        # get the last member
        my $last_member = pop @$mwu;

        # rehang last member under the parent of the whole MWU
        $last_member->set_parent( $mwu_top->get_parent );

        # rehang all MWU members under the last member
        foreach my $mwu_member (@$mwu) {
            $mwu_member->set_parent($last_member);
        }

        # rehang all further children of the MWU under the last member
        foreach my $mwu_child ( $mwu_top->get_children ) {
            $mwu_child->set_parent($last_member);
        }
    }
}

sub _get_mwu_part_type {
    my ($anode) = @_;
    return 'art'    if $anode->is_article;
    return 'adp'    if $anode->is_adposition;
    return 'noun'   if $anode->is_noun;
    return 'adv'    if $anode->is_adverb;
    return 'adj'    if $anode->is_adjective;
    return 'verb'   if $anode->is_verb;
    return 'subord' if $anode->is_subordinator;
    return 'other';
}

sub rehang_prec {
    my ( $self, $aroot ) = @_;

    foreach my $prec ( grep { $_->match_iset( 'pos' => 'conj', 'conjtype' => 'coor' ) and scalar( $_->get_children() ) == 1 } $aroot->get_children() ) {
        my ($child) = $prec->get_children();
        $child->set_parent( $prec->get_parent() );
        $prec->set_parent($child);
        $prec->set_afun('AuxY');
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::P2A::NL::Alpino

=head1 DESCRIPTION

Converts phrase-based Dutch Alpino Treebank to dependency format.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
