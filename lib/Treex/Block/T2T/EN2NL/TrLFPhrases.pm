package Treex::Block::T2T::EN2NL::TrLFPhrases;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

# two English words, child t-lemma + formeme & parent t-lemma --> one Dutch t-lemma + mlayer_pos
my %CHILD_PARENT_TO_ONE_NODE = (
    'sure|adj:compl make'  => 'controleren|verb',
    'output|n:attr device' => 'uitvoer_apparaat|noun',
    'email|n:attr client' => 'email_programma|noun',
    'security|n:attr reason' => 'veiligheid_reden|noun',
    'business|n:attr environment' => 'onderneming_klimaat|noun',
    'mouse|n:attr button' => 'muis_knop|noun',
);

# one English t-lemma + syntpos --> Dutch child (t-lemma, formeme, mlayer_pos) + parent (t-lemma, mlayer_pos)
my %ONE_NODE_TO_CHILD_PARENT = (
    'need|v:fin' => 'nodig|n:predc|adj hebben|verb',
);

sub process_ttree {
    my ( $self, $troot ) = @_;

    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
        $self->try_2to1($tnode);
    }

# (This does not work well, and Alpino has a hack for that)
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

# (This does not work well, and Alpino has a hack for that)
#        # need to -> moeten
#        if ( $src_parent->t_lemma eq 'need' and $src_parent->formeme =~ /v:.*fin/ and $src_tnode->formeme eq 'v:to+inf' and $tnode->formeme =~ /^v/ ) {
#
#            $parent->set_t_lemma( 'moeten' );
#            $parent->set_t_lemma_origin('rule-TrLFPhrases');
#            return;
#        }

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

# Try translating 1 node into 2 -- adding a new node
sub try_1to2 {
    my ( $self, $tnode ) = @_;
    return if ( $tnode->t_lemma_origin eq 'rule-TrLFPhrases' );
    my $src_tnode = $tnode->src_tnode() or return 0;

    my $id = $src_tnode->t_lemma . '|' . $src_tnode->formeme;
    $id =~ s/:.*\+/:/;
    if ( my $translation = $ONE_NODE_TO_CHILD_PARENT{$id} ) {
        my ( $child_info, $node_info ) = split / /, $translation;

        my ( $t_lemma, $formeme, $mlayer_pos ) = split /\|/, $child_info;
        my $child = $tnode->create_child(
            {
                t_lemma        => $t_lemma,
                formeme        => $formeme,
                mlayer_pos     => $mlayer_pos,
                t_lemma_origin => 'rule-TrLFPhrases',
                formeme_origin => 'rule-TrLFPhrases',
                clause_number  => $tnode->clause_number,
                nodetype       => 'complex',
            }
        );
        $child->shift_after_node($tnode);

        ( $t_lemma, $mlayer_pos ) = split /\|/, $node_info;
        $tnode->set_t_lemma($t_lemma);
        $tnode->set_attr( 'mlayer_pos', $mlayer_pos );
        $tnode->set_t_lemma_origin('rule-TrLFPhrases');
        return;
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2NL::TrLFPhrases

=head1 DESCRIPTION

Rule-based translation of cases which the translation models can't handle (where 2 nodes 
should map onto 1 or 1 node into 2).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
