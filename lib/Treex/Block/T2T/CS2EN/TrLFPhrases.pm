package Treex::Block::T2T::CS2EN::TrLFPhrases;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

# two Czech words, child t-lemma + formeme & parent t-lemma --> one English t-lemma + mlayer_pos
my %CHILD_PARENT_TO_ONE_NODE = (
    'nástroj|n:2 panel'  => 'toolbar|noun',
);

sub process_ttree {
    my ( $self, $troot ) = @_;

    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
        $self->try_2to1($tnode);
    }

#    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
#        $self->try_1to2($tnode);
#    }
    return;
}

# Translate 2 nodes to 1 -- try merging the node with its parent
sub try_2to1 {

    my ( $self, $tnode ) = @_;
    my $src_tnode  = $tnode->src_tnode() or return 0;
    my $parent     = $tnode->get_parent();
    my $src_parent = $src_tnode->get_parent();

    if ( !$parent->is_root and $parent->t_lemma_origin ne 'rule-TrLFPhrases' ) {

        # dictionary rules
        my $id = $src_tnode->t_lemma . '|' . $src_tnode->formeme . ' ' . $src_parent->t_lemma;

        if ( my $translation = $CHILD_PARENT_TO_ONE_NODE{$id} ) {
            my ( $t_lemma, $mlayer_pos ) = split /\|/, $translation;

            $parent->set_t_lemma($t_lemma);
            $parent->set_attr( 'mlayer_pos', $mlayer_pos );
            $parent->set_t_lemma_origin('rule-TrLFPhrases');

            map { $_->set_parent($parent) } $tnode->get_children();
            $tnode->remove();
            return;
        }
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::TrLFPhrases

=head1 DESCRIPTION

Rule-based translation of cases which the translation models can't handle (where 2 nodes 
should map onto 1 or 1 node into 2).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
