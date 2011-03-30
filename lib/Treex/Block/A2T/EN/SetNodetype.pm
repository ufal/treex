package Treex::Block::A2T::EN::SetNodetype;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    my $functor = $t_node->functor;
    my $t_lemma = $t_node->t_lemma;
    my $nodetype;

    if ( $functor =~ /^(?:APPS|CONJ|DISJ|ADVS|CSQ|GRAD|REAS|CONFR|CONTRA|OPER)$/ ) {
        $nodetype = 'coap';
    }
    elsif ( $functor =~ /^(?:RHEM|PREC|PARTL|MOD|ATT|INTF|CM)$/ ) {
        $nodetype = 'atom';
    }
    elsif ( $t_lemma =~ m/^#(?:Idph|Forn)$/ ) {
        $nodetype = "list";
    }
    elsif ( $functor =~ m/^[FD]PHR$/ ) {
        $nodetype = lc $functor;
    }
    elsif ( $t_lemma =~ m/^#(?:AsMuch|Cor|EmpVerb|Equal|Gen|Oblfm|QCor|Rcp|Some|Total|Unsp|Amp|Ast|Percnt|Bracket|Comma|Colon|Dash|Period|Period3|Slash)$/ ) {
        $nodetype = 'qcomplex';
    }
    else {
        $nodetype = 'complex';
    }

    $t_node->set_nodetype($nodetype);

    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::SetNodetype

Value of the C<nodetype> attribute is filled (accordingly to the value of C<functor> and C<t_lemma>)
    in each SEnglishT node.

    =back
    =cut

    # Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
