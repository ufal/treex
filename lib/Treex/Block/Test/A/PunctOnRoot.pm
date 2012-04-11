package Treex::Block::Test::A::PunctOnRoot;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# Tests if in the sentences where is a punctuation at the end, it is really 
# child of the root node.

sub process_atree {
    my ( $self, $a_root ) = @_;
   
    foreach my $anode ($a_root->get_children()) {
        if ($anode->afun =~ /^Aux[XK]/) {
            return;
        }
    }

    my @subtrees = $a_root->get_descendants({ordered=>1});
    if ($subtrees[-1]->afun =~ /^Aux[XK]/) {
    	$self->complain($a_root);
    }
           
}

# (C) 2012 Jindřich Libovický <jlibovicky@gmail.com>

1;
