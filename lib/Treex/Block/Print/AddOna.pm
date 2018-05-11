package Treex::Block::Print::AddOna;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_ttree {
    my ($self, $ttree) = @_;
    my @tnodes = $ttree->get_descendants( { ordered => 1 } );
    for my $tnode (@tnodes){
        if (    $tnode->formeme eq 'drop'
            and $tnode->gram_gender eq 'fem'
            and $tnode->gram_number eq 'sg'
            and $tnode->functor eq 'ACT'
            and $tnode->get_parent->gram_tense =~ /sim|post/
            and $tnode->get_parent->gram_verbmod eq 'ind'
            ){

            # Don't add "ona" if the antecedent is in the same sentence.
            my ($antec) = $tnode->get_coref_text_nodes();
            next if $antec and $antec->root == $tnode->root and $antec->formeme ne 'drop';

            my $verb = $tnode->get_parent->get_lex_anode or next;
            my $ona = $verb->create_child(form=>'ona');
            $ona->shift_before_node($verb);
        }
    }
    my $atree = $ttree->get_zone()->get_atree();
    my $sentence = "";
    foreach my $a_node ( $atree->get_descendants( { ordered => 1 } ) ) {
        $sentence .= $a_node->form;
        $sentence .= " " if !$a_node->no_space_after;
    }
    $sentence =~ s/ $//;
    print {$self->_file_handle} $sentence . "\n";
    return;
}

1;

# Preprocessing for cs->en NMT.
# Author: Martin Popel