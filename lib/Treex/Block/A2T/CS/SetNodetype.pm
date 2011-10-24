package Treex::Block::A2T::CS::SetNodetype;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Use functors in deciding the node type? If set to 0, this won't be dependent on functors, but some nodetypes will not be applied
has 'use_functors' => ( isa => 'Bool', is => 'ro', default => 1 );

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

    # coordinations based on functors
    if ( $self->use_functors and $t_node->functor =~ /^(APPS|CONJ|DISJ|ADVS|CSQ|GRAD|REAS|CONFR|CONTRA|OPER)/ ) {
        return 'coap';
    }

    # rhematizers
    elsif ( $self->use_functors and $t_node->functor =~ /^(RHEM|PREC|PARTL|MOD|ATT|INTF|CM)/ ) {
        return 'atom';
    }

    # foreign phrases
    elsif ( $self->use_functors and $t_node->functor =~ /^FPHR$/ ) {
        return 'fphr';
    }

    # idioms
    elsif ( $self->use_functors and $t_node->functor =~ /^DPHR$/ ) {
        return 'dphr';
    }

    # coordinations simply based on morphology (only if the functors are not be used or are not set)
    elsif ( ( !$self->use_functors or !$t_node->functor ) and $t_node->get_lex_anode and $t_node->get_lex_anode->afun =~ /^(Coord|Apos)/ ) {
        return 'coap';
    }

    # a-lemmas for semantically relevant punctuation -- not modified by the current automatic analysis
    elsif ( $t_node->t_lemma =~ /^(&|%|\*|\.|\.\.\.|:|,|;|-|–|\/|\()$/ ) {
        return 'qcomplex';
    }

    # t-lemmas for punctuation (PDT-style) and generated nodes
    elsif ( $t_node->t_lemma =~ /^#(Benef|Total|Cor|EmpVerb|Gen|Whose|Why|QCor|Rcp|Equal|Where|How|When|Some|AsMuch|Unsp|Amp|Ast|Deg|Percnt|Comma|Colon|Dash|Bracket|Period|Period3|Slash)/ ) {
        return 'qcomplex';
    }

    # list structures
    elsif ( $t_node->t_lemma =~ /^\#(Forn|Idph)/ ) {
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

Treex::Block::A2T::CS::SetNodetype

=head1 DESCRIPTION

Value of the C<nodetype> attribute is filled in each Czech t-node.

=head1 PARAMETERS

=over

=item C<use_functors>

If set 0, functors will not be used in determining the C<nodetype>. The block will not then depend on C<functor> values,
but some of the C<nodetype> values will remain unused. Defaults to C<1>. 

=back

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
