   package Treex::Block::A2A::CA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

   sub deprel_to_afun
    {
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
    my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $ppos = $parent->tag();
        # ROOT=S
        if($deprel eq 'S')
        {
	    #if it is verb-main
            if($node->tag() =~ 'vm')
            {
                $node->set_afun('Pred');
            }
            else
            {

                $node->set_afun('ExD');
            }
        }
        #mark auxilary verbs
        elsif($deprel eq 'AUX')
        {
        if($node->tag() =~ 'va')
            {
                $node->set_afun('AuxV');
            }
        }
        
         elsif($deprel eq 'SF')
        {
          if($node->tag() =~ 'vm')
            {
		if($ppos =~'n'){
                $node->set_afun('Atr');
                }
                else{
                $node->set_afun('Obj');
                }
            }
            elsif ($node->tag() =~ 'va')
            {

                $node->set_afun('AuxV');
            }
        }
        
        #mark all determiners
            if($node->tag() =~ 'd')
            {
                $node->set_afun('Atr');
            }
            #find terminal punctuation
            if($node->tag() =~ 'Fp')
            {
                $node->set_afun('AuxK');
            }
            #find commas, need to resolve when it is a coordinating conjunction
            if($node->tag() =~ 'Fc')
            {
                $node->set_afun('AuxX');
            }
            #numerals
             if($node->tag() =~ 'Z')
            {
                $node->set_afun('Atr');
            }
            #adverbs
             if($node->tag() =~ 'R')
            {
                $node->set_afun('Adv');
            }
            #default noun behavior
             if($node->tag() =~ 'n')
            {
                $node->set_afun('Atr');
            }
            
            #mark the subject
             elsif($deprel eq 'SUJ')
        {
       
                $node->set_afun('Sb');
            
        }
            
            
        }
        }