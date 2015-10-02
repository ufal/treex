package Treex::Block::A2T::EU::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetFormeme';

# semantic adjectives
override 'get_aux_string' => sub {
    my ( $self, @anodes ) = @_;
    my $aux_string = join '_', map { lc $_->iset->case } @anodes;

    $aux_string=~ s/^_+//;
    $aux_string=~ s/_+$//;
    $aux_string=~ s/_+/_/;

    return $aux_string;
};

override 'formeme_for_adv' => sub {
    my ($self, $t_node, $a_node) = @_;

    # E.g. in Portuguese, it seems that adverbs may have prepositions,
    # e.g. "por(afun=AuxP) ali(afun=Adv,parent=por)"
    # Let's handle it here. If needed it is easy to override this method to return always 'adv'.
    my @a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    push @a_nodes, $a_node;
    push @a_nodes, grep {$_->afun eq "Atr"} $a_node->get_children();
    my $prep = $self->get_aux_string(@a_nodes);
    return "adv:$prep+X" if ($prep && $a_node->afun ne "Atr");
    return 'adv';
};

override 'formeme_for_noun' => sub {
    my ($self, $t_node, $a_node) = @_;

    # noun with a preposition (or postposition)
    my @a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    push @a_nodes, $a_node;
    push @a_nodes, grep {$_->afun eq "Atr"} $a_node->get_children();
    my $prep = $self->get_aux_string(@a_nodes);
    return "n:$prep+X" if ($prep && $a_node->afun ne "Atr");

    return super();
};

override 'formeme_for_adj' => sub {
    my ($self, $t_node, $a_node) = @_;

    my @a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    push @a_nodes, $a_node;
    push @a_nodes, grep {$_->afun eq "Atr"} $a_node->get_children();
    my $prep = $self->get_aux_string(@a_nodes);

    return "n:$prep+X" if ($prep && $a_node->afun ne "Atr"); # adjectives with prepositions are treated as a nominal usage
    return 'adj:poss'  if $a_node->match_iset(poss=>'poss', prontype=>'prs'); # possesive personal pronouns
    return 'adj:attr'  if $self->below_noun($t_node) || $self->below_adj($t_node);
    return 'n:subj'    if $a_node->afun eq 'Sb'; # adjectives in the subject positions -- nominal usage
    return 'adj:compl' if $self->below_verb($t_node);
    return 'adj:';
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EU::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of Spanish t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
