package Treex::Block::T2A::ImposeSubjpredAgr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Find finite verbs
    return if !$self->is_finite_verb($t_node);
    my $t_vfin = $t_node;
    my $a_vfin = $t_vfin->get_lex_anode() or return;

    # Find their subject
    my $a_subj = $self->find_a_subject_of($a_vfin) or return;

    # Fill the categories, use sane defaults (singular, 3rd person)
    if (my $gender = $a_subj->iset->gender){
        $a_vfin->iset->set_gender($gender);
    }

    my $number = $a_subj->iset->number || 'sing';
    $number = 'plu' if $a_subj->is_member();
    $a_vfin->iset->set_number($number);

    my $person = $a_subj->iset->person || '3';
    $a_vfin->iset->set_person($person);
    return;
}

sub is_finite_verb {
    my ($self, $t_node) = @_;
    return $t_node->formeme =~ /^v.+(fin|rc)/ ? 1 : 0;
}

sub find_a_subject_of {
    my ($self, $a_vfin) = @_;
    return first { ( $_->afun || '' ) eq 'Sb' } $a_vfin->get_echildren;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ImposeSubjpredAgr - subject-predicate agreement

=head1 DESCRIPTION

Set gender, number and person of verbs according to their subjects.
By default only finite verbs are processed.
Coordinated subjects imply plural verb.

In some languages (Portuguese), verbs have no gender, but you need noun-complement agreement in gender.
E.g. "A camisola é amarela". In this case, C<T2A::ImposeSubjpredAgr> must assign the feminine gender
to the verb ("é"), so C<T2A::ImposeAttrAgr> can propagate it to the complement adjective ("amarela").
If needed, you can easily delete the gender from verbs later.


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
