package Treex::Block::A2A::NL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll' );


#    $self->deprel_to_afun($a_root)
    $self->attach_final_punctuation_to_root($a_root);
#    $self->process_prepositional_phrases($a_root);
#    $self->restructure_coordination($a_root);
    $self->resolve_coordinations($a_root);
#    $self->check_afuns($a_root);
    $self->deprel_to_afun($a_root);
    $self->fix_AuxK($a_root);
    $self->fix_questionAdverbs($a_root);
    $self->fix_InfinitivesNotBeingObjects($a_root);
    $self->fix_SubordinatingConj($a_root);
}


my %cpos2afun = (
    'Art' => 'AuxA',
    'Prep' => 'AuxP',
    'Adv' => 'Adv',
    'Punc' => 'AuxX',
    'Conj' => 'AuxC', # also Coord, but it is already filled when filling is_member of its children
);


my %parentcpos2afun = (
    'Prep' => 'Adv',
    'N' => 'Atr',
);


my %deprel2afun = (
    'su' => 'Sb',
    'obj1' => 'Obj',
    # "vc" = verbal complement
    'vc' => 'Obj',
    # "se" = obligatory reflexive object
    'se' => 'Obj',
#    'ROOT' => 'Pred',
);

sub deprel_to_afun {
    my ( $self, $root ) = @_;

    foreach my $node (grep {not $_->is_coap_root} $root->get_descendants)  {
        
        #If AuxK is set then skip this node.
        next if(defined $node->afun and $node->afun eq 'AuxK');


        my ($parent) = $node->get_eparents();

        my $deprel = ( $node->is_member ? $node->get_parent->conll_deprel : $node->conll_deprel() );

#        if (not defined $deprel) {
#            print $node->get_address."\n";
#
#            exit;
#        }

        my $cpos    = $node->get_attr('conll/pos');
        my $parent_cpos   = ($parent and not $parent->is_root) ? $parent->get_attr('conll/cpos') : '';

        my $afun = $deprel2afun{$deprel} || # from the most specific to the least specific
                $cpos2afun{$cpos} ||
                    $parentcpos2afun{$parent_cpos} ||
                        'NR'; # !!!!!!!!!!!!!!! temporary filler

        if ($deprel eq 'obj1' and $parent_cpos eq 'Prep') {
            $afun = 'Adv';
        }

        if ($parent->is_root and $cpos eq 'V') {
            $afun = 'Pred';
        }

	# Change deprel "body" to afun "Pred" if its parent is not "Pred" and is directly under the root.
	if ($deprel eq 'body' and defined $parent->get_parent and $parent->get_parent->is_root and $parent->afun ne 'Pred' and not $parent->tag =~ /J,.*/) {
		$afun = 'Pred';
		$node->set_parent($root);
		$parent->set_parent($node);
	}


        if ($node->get_parent->afun eq 'Coord' and not $node->is_member
                and ($node->get_iset('pos')||'') eq 'conj') {
            $afun = 'AuxY';
        }

        # AuxX should be used for commas, AuxG for other graphic symbols
        if($afun eq q(AuxX) && $node->form ne q(,)) {
            $afun = q(AuxG);
        }

        $node->set_afun($afun);
    }
}


sub resolve_coordinations {
    my ( $self, $root ) = @_;

    foreach my $conjunct (grep {$_->conll_deprel eq 'cnj'} $root->get_descendants) {
        my $coord_head = $conjunct->get_parent;
        $conjunct->set_is_member(1);
        $coord_head->set_afun('Coord');
        # added by DM: commas should depend on conjunctions
        foreach my $comma (grep {$_->form eq ',' && $_->ord > $conjunct->ord} $conjunct->get_children) {
            $comma->set_parent($coord_head);
        }
        # added by DM: first-member children placed after the coordination may be shared modifiers
        foreach my $child ($conjunct->get_children) {
            if ($conjunct->ord < $coord_head->ord && $child->ord > $coord_head->ord) {
                $child->set_parent($coord_head);
                $child->set_is_shared_modifier(1);
            }
        }
    }
}

sub fix_AuxK {
    my ( $self, $root ) = @_;
    my $lastSubtree = ($root->get_descendants({ordered=>1}))[-1];

    # change to final punctuation
    if ($lastSubtree->afun eq "AuxX") {
        $lastSubtree->set_afun("AuxK");

        if ($lastSubtree->get_parent() != $root) {
            $lastSubtree->set_parent($root);
        }
    }
}

sub fix_questionAdverbs {
    my ( $self, $root ) = @_;

    # first find all question adverbs depending directly on the root
    my @adv_root_children = ();
    foreach my $anode ($root->get_children()) {
        if ($anode->afun eq "NR" &&
            $anode->tag =~ /^P4/) {
            
            push @adv_root_children, $anode;
            
        }
    }

    # if such adverb is followed 
    foreach my $adv (@adv_root_children) {
        if (scalar $adv->get_children() == 1 &&
              ($adv->get_children())[0]->tag =~ /^VB/) {
            my $verb = ($adv->get_children())[0];

            $verb->set_afun("Pred");
            $verb->set_parent($root);

            $adv->set_afun("Adv");
            $adv->set_parent($verb);

        }
    }
}

sub fix_InfinitivesNotBeingObjects {
    my ( $self, $root ) = @_;

    my @standalonePreds = ();
    my @standaloneInfinitives = ();


    foreach my $anode ($root->get_children()) {
        if ($anode->afun eq "Pred") { 
            push @standalonePreds, $anode;
        }
        elsif ($anode->tag =~ /^Vf/) {
            push @standaloneInfinitives, $anode;
        }
    }

    # fix the simpliest case...
    if (scalar @standalonePreds == 1 && scalar @standaloneInfinitives == 1) {
        my $pred = $standalonePreds[0];
        my $infinitive = $standaloneInfinitives[0];

        $infinitive->set_parent($pred);
        $infinitive->set_afun("Obj");
    }
}

sub fix_SubordinatingConj {
    my ( $self, $root ) = @_;
    
    # take sentences with two predicates on the root
    my @predicates = ();
    foreach my $anode ($root->get_children()) {
        if ($anode->afun eq "Pred") { push @predicates, $anode; }
    }
    
    # just two clauses, it should be obvious how they should look like
    if (scalar @predicates == 2) {
        my @subordConj = ("omdat", "doordat", "aangezien", "daar", "dan", 
            "zodat", "opdat", "als", "zoals", "tenzij", "voordat", "nadat", 
            "terwijl", "dat", "hoezeer", "indien");
        my $mainClause;
        my $depedentClause;
        my $conj;
        
        my @firstNodes = $predicates[0]->get_descendants({ordered=>1});
        my @secondNodes = $predicates[1]->get_descendants({ordered=>1});
        
        if ( @firstNodes && $firstNodes[0]->lemma =~ (join '|', @subordConj) ) {
            $depedentClause = $predicates[0];
            $mainClause = $predicates[1];
            $conj = $firstNodes[0];
        }
        elsif ( @secondNodes && $secondNodes[0]->lemma =~ (join '|', @subordConj) ) {
            $depedentClause = $predicates[1];
            $mainClause = $predicates[0];
            $conj = $secondNodes[1];
        }
        else { return; }
        
       
        $conj->set_parent($mainClause);
        $depedentClause->set_parent($conj);
        $depedentClause->set_afun("NR");
    }
}



1;

=over

=item Treex::Block::A2A::NL::CoNLL2PDTStyle

Converts Dutch trees from CoNLL 2006 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# + 2012 Jindrich Libovicky <jlibovicky@gmail.com> and Ondrej Kosarko
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
