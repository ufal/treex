package Treex::Block::T2T::CS2EN::RemovePerspronGender;

use utf8;
use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
extends 'Treex::Core::Block';

has 'remove_guessed_gender' => ( isa => 'Bool', is => 'ro', default => 0 );

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # only personal pronouns whose source node is also a personal pronoun
    return if ( $t_node->t_lemma ne '#PersPron' );
    my $t_src = $t_node->src_tnode();
    return if ( !$t_src or $t_src->t_lemma ne '#PersPron' );

    # look at the source side: skip anything where we don't know the antecedent (or it is not a common noun)
    my @coref = $t_src->get_coref_chain( { ordered => 1 } );

    if ( !@coref ) {

        return if ( !$self->remove_guessed_gender );

        # even without antecedent: generated subjects -- remove gender if 'anim' was just guessed
        # good for IT domain (where things are concerned), not that good for news (where mostly persons are concerned)
        if ( ( $t_src->formeme // '' ) eq 'drop') {
            $t_node->set_gram_gender('nr');
        }
        return;
    }

    my @t_antecs = grep { $_->gram_sempos =~ /^n.denot/ } reverse @coref;
    if ( !@t_antecs ) {
        return if ( !$self->remove_guessed_gender );
        # remove the guessed gender
        $t_node->set_gram_gender('nr');
        return;
    }

    # skip anything that might refer to persons
    return if ( any {$_->is_name_of_person} @t_antecs );

    my @a_antecs = grep {defined $_} map {$_->get_lex_anode()} @t_antecs;
    my @n_antecs = grep {defined $_} map {$_->n_node} @a_antecs;

    return if ( any {$_->ne_type =~ /^[pP]/} @n_antecs );

    # remove the gender
    $t_node->set_gram_gender('nr');
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2EN::RemovePerspronGender

=head1 DESCRIPTION

Removing Czech genders of C<#PersPron>s that do not refer to persons. They
will default to neuter gender "it" in English.

This rule aims mainly for precision -- the antecedent must be set, and it must be
a noun, not a personal named entity (and C<is_name_of_person> must be false).

=head1 PARAMETERS

=over

=item remove_guessed_gender

A boolean indicating whether to remove gender that was simply guessed (without any
coreference links, mainly with generated subjects).
For the IT domain (i.e., text concerning things, not persons), it is good to remove guessed gender,
but this is sometimes bad for the news domain.

=back

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

