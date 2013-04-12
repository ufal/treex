package Treex::Block::T2T::PosFromTLemma;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;
    my $lemma = $node->t_lemma;
    if ($lemma =~ s/#(.)$//){
        $node->set_attr('mlayer_pos', $1);
        $node->set_t_lemma($lemma);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PosFromTLemma - fill mlayer_poss attribute

=head1 DESCRIPTION

Attribute mlayer_pos is a temporary solution to encode morphological part-of-speech tag into t-layer.
This simple block expects t_lemmas with added # and mlayer_pos (e.g. pes#N) and converts them
to normal t_lemmas (pes) and a separate attribute mlayer_pos (N).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
