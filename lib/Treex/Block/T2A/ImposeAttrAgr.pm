package Treex::Block::T2A::ImposeAttrAgr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Process only congruent adjectives (and possesives etc.)
    return if !$self->should_agree_with_parent($t_node);

    # Find the governing noun
    my $a_attr = $t_node->get_lex_anode() or return;
    my $a_noun = $self->find_a_governing_noun($a_attr, $t_node) or return;

    # Impose the agreement (copy Interset features gender, number, case)
    $self->impose_agreement($a_attr, $a_noun, $t_node);

    return;
}

sub should_agree_with_parent {
    my ($self, $t_node) = @_;
    return $t_node->formeme =~ /attr|poss|compl/ ? 1 : 0;
}

sub find_a_governing_noun {
    my ($self, $a_attr, $t_attr) = @_;
    my ($a_noun) = $a_attr->get_eparents();
    return if $a_noun->is_root;
    return $a_noun;
}

sub impose_agreement {
    my ($self, $a_attr, $a_noun, $t_attr) = @_;

    # By default, the imposed categories are: gender, number, case.
    my @categories = qw(gender number case);

    # However, for nouns in attributive position, it is just the case.
    if ( $t_attr->formeme eq 'n:attr' ) {
        @categories = qw(case);
    }

    # Copy the Interset features.
    foreach my $cat (@categories) {
        $a_attr->set_iset($cat, $a_noun->get_iset($cat));
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ImposeAttrAgr - noun-adjective agreement

=head1 DESCRIPTION

Set gender, number and case of adjectives according to their governing nouns.

This implementation takes care also of complement agreement.
e.g. "Cars(parent=are,number=plural) are nice(formem=adj:compl,parent=are)"
(In English, there is no agreement with adjectives, but let's have it as an example.)
However, you need to run C<T2A::ImposeSubjpredAgr> (or something equivalent)
B<before> this block, so the verb ("are") a-node has all the categories.
In this case, the method C<find_a_governing_noun> will actually return the veb ("are").

In some languages (Portuguese), verbs have no gender, but you need noun-complement agreement in gender.
E.g. "A camisola é amarela". In this case, C<T2A::ImposeSubjpredAgr> must assign the feminine gender
to the verb ("é"), so C<T2A::ImposeAttrAgr> can propagate it to the complement adjective ("amarela").
If needed, you can easily delete the gender from verbs later.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
