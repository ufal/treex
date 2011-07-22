package Treex::Block::A2A::IT::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';


#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    
    
    
    # attach terminal punctuations (., ?, ! etc) to root of the tree
    $self->attach_final_punctuation_to_root($a_root);    

    # swap the afun of preposition and its nominal head
    afun_swap_prep_and_its_nhead($a_root);
    $self->restructure_coordination($a_root);    
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form = $node->form();
        my $pos = $node->conll_pos();
        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;

        # trivial conversion to PDT style afun
        $afun = 'Atv' if ($deprel eq 'arg');        # arg       -> Atv
        $afun = 'AuxV' if ($deprel eq 'aux');       # aux       -> AuxV
        $afun = 'Atr' if ($deprel eq 'clit');       # clit      -> Atr
        $afun = 'Atv' if ($deprel eq 'comp');       # comp      -> Atv
        $afun = 'Coord' if ($deprel eq 'con');      # con       -> Coord
        $afun = 'Atr' if ($deprel eq 'concat');     # concat    -> Atr
        $afun = 'AuxA' if ($deprel eq 'det');       # det       -> AuxA
        $afun = 'Coord' if ($deprel eq 'dis');      # dis       -> Coord
        $afun = 'Atr' if ($deprel eq 'mod');        # mod       -> Atr
        $afun = 'Atr' if ($deprel eq 'mod_rel');    # mod_rel   -> Atr
        $afun = 'AuxV' if ($deprel eq 'modal');     # modal     -> AuxV
        $afun = 'Atv'  if ($deprel eq 'obl');       # obl       -> Atv
        $afun = 'Obj' if ($deprel eq 'ogg_d');      # ogg_d     -> Obj
        $afun = 'Obj' if ($deprel eq 'ogg_i');      # ogg_i     -> Obj
        $afun = 'Pred' if ($deprel eq 'pred');      # pred      -> Pred
        $afun = 'AuxP' if ($deprel eq 'prep');      # prep      -> AuxP
        $afun = 'Sb' if ($deprel eq 'sogg');        # sogg      -> Sb

        # punctuations
        if ($deprel eq 'punc') {
            if ($form eq ',') {
                $afun = 'AuxX';
            }
            elsif ($form =~ /^(\?|\:|\.|\!)$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # deprelation ROOT can be 'Pred'            # pred      -> Pred
        if (($deprel eq 'ROOT') && ($pos =~ /^(V.*)$/)) {
            $afun = 'Pred';
        }   

        if($afun =~ s/_M$//)
        {
            $node->set_is_member(1);
        }
        $node->set_afun($afun);
    }
}

sub attach_terminal_punc_to_root {
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $fnode = $nodes[$#nodes];
    my $fnode_afun = $fnode->afun();
    if ($fnode_afun eq 'AuxK') {
        $fnode->set_parent($root);
    }
}

# This function will swap the afun of preposition and its nominal head.
# It was because, in the original treebank preposition was given
# 'mod(Atr)' label and its nominal head was given 'prep(AuxP)'.
sub afun_swap_prep_and_its_nhead {
    my $root = shift;
    my @nodes = $root->get_descendants();
    
    foreach my $node (@nodes) {
        if (($node->afun() eq 'AuxP') && ($node->conll_pos() =~ /^S/))  {
            my $parent = $node->get_parent();
            if (($parent->afun() eq 'Atr') && ($parent->conll_pos() eq 'E')) {
                $parent->set_afun('AuxP');
                $node->set_afun('Atr');
            }
        }
    }
}

sub detect_coordination
{
    my $self = shift;
    my $root = shift;
    my $coords = shift; # reference to array where detected coordinations are collected
    # Depth-first search.
    # If a conjarg is found, find all nodes involved in the coordination.
    # Make sure that any conjargs further to the right are not later recognized as different coordination.
    # However, search their descendants for nested coordinations.
    my @members; # coordinated nodes
    my @delimiters; # separators between members: punctuation and conjunctions
    my @modifiers; # other children of the members, including shared modifiers of the whole coordination
    $self->collect_coordination_members($root, \@members, \@delimiters, \@modifiers);
    if(@members)
    {
        # Any left modifiers of the first member will be considered shared modifiers of the coordination.
        # Any right modifiers of the first member occurring after the second member will be considered shared modifiers, too.
        # Note that the Bulgarian structure does not provide for the distinction between shared modifiers and private modifiers of the first member.
        my $ord0 = $root->ord();
        my $ord1 = $members[1]->ord();
        my @sharedmod = grep {($_->ord() < $ord0 || $_->ord() > $ord1) && !$_->match_iset('pos' => 'part', 'negativeness' => 'neg')} (@modifiers);
        # If the first member is a preposition then the real afun is one level down.
        my $afun = $root->afun();
        if($afun eq 'AuxP')
        {
            my $prepcomp = $self->get_preposition_argument($root);
            if(defined($prepcomp))
            {
                $afun = $prepcomp->afun();
            }
        }
        push(@{$coords},
        {
            'members' => \@members,
            'delimiters' => \@delimiters,
            'shared_modifiers' => \@sharedmod,
            'oldroot' => $root
        });
        # Call recursively on all modifier subtrees (but not on members or delimiters).
        foreach my $modifier (@modifiers)
        {
            $self->detect_coordination($modifier, $coords);
        }
    }
    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ($root->children())
        {
            $self->detect_coordination($child, $coords);
        }
    }
}


#------------------------------------------------------------------------------
# Collects members and delimiters of coordination. The BulTreeBank uses two
# approaches to coordination and one of them requires that this method is
# recursive.
#------------------------------------------------------------------------------
sub collect_coordination_members
{
    my $self = shift;
    my $croot = shift; # the first node and root of the coordination
    my $members = shift; # reference to array where the members are collected
    my $delimiters = shift; # reference to array where the delimiters are collected
    my $modifiers = shift; # reference to array where the modifiers are collected
    my @children = $croot->children();
    my @members0 = grep {$_->conll_deprel() eq 'cong' || $_->conll_deprel() eq 'disg'} (@children);
    if(@members0)
    {
        # If $croot is the real root of the whole coordination we must include it in the members, too.
        # However, if we have been called recursively on existing members, these are already present in the list.
        if(!@{$members})
        {
            push(@{$members}, $croot);
        }
        my @delimiters0 = grep {$_->conll_deprel() =~ m/^(Coord)$/} (@children);
        my @modifiers0 = grep {$_->conll_deprel() !~ m/^(Coord|AuxG|AuxK)$/} (@children);
        # Add the found nodes to the caller's storage place.
        push(@{$members}, @members0);
        push(@{$delimiters}, @delimiters0);
        push(@{$modifiers}, @modifiers0);
        # If any of the members have their own conjarg children, these are also members of the same coordination.
        foreach my $member (@members0)
        {
            $self->collect_coordination_members($member, $members, $delimiters, $modifiers);
        }
    }
    # If some members have been found, this node is a coord member.
    # If the node itself does not have any further member children, all its children are modifers of a coord member.
    elsif(@{$members})
    {
        push(@{$modifiers}, @children);
    }
}

1;



=over

=item Treex::Block::A2A::IT::CoNLL2PDTStyle

Converts ISST Italian treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes

        a) Coordination                 -> Yes

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
