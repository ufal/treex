package Treex::Block::T2A::EN::ImposeSubjpredAgr;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    foreach my $t_node ( $t_root->get_descendants() ) {
        if ( $t_node->formeme =~ /^v.+(fin|rc)/ ) {
            $self->process_finite_verb($t_node);
        }
    }
    return;
}

sub process_finite_verb {
    my ( $self, $t_vfin ) = @_;
    my $a_vfin = $t_vfin->get_lex_anode();

    # find the subject
    my $a_subj = find_a_subject_of($a_vfin);
    return if ( not $a_subj );

    # in relative clauses, the agreement is with the antecedents of the relative pronoun
    # -> use the antecedent as the subject (if it is set)
    if ( $a_subj->lemma =~ /^(who|that|which)/ ) {
        my ($t_subj) = $a_subj->get_referencing_nodes('a/lex.rf');
        if ( $t_subj and $t_subj->get_coref_gram_nodes() ) {
            my ($t_antec) = $t_subj->get_coref_gram_nodes();
            $a_subj = $t_antec->get_lex_anode() ? $t_antec->get_lex_anode : $a_subj;
        }
    }

    my $number = $a_subj->morphcat_number();
    $number = 'S' if ( $number !~ /[PS]/ );
    $number = 'P' if ( $a_subj->is_member() );
    $a_vfin->set_morphcat_number($number);

    my $person = $a_subj->morphcat_person();
    $person = '3' if ( $person !~ /[123]/ );
    $a_vfin->set_morphcat_person($person);
    return;
}

sub find_a_subject_of {
    my ($a_vfin) = @_;
    my @children = $a_vfin->get_echildren;
    my @subjects = grep { ( $_->afun || '' ) eq 'Sb' } @children;

    return $subjects[0] if (@subjects);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::ImposeSubjpredAgr

=head1 DESCRIPTION

Set person and number of verbs according to their subjects. 

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
