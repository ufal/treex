package Treex::Block::T2T::FixGrammatemesAfterTransfer;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $t_src = $t_node->src_tnode or return;
    
    $self->_fix_valid_grammatemes( $t_node, $t_src );

    $self->_fix_negation( $t_node, $t_src );

    $self->_fix_number( $t_node, $t_src );
    
    $self->_fix_degcmp( $t_node, $t_src );

    return;
}

# To be overridden
sub _fix_negation {
    my ( $self, $t_node, $t_src ) = @_;
    return;
}

# To be overridden
sub _fix_number {
    my ( $self, $t_node, $t_src ) = @_;
    return;
}

# To be overridden
sub _fix_degcmp {
    my ( $self, $t_node, $t_src ) = @_;
    return;
}

# Filter valid grammatemes according to the new synt. part-of-speech
sub _fix_valid_grammatemes {

    my ( $self, $t_node, $src_t_node ) = @_;

    my $formeme = $t_node->formeme;
    my $src_formeme = $src_t_node->formeme;

    if ( $formeme !~ /^v/ ) {
        $t_node->set_voice(undef);
        $t_node->set_is_passive(undef);
    }

    # Target nouns
    if ( $formeme =~ /^n/ and $src_formeme !~ /^(n|drop|adj:poss)/ ) {
        #$t_node->set_gram_sempos('n.denot');
        $t_node->set_gram_number('sg') if ($t_node->gram_number || '') ne 'pl';
        # we're keeping degcmp since it hurts with some NNPs such as High Court
        foreach my $gram (qw(diathesis verbmod deontmod tense aspect resultative dispmod iterativeness person)) {
            $t_node->set_attr( "gram/$gram", undef );
        }
    }

    # Source verbs, target adjectives or adverbs
    # TODO correcting nouns -> adjectives, adverbs causes problems; adding degcmp, too
    if ( $formeme =~ /^ad[jv]/ and $src_formeme =~ /^v/ ) {

        $t_node->set_gram_sempos( $formeme =~ /^adj/ ? 'adj.denot' : 'adv.denot.grad.neg' );

        foreach my $gram (qw(diathesis verbmod deontmod tense aspect resultative dispmod iterativeness person)) {
            $t_node->set_attr( "gram/$gram", undef );
        }
    }

    # Delete all grammatemes for 'x'
    if ( $formeme eq 'x' && $src_formeme ne 'x' ) {
        $t_node->set_attr( "gram", undef );
    }
    return;
}



1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::FixGrammatemesAfterTransfer

=head1 DESCRIPTION

Handle necessary changes in grammatemes after transfer. This base class only limits
the set of possible grammatemes when part-of-speech is changed in translation.

Language-specific blocks should add their particular changes for number, negation,
and degree of comparison.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
