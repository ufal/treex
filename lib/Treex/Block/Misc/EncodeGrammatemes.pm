package Treex::Block::Misc::EncodeGrammatemes;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->t_lemma eq '#PersPron' ) {
        $tnode->set_t_lemma( $tnode->t_lemma . '|person=' . $tnode->gram_person );
    }
    if ( $tnode->is_clause_head and ( $tnode->sentmod // '' ) =~ /^(inter|imper)/ ) {
        $tnode->set_formeme( $tnode->formeme . '|sentmod=' . $tnode->sentmod );
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::EncodeGrammatemes

=head1 DESCRIPTION


=head1 AUTHOR


=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
