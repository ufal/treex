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

my %HEAD_SCORE = ('hd' => 6, 'cmp' => 5, 'crd' => 4, 'dlink' => 3, 'rhd' => 2, 'whd' => 1);

my %DEPREL_CONV = (
    'su' => 'Sb',
    'sup' => 'Sb',
    'obj1' => 'Obj',
    'pobj1' => 'Obj',
    'se' => 'Obj', # reflexive
    'obj2' => 'Obj',
    'me' => 'Obj', # adverbial complement
    'ld' => 'Obj', # ditto
    'predc' => 'Pnom', # predicative complement
    'vc' => 'Obj', # verbal complement (?)
    'obcomp' => 'Obj', # comparative complement of an adjective
    'pc' => 'Obj', # prepositional object
    'predm' => 'Adv',
    'cmp' => 'AuxC',
    'crd' => 'Coord',
    'app' => 'Apos',
    'se' => 'AuxT',
);

# convert original deprels (stored as conll_deprel) to PDT-style afuns
sub convert_deprel {
    my ($self, $node) = @_;

    my $deprel = $node->conll_deprel // '';
    my $afun = $DEPREL_CONV{$deprel};
    if (!$afun) {
        if ($deprel eq 'mod'){
            $afun = 'Atr' if ($node->is_adjective);
            $afun = 'Neg' if ($node->lemma eq 'niet');
            $afun = 'Adv' if (!$afun);
        }
        elsif($deprel eq 'hd'){
            $afun = 'Atr' if ($node->match_iset('synpos' => 'attr'));
            $afun = 'Pred' if ($node->is_verb and $node->parent->is_root);
            $afun = 'AuxP' if ($node->is_preposition);
            $afun = 'Obj' if (!$afun);  # subject is selected later
        }
        elsif($deprel eq 'det'){
            $afun = $node->match_iset('subpos' => 'art') ? 'AuxA' : 'Atr';        
        }
        elsif($deprel eq '--'){
            $afun = 'AuxK' if ($node->lemma =~ /[\.!?]/);
            $afun = 'AuxX' if ($node->lemma eq ',');
            $afun = 'AuxG' if (!$afun);
        }
        elsif ($deprel eq 'mwp'){
            # set AuxP for multi-word prepositions, avoid other multi-word units
            $afun = 'AuxP' if ($node->is_preposition or (($node->parent->conll_deprel // '') eq 'mwp' and ($node->parent->afun // '') eq 'AuxP'));
            $afun = 'AuxA' if (!$afun and $node->match_iset('subpos' => 'art'));
            $afun = 'NR' if (!$afun);
        }
        elsif ($deprel eq 'svp'){
            $afun = 'AuxV' if ($node->is_preposition or $node->is_adverb);
            $afun = 'Obj' if (!$afun);
        }
        else {
            $afun = 'NR'; # keep unselected
        }
    }
    $node->set_afun($afun);
}

sub convert_pos {
    my ($self, $node, $postag) = @_;
    
    # convert to Interset (TODO would need CoNLL encoding capability to set CoNLL POS+feat)
    my $iset = tagset::nl::cgn::decode($postag);
    $node->set_iset($iset);
}

# given a non-terminal, return the word-order value of the leftmost terminal node governed by it
sub _leftmost_terminal_ord {
    my ($p_node) = @_;
    return min( map { $_->wild->{pord} } grep { $_->form and $_->wild->{pord} } $p_node->get_descendants() );
}

sub create_subtree {

    my ($self, $p_root, $a_root) = @_;
    
    my @children = sort {($HEAD_SCORE{$b->wild->{rel}} || 0) <=> ($HEAD_SCORE{$a->wild->{rel}} || 0)} grep {!defined $_->form || $_->form !~ /^\*\-/} $p_root->get_children();
    #my @children = sort {($HEAD_SCORE{$b->wild->{rel}} || 0) <=> ($HEAD_SCORE{$a->wild->{rel}} || 0)} $p_root->get_children();
    
    # no coordination head -> insert commas from those attached to sentence root
    if ($p_root->phrase eq 'conj' and not any {$_->form} @children){
        # find a punctuation node just before the last coordination member 
        my ($last_child) = sort { _leftmost_terminal_ord($b) <=> _leftmost_terminal_ord($a) } @children;        
        my $needed_ord = _leftmost_terminal_ord($last_child) - 1;
        my ($punct_node) = grep { ($_->wild->{pord} // -1) == $needed_ord } $p_root->get_root()->get_children();

        # punctuation node has been found -- use it as the coordination head
        if ($punct_node){
            $punct_node->wild->{rel} = 'crd';
            unshift @children, $punct_node;
            # an a-node for the same p-node has already been created -> mark it for deletion
            if ($self->_processed_nodes->{$punct_node}){
                $self->_nodes_to_remove->{$punct_node} = $self->_processed_nodes->{$punct_node};
            }
            # remember that we created an a-node for this p-node
            $self->_processed_nodes->{$punct_node} = $a_root;
        }
    }

    my $head = $children[0];
    foreach my $child (@children) {
        my $new_node;
        if ($child == $head) {
            $new_node = $a_root;
        }
        else {
            $new_node = $a_root->create_child();
        }
        if (defined $child->form) { # the node is terminal
            $self->fill_attribs($child, $new_node);
        }
        elsif (defined $child->phrase) { # the node is nonterminal
            $self->create_subtree($child, $new_node);
        }
    }
}

# fill newly created node with attributes from source
sub fill_attribs {
    my ($self, $source, $new_node) = @_;

    $new_node->set_terminal_pnode($source);
    $new_node->set_form($source->form);
    $new_node->set_lemma($source->lemma);
    $new_node->set_tag($source->tag);
    $new_node->set_attr('ord', $source->wild->{pord});
    $new_node->set_conll_deprel($source->wild->{rel});
    $self->convert_pos($new_node, $source->wild->{postag});
    foreach my $attr (keys %{$source->wild}) {
        next if $attr =~ /^(pord|rel)$/;
        $new_node->wild->{$attr} = $source->wild->{$attr};
    }
    $self->convert_deprel($new_node);
}


sub process_zone {
    my ($self, $zone) = @_;
    my $p_root = $zone->get_ptree;
    my $a_root = $zone->create_atree();

    $self->_set_processed_nodes({});
    $self->_set_nodes_to_remove({});
    foreach my $child ($p_root->get_children()) {

        # skip nodes already attached to coordination
        next if ($self->_processed_nodes->{$child});

        my $new_node = $a_root->create_child();

        if ($child->phrase) {
            $self->create_subtree($child, $new_node);
        }
        else {
            $self->fill_attribs($child, $new_node);
            # remember that we created an a-node for this p-node (likely punctuation)
            # so it gets deleted if we use the p-node as coordination head
            $self->_processed_nodes->{$child} = $new_node;
        }
    }
    # remove doubly created punctuation nodes (keep coord heads)
    foreach my $node (values %{$self->_nodes_to_remove}){
        $node->remove();
    }
    # setting coordination members
    # TODO shared modifiers
    $self->set_coord_members($a_root);
    # post-processing
    $self->rehang_relative_clauses($a_root);
    $self->mark_subjects($a_root);
    $self->rehang_aux_verbs($a_root);
    $self->fix_mwu($a_root);    
}

sub set_coord_members {
    my ($self, $a_root) = @_;
    foreach my $a_node ($a_root->get_descendants()){
        $a_node->set_is_member(1) if (($a_node->parent->afun // '') =~ /^(Coord|Apos)$/);
    }
}

# Rehang relative clauses so the predicate of the clause governs it, not the WH-word
# TODO: coordinated verbs in the clause? 
sub rehang_relative_clauses {
    my ($self, $a_root) = @_;

    foreach my $anode (grep { $_->conll_deprel eq 'rhd' } $a_root->get_descendants()){
        my ($clause) = $anode->get_children();
        my $parent = $anode->get_parent();
        $clause->set_parent($parent);
        $anode->set_parent($clause);
        $anode->set_afun( $anode->is_adverb ? 'Adv' : 'Obj' );
        $clause->set_afun('Atr');
        $clause->set_is_member($anode->is_member);
        $anode->set_is_member(undef);
    }
}

# Set the afun 'Sb' for the first plain noun group in nominative or non-marked case
# TODO: check for congruency in number
sub mark_subjects {
    my ($self, $a_root) = @_;

    foreach my $a_verb (grep { $_->match_iset('verbform' => 'fin') } $a_root->get_descendants()){
        my @objects = grep { $_->is_noun or $_->match_iset('synpos' => 'subst') } $a_verb->get_echildren({ordered=>1, or_topological=>1});
        # skip clauses where subjects are already marked
        next if (any { $_->afun eq 'Sb' } @objects);
        # look for explicite nominatives
        my $first_nom = first { $_->match_iset('case' => 'nom') } @objects;
        if ($first_nom){
            $first_nom->set_afun('Sb');
            next;
        }
        # look for first noun with unmarked case
        my $first_unmarked = first { !$_->get_iset('case') } @objects;
        if ($first_unmarked){
            $first_unmarked->set_afun('Sb');
        }
    }
}

# Rehang auxiliaries under main verb: zullen (+infinitive), worden hebben zijn (+participle)
# TODO: other combinations (gaan+inf, zijn+inf)?    
sub rehang_aux_verbs {
    my ($self, $a_root) = @_;
    
    foreach my $aux_verb (grep { $_->lemma =~ /^(zullen|worden|hebben|zijn)$/ } $a_root->get_descendants({ordered=>1})){

        # find full verbs hanging on the auxiliary
        my $full_verbform = $aux_verb->lemma eq 'zullen' ? 'inf' : 'part';
        my @full_verbs = first { $_->match_iset('verbform' => $full_verbform) } $aux_verb->get_echildren({or_topological=>1});
        my $verb_head;

        # find where to rehang (under full verb or its coordination head if more full verbs
        # share the auxiliary
        if (@full_verbs > 1 and $full_verbs[0]->is_member){
            $verb_head = $full_verbs[0]->parent;            
        }
        elsif (@full_verbs){
            $verb_head = $full_verbs[0];
        }
        # rehang (including children of the auxiliary), update afuns
        if ($verb_head){
            $verb_head->set_parent($aux_verb->get_parent);
            $verb_head->set_is_member($aux_verb->is_member);
            $aux_verb->set_is_member(undef);
            $aux_verb->set_parent($verb_head);
            map { $_->set_parent($verb_head) } $aux_verb->get_children();
            map { $_->set_afun($aux_verb->afun) } @full_verbs;
            $aux_verb->set_afun('AuxV');
        }
    }
}

# Heuristics for fixing multi-word units: rehanging everything under the last part of the MWU
sub fix_mwu {
    my ($self, $a_root) = @_;
    my %mwus = ();
    
    # find MWUs in a tree
    foreach my $mwu_member (grep { $_->conll_deprel eq 'mwp' } $a_root->get_descendants({ordered=>1})){
        my ($mwu_id) = $mwu_member->get_terminal_pnode->get_parent->id;
        if (!$mwus{$mwu_id}){
            $mwus{$mwu_id} = [];    
        }
        push @{ $mwus{$mwu_id} }, $mwu_member;
    }   
    
    # process each MWU separately
    foreach my $mwu (values %mwus){
        
        # get the last member
        my $last_member = pop @$mwu;
        # rehang last member under the parent of the MWU
        $last_member->set_parent($mwu->[0]->get_parent);
        # rehang all MWU members under the last member
        foreach my $mwu_member (@$mwu){
            $mwu_member->set_parent($last_member);
        }
        # rehang all further children of the MWU under the last member 
        foreach my $mwu_child (@$mwu->[0]->get_children){
            $mwu_child->set_parent($last_member);
        }
    }    
    
}

1;

=over

=item Treex::Block::P2A::NL::Alpino

Converts phrase-based Dutch Alpino Treebank to dependency format.

=back

=cut

# Copyright 2014 David Mareček <marecek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
