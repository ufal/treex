package Treex::Block::T2A::PT::AddVerbNegation;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # select only negated verbs
    return if ( ( $t_node->gram_sempos || '' ) !~ /^v/ or ( $t_node->gram_negation || '' ) ne 'neg1' );
    my $a_node = $t_node->get_lex_anode() or return;

    # create the particle 'not'
    my $neg_node = $a_node->create_child(
        {
            'lemma'        => 'não',
            'form'         => 'não',
            'afun'         => 'Neg',
            'morphcat/pos' => '!',
        }
    );
    $neg_node->shift_before_node($a_node);
    $t_node->add_aux_anodes($neg_node);


    return;


}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::AddVerbNegation

=head1 DESCRIPTION

Creates the particle 'não' corresponding to the negation of the negated verb

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
