package Treex::Block::W2A::JA::FixPeriod;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# We change "。" to classic period, also rehang it to root 

sub process_atree {
    my ( $self, $a_root ) = @_;
    foreach my $child ( $a_root->get_descendants() ) {
        if ( $child->form eq "。") {
            $child->set_form(".");
            $child->set_lemma(".");
            $child->set_parent($a_root);
        }
    }
    return 1;
}

1;
