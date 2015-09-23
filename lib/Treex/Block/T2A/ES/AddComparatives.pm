package Treex::Block::T2A::ES::AddComparatives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if (($tnode->gram_degcmp || '') eq 'comp' && $tnode->t_lemma !~ /^(mayor|menos|mejor|peor|más)$/){
        my $anode = $tnode->get_lex_anode() or return;
        my $mas = $anode->create_child({
            lemma => 'más',
            form => 'más',
            afun => 'Adv',
        });
        $mas->shift_before_node($anode);
        $mas->iset->set_pos('adv');
        $tnode->add_aux_anodes($mas);
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddComparatives

=head1 DESCRIPTION

Add a-nodes "más" for comparative degree.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
