package Treex::Block::HamleDT::Test::PredHeadInterrogativePronoun;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

#Tests, if interrogative pronouns are dependent on the predicate


sub process_atree {
    my ( $self, $a_root ) = @_;

    my @adv_root_children = ();
    foreach my $anode ($a_root->get_children()) {
        
        if ($anode->tag =~ /^P4/) {
            #It is a interrogative pronoun

            push @adv_root_children, $anode;
            
        }
    }

    #Test for each pronoun...
    foreach my $anode (@adv_root_children) {
        
        #complaining, if verb is dependent
        if (scalar $anode->get_children() == 1 and
              ($anode->get_children())[0]->tag =~ /^VB/) {
            $self->complain($a_root);            
        }
    }
}


# (C) 2012 Jindrich Libovicky <jlibovicky@gmail.com>
# (C) 2012 Karel Bilek <kb@karelbilek.com>
