package Treex::Block::HamleDT::Test::SingleEffectiveRootChild;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# Test if the tree root has more children than just sentence and the final
# punctuation.

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @rootChildren = $a_root->get_children();
    
    if (scalar @rootChildren == 1) { return; }
    if (scalar @rootChildren > 2) { $self->complain($a_root); }
    
    # root has two children
    foreach my $anode (@rootChildren) {
        # if one of them is punctuation => OK
        if ($anode->afun =~ /^Aux[XK]/) { return; }
    }
    
    # complain otherwise
    $self->complain($a_root);       
}

#(C) 2012 Jindřich Libovický <jlibovicky@gmail.com>

1;
