package Treex::Block::A2T::SetNodetype;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


# t-lemmas regexp for qcomplex nodes: punctuation and some generated nodes
Readonly my $QCOMPLEX_TLEMMA => "Oblfm|Benef|Total|Cor|EmpVerb|Gen|Whose|Why|QCor|Rcp|Equal|Where|How|When|Some|AsMuch|
Unsp|Amp|Ast|Deg|Percnt|Comma|Colon|Dash|Bracket|Period|Period3|Slash";


sub process_ttree {

    my ( $self, $t_root ) = @_;

    $t_root->set_nodetype('root');

    foreach my $t_node ( $t_root->get_descendants ) {
        $t_node->set_nodetype( $self->detect_nodetype($t_node) );
    }
}

# Detect the node type of an internal node
sub detect_nodetype {

    my ( $self, $t_node ) = @_;
    my $functor = $t_node->functor || '';
    my $t_lemma = $t_node->t_lemma;

    # coordinations
    if ( $functor =~ /^(APPS|CONJ|DISJ|ADVS|CSQ|GRAD|REAS|CONFR|CONTRA|OPER)/ ) {
        return 'coap';
    }

    # rhematizers
    elsif ( $functor =~ /^(RHEM|PREC|PARTL|MOD|ATT|INTF|CM)/ ) {
        return 'atom';
    }

    # foreign phrases, idioms
    elsif ( $functor =~ /^[FD]PHR$/ ) {
        return lc $t_node->functor;
    }

    # a-lemmas for semantically relevant punctuation (are not changed to t-lemmas by the current automatic analysis)
    elsif ( $t_lemma =~ /^(&|%|°|\*|\.|\.\.\.|:|,|;|-|–|\/|\()$/ ) {
        return 'qcomplex';
    }

    # t-lemmas for punctuation (PDT-style) and generated nodes
    elsif ( $t_lemma =~ /^#($QCOMPLEX_TLEMMA)$/s ) {
        return 'qcomplex';
    }

    # list structures
    elsif ( $t_lemma =~ /^#(Forn|Idph)/ ) {
        return 'list';
    }

    # default value
    else {
        return 'complex';
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SetNodetype

=head1 DESCRIPTION

The value of the C<nodetype> attribute is filled in each t-node according to its t-lemma or functor.

Depending on whether all functors are already set, the behavior of this block is different -- if only the coordination
functors are set, 'atom', 'fphr' and 'dphr' nodetypes are not distinguished. If no functors are set, not even the
'coap' nodetype is recognized.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
