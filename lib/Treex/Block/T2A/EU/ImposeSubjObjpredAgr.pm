package Treex::Block::T2A::EU::ImposeSubjObjpredAgr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Find finite verbs
    return if !$self->is_finite_verb($t_node);
    my $t_vfin = $t_node;
    my $a_vfin = $t_vfin->get_lex_anode() or return;

    # Find their ergative childs
    my $t_erg = first {$_->formeme =~ /:\[erg\]\+X/} $t_node->get_children();

    if (defined $t_erg) {
	my $a_erg = $t_erg->get_lex_anode();

	# Fill the categories, use sane defaults (singular, 3rd person)
	my $number = $a_erg->iset->number || 'sing';
	$number = 'plur' if $a_erg->is_member();
	#$a_vfin->iset->set_ergnumber($number);
	$a_vfin->iset->set_number($number);
	$a_erg->set_afun('Sb');

	my $person = $a_erg->iset->person || '3';
	#$a_vfin->iset->set_ergperson($person);
	$a_vfin->iset->set_person($person);
	$a_erg->set_afun('Sb');
    }

    # Find their absolutive childs
    my $t_abs = first {$_->formeme =~ /:\[abs\]\+X/} $t_node->get_children();

    if (defined $t_abs) {
	my $a_abs = $t_abs->get_lex_anode();

	# Fill the categories, use sane defaults (singular, 3rd person)
	my $person = $a_abs->iset->person || '3';
	my $number = $a_abs->iset->number || 'sing';
	$number = 'plur' if $a_abs->is_member();
	if ($a_vfin->iset->person) {
	    $a_vfin->iset->set_absperson($person);
	    $a_vfin->iset->set_absnumber($number);
	    $a_abs->set_afun('Obj');
	} else {
	    $a_vfin->iset->set_person($person);
	    $a_vfin->iset->set_number($number) if (! $a_vfin->iset->number);
	    $a_abs->set_afun('Sb');
	}    
    }

    # Find their dative childs
    my $t_dat = first {$_->formeme =~ /:\[dat\]\+X/} $t_node->get_children();

    if (defined $t_dat) {
	my $a_dat = $t_dat->get_lex_anode();

	my $number = $a_dat->iset->number || 'sing';
	$number = 'plur' if $a_dat->is_member();
	$a_vfin->iset->set_datnumber($number);

	my $person = $a_dat->iset->person || '3';
	$a_vfin->iset->set_datperson($person);
    }

    return;
}

sub is_finite_verb {
    my ($self, $t_node) = @_;
    return $t_node->formeme =~ /^v.+(fin|rc)/ ? 1 : 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::ImposeSubjObjpredAgr - subject-predicate agreement

=head1 DESCRIPTION

Set number and person of verbs according to their subjects and objects.
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
