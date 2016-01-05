package Treex::Block::Write::LayerAttributes::BracketedVerbform;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'use_aligned_golden' => ( is => 'ro', isa => 'Bool', default => 0 );

sub modify_single {

    my ( $self, $tnode ) = @_;

    return '' if ( ( $tnode->gram_sempos || '' ) ne 'v' );

    if ( $self->use_aligned_golden ) {
        my ($aligned) = $tnode->get_directed_aligned_nodes();
        $aligned = first { ( $_->gram_sempos || '' ) eq 'v' } @{$aligned};
        if ($aligned) {
            $tnode = $aligned;
        }
    }

    my $lex = $tnode->get_lex_anode();

    return '' if ( !$lex );

    my $root = $lex->get_root();
    my %anodes = map { $_->id => 1 }
        grep { ( $_->afun || '' ) =~ m/^Aux[RV]$/ || _get_tag($_) =~ m/^V/ } $tnode->get_aux_anodes();
    $anodes{ $lex->id } = 2;

    return _get_subtree( $root, \%anodes );
}

sub _get_subtree {

    my ( $node, $find ) = @_;
    my @left  = $node->get_children( { preceding_only => 1 } );
    my @right = $node->get_children( { following_only => 1 } );

    if ( $find->{ $node->id } ) {

        my $tag = _get_tag($node);
        log_info( $node->get_address() ) if ( !$tag );
        my $lemma = $find->{ $node->id } eq '2' ? '_L' : $node->lemma;

        $lemma = '_M' if ( Treex::Tool::Lexicon::CS::is_modal_verb($lemma) );
        $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma);

        $tag =~ s/^(..)......(.).(..).*$/$1$2$3/;    # POS, SubPOS, Tense, Negation, Voice

        return '(' . join( '', map { _get_subtree( $_, $find ) } @left )
            . $tag . ' ' . $lemma
            . join( '', map { _get_subtree( $_, $find ) } @right ) . ')';
    }

    return join( '', map { _get_subtree( $_, $find ) } @left ) . join( '', map { _get_subtree( $_, $find ) } @right );
}

Readonly my @MORPHCAT_TO_TAG => qw(pos subpos gender number case possgender possnumber
    person tense grade negation voice reserve1 reserve2 variant);

sub _get_tag {
    my ($node) = @_;

    return $node->tag if ( $node->tag );

    my %morphcat;
    foreach my $cat (@MORPHCAT_TO_TAG) {
        $morphcat{$cat} = $node->get_attr("morphcat/$cat") || '.';
    }
    return join q{}, map { $morphcat{$_} } @MORPHCAT_TO_TAG;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::BracketedVerbform

=head1 DESCRIPTION

For a given Czech verbal t-node, output the corresponding compound verbform on the a-layer (as bracketed tree,
auxiliary verb lemmas (except the modal verb) and partial tags of all forms, thus marking POS, 
SubPOS, Tense, Voice, and Negation)

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
