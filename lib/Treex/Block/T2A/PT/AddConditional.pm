package Treex::Block::T2A::PT::AddConditional;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->functor eq 'COND'){
    	
        my $a_node = $tnode->get_lex_anode() or return;

        my $conditional = $a_node->create_child({
            'lemma'        => 'se',
            'form'         => 'se',
            'afun'         => 'AuxC',
        });

        $conditional->shift_before_subtree($a_node);
        $tnode->add_aux_anodes($conditional);
        return;

    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::AddConditional

=head1 DESCRIPTION

Creates an auxilary node for the Portuguese conditional 'se'

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



