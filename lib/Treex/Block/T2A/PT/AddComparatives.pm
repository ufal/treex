package Treex::Block::T2A::PT::AddComparatives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if ($tnode->gram_degcmp eq 'comp' && $tnode->t_lemma !~ /^(maior|melhor)$/){
        my $anode = $tnode->get_lex_anode() or return;
        my $mais = $anode->create_child({
            lemma => 'mais',
            form => 'mais',
            afun => 'Adv',
        });
        $mais->shift_before_node($anode);
        $mais->iset->set_pos('adv');
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::PT::AddComparatives

=head1 DESCRIPTION

Add a-nodes "mais" for comparative degree.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
