package Treex::Block::A2T::SK::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %tag2sempos = (
    'adj-C' => 'adj.quant.def',
    'adj-P' => 'adj.pron.def.demon',
    'adj'   => 'adj.denot',
    'n-P'   => 'n.pron.def.pers',
    'n-C'   => 'n.quant.def',
    'n'     => 'n.denot',
    'adv'   => 'adv.denot.grad.neg',
    'v'     => 'v',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode();

    return if ( $tnode->nodetype ne 'complex' or !$anode );

    my $syntpos = $tnode->formeme;
    $syntpos =~ s/:.*//;
    my $tag_key = $syntpos . '-' . substr( $anode->tag, 0, 1 );
    if ( $tag2sempos{$tag_key} ) {
        $tnode->set_gram_sempos( $tag2sempos{$tag_key} );
    }
    elsif ( $tag2sempos{$syntpos} ) {
        $tnode->set_gram_sempos( $tag2sempos{$syntpos} );
    }
    return;
}

1;
