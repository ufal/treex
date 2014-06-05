package Treex::Block::A2T::SetFunctorsRules;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'formeme2functor' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_formeme2functor'
);

has 'tag2functor' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_tag2functor'
);

has 'aux2functor' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_aux2functor'
);

has 'lemma2functor' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_lemma2functor'
);

has 'afun2functor' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_afun2functor'
);

has 'temporal_nouns' => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    builder    => '_build_temporal_nouns'
);

has 'prep_when'  => ( 'isa' => 'Str', 'is' => 'ro', default => '^$' );
has 'prep_since' => ( 'isa' => 'Str', 'is' => 'ro', default => '^$' );
has 'prep_till'  => ( 'isa' => 'Str', 'is' => 'ro', default => '^$' );


sub process_tnode {

    my ( $self, $tnode ) = @_;

    if ( defined( $tnode->functor ) ) {
        return;
    }

    my $lex_anode = $tnode->get_lex_anode;

    if ( not defined $lex_anode ) {
        $tnode->set_functor('???');
        return;
    }
    my $afun           = $lex_anode->afun;
    my $mlemma         = lc $lex_anode->lemma;
    my @aux_a_nodes    = $tnode->get_aux_anodes();
    my $first_aux_prep = $self->get_first_aux_prep_lemma(@aux_a_nodes);
    my $functor;

    # main node of the sentence: PRED
    if ( $tnode->get_parent()->is_root() ) {
        $functor = 'PRED'
    }

    # solve temporal expressions
    elsif ( defined $self->temporal_nouns->{$mlemma} and ( not @aux_a_nodes or $first_aux_prep =~ $self->prep_when ) ) {
        $functor = "TWHEN";
    }
    elsif ( defined $self->temporal_nouns->{$mlemma} and $first_aux_prep =~ $self->prep_since ) {
        $functor = "TSIN";
    }
    elsif ( defined $self->temporal_nouns->{$mlemma} and $first_aux_prep eq $self->prep_till ) {
        $functor = "TTILL";
    }

    # use different mappings to set the functor (lemmas, tags, afuns, aux node lemmas)
    elsif ( $functor = $self->lemma2functor->{ $tnode->t_lemma } ) {
    }
    elsif ( $functor = $self->tag2functor->{ $lex_anode->tag } ) {
    }
    elsif ( defined $afun and $functor = $self->afun2functor->{$afun} ) {
    }
    elsif ( ($functor) = grep {$_} map { $self->aux2functor->{ $_->lemma } } @aux_a_nodes ) {
    }

    # try additional rules, such as ACT-PAT given diathesis, subject and object
    elsif ( $functor = $self->try_rules($tnode) ) {
    }

    # last: try formemes or resort to '???'
    elsif ( $functor = $self->formeme2functor->{ $tnode->formeme } ) {
    }
    else {
        $functor = '???';
    }

    $tnode->set_functor($functor);
}

# return the lemma of the first preposition or conjunction among the auxiliary nodes
sub get_first_aux_prep_lemma {
    my ( $self, @aux_a_nodes ) = @_;
    my $prep = first { $_->is_preposition() or $_->is_conjunction } @aux_a_nodes;
    return $prep ? $prep->lemma // '' : '';
}

# this should return a functor determined by the rules, or undef if not applicable
sub try_rules { return; }

# this should return hashrefs that do the mapping
sub _build_formeme2functor { return {} }

sub _build_tag2functor { return {} }

sub _build_afun2functor { return {} }

sub _build_lemma2functor { return {} }

sub _build_aux2functor { return {} }

sub _build_temporal_nouns { return {} }


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SetFunctorsRules

=head1 DESCRIPTION

A very basic block that sets functors using several simple rules. These require 
lists of applicable tags, lemmas, formemes etc. for a given language. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
