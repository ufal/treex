package Treex::Block::Print::VectorsForTM;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::TranslationModel::Features::EN;
binmode STDOUT, ':utf8';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    my ($en_tnode) = $cs_tnode->get_aligned_nodes_of_type('int');
    return if !$en_tnode;
    my $cs_anode = $cs_tnode->get_lex_anode or return;

    #return if $en_tnode->functor =~ /CONJ|DISJ|ADVS|APPS/;
    my $en_tlemma = $en_tnode->t_lemma;
    my $cs_tlemma = $cs_tnode->t_lemma;
    return if $en_tlemma !~ /\p{IsL}/ || $cs_tlemma !~ /\p{IsL}/;

    my $features_rf =
        Treex::Tool::TranslationModel::Features::EN::features_from_src_tnode( $en_tnode, { encode => 1 } ) or return;
    my ($cs_mlayer_pos) = ( $cs_anode->tag =~ /^(.)/ );

    print join "\t", (
        lc($en_tlemma),
        $cs_tlemma . "#" . $cs_mlayer_pos,
        $en_tnode->formeme,
        $cs_tnode->formeme,
        join ' ', map {"$_=$features_rf->{$_}"} keys %{$features_rf}
    );
    print "\n";
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::VectorsForTM - print features for training translation models

=head1 DESCRIPTION

For each node, one line is printed
TODO

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
