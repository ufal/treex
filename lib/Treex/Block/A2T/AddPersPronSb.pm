package Treex::Block::A2T::AddPersPronSb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has formeme_for_dropped_subj => (is=>'ro', default=>'n:subj'); # or 'drop'

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Process finite verbs that miss a (dropped) subject.
    return if !$self->is_finite_verb($t_node);
    return if !$self->needs_subject($t_node);
               
    my $new_node = $t_node->create_child({
        t_lemma => '#PersPron',
        functor => 'ACT',
        formeme => $self->formeme_for_dropped_subj,
        nodetype => 'complex',
        'gram/sempos' => 'n.pron.def.pers',
        set_is_generated => 1,
    });
    $new_node->shift_before_node($t_node);
    $self->fill_grammatemes($new_node);
    return;
}

sub is_finite_verb {
    my ($self, $t_node) = @_;
    return $t_node->formeme =~ /^v.+(fin|rc)/ ? 1 : 0;
}

sub needs_subject {
    my ($self, $t_node) = @_;

    # TODO: See A2T::CS::AddPersPronSb 
    #return 0 if !$t_node->is_clause_head;
    #return 0 if is_passive_having_PAT($t_node);
    #return 0 if is_active_having_ACT($t_node);
    #return 0 if is_GEN($t_node);
    #return 0 if is_IMPERS($t_node);

    my $a_node = $t_node->get_lex_anode();
    return 0 if !$a_node;
    return 0 if any { ( $_->afun || '' ) eq 'Sb' } $a_node->get_echildren;
    return 1;
}

sub fill_grammatemes {
    my ($self, $subject) = @_;
    my $verb = $subject->get_parent();
    for my $grammateme (qw(gender number person)){
        $subject->set_attr("gram/$grammateme", $verb->get_attr("gram/$grammateme"));
    }
    return;
}


1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::AddPersPronSb - add "dropped" subject

=head1 DESCRIPTION

New t-nodes with t_lemma #PersPron corresponding to unexpressed ('pro-dropped') subjects of finite clauses
are added.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
