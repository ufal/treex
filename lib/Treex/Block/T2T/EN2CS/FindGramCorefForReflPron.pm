package Treex::Block::T2T::EN2CS::FindGramCorefForReflPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Focus on personal pronouns which are not in nominative case.
    return if $tnode->t_lemma ne '#PersPron';
    return if $tnode->formeme =~ /1/;
    my $perspron = $tnode;
    
    # Don't add gram coref where text coref is already detected.
    # T2T::EN2CS::TurnTextCorefToGramCoref will change the type later.
    # "They are angry if you steal their[text_coref=They] cars."
    # We don't want to make "their" coreferent with "you".
    #return if $perspron->get_coref_text_nodes();
    # Unfortunatelly, the quality of current English text coref
    # (using A2T::EN::FindTextCoref) is low, so it is better to ignore it.
    # BTW: after adding check for agreement in person, "their" cannot be coreferent with "you".

    my $clause_head = $perspron->get_clause_ehead() or return;

    # TODO: Should we use get_echildren here?
    my $subject = first { ( $_->formeme || '' ) =~ /1/ } $clause_head->get_echildren();
    return if !$subject;
    if (all {$self->agree_in($_, $perspron, $subject)} qw(gender number person)){
        $perspron->add_coref_gram_nodes($subject);
    }
 
    return;
}

sub agree_in {
    my ($self, $category, $perspron, $antec) = @_;
    my $pron_cat  = $perspron->get_attr("gram/$category") || '';
    my $antec_cat = $antec->get_attr("gram/$category") || '';
    return 0 if $category eq 'person' && !$antec_cat && $pron_cat =~ /1|2/;
    return 1 if !$pron_cat || !$antec_cat;
    return 1 if $pron_cat eq $antec_cat;
    return 1 if $category eq 'gender' && all {$_ =~ /inan|anim/} ($pron_cat, $antec_cat);
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::FindGramCorefForReflPron

=head1 DESCRIPTION

Make co-reference links from personal pronouns to their antecedents,
if the latter ones are in subject position. This is neccessary because
of Czech pronoun 'reflexivization' (subclass of grammatical coreference).

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008,2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
