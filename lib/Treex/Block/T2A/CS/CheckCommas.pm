package Treex::Block::T2A::CS::CheckCommas;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    if ($tnode->wild->{check_comma_after}) {
        my $anode = $tnode->get_lex_anode or return;
        my $next_anode = $anode->get_next_node;
        return if !$next_anode || $next_anode->lemma eq ",";

        my $comma = $anode->create_child({
            'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        });
        $comma->shift_after_node($anode);
    }
}

1;
