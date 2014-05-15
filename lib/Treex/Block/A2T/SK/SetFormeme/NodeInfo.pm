package Treex::Block::A2T::SK::SetFormeme::NodeInfo;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::CS::SetFormeme::NodeInfo';

# Slovak-specific syntpos (needs lemmas)
override '_build_syntpos' => sub {
    my ($self) = @_;

    # skip technical root, conjunctions, prepositions, punctuation etc.
    return '' if ( $self->t->is_root or $self->tag =~ m/^.[%^#,FRVXc:]/ );

    # adjectives, adjectival numerals and pronouns
    return 'adj' if ( $self->tag =~ m/^.[\}=\?148ACDGLOSUadhklnrwyz]/ );

    # indefinite and negative pronous cannot be disambiguated simply based on POS (some of them are nouns)
    return 'adj' if ( $self->tag =~ m/^.[WZ]/ and $self->lemma =~ m/(žiadny|žiaden|čí|aký|ktorý|koľvek)$/ );

    # adverbs, adverbial numerals ("dvakrát" etc.),
    # including interjections and particles (they behave the same if they're full nodes on t-layer)
    return 'adv' if ( $self->tag =~ m/^.[\*bgouvTI]/ );

    # verbs
    return 'v' if ( $self->tag =~ m/^V/ );

    # everything else are nouns: SubPOS -- 56789EHPNJQYj@X, no POS (possibly -- generated nodes)
    return 'n';
};

override '_aux_tag' => sub {
    my ( $self, $anode ) = @_;
    return $anode->wild->{tag_cs_pdt};
};

override '_aux_lemma' => sub {
    my ( $self, $anode ) = @_;
    my $lemma = $anode->lemma;
    $lemma =~ s/^byť$/být/;
    return $lemma;
};

override '_build_tag' => sub {
    my ($self) = @_;
    return '' if ( !$self->a );

    my ( $pdt_tag, $lemma, $snk_tag ) = (
        $self->a->wild->{tag_cs_pdt} // '',
        $self->a->lemma              // '',
        $self->a->tag                // ''
    );

    if ( $snk_tag =~ /P[FU]/ and $lemma =~ m/(môj|tvôj|jeho|svoj|jej|náš|váš|ich)$/ ) {
        $pdt_tag =~ s/^../PS/;
    }
    elsif ( $snk_tag =~ /^AF/ ) {
        $pdt_tag =~ s/^../AU/;
    }
    return $pdt_tag;
};

override '_build_trunc_lemma' => sub {
    my ($self) = @_;
    return $self->lemma;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::SetFormeme::NodeInfo

=head1 SYNOPSIS

    my $node_info = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( t => $t_node );

    print( $node_info->sempos . ' '. $node_info->prep . ' ' . $node_info->case );

=head1 DESCRIPTION

A helper object for L<Treex::BLock::A2T::CS::SetFormeme> that collects all the needed information for a node from
both t-layer and a-layer, including preposition and case collected from aux-nodes and surroundings of the node.

All values except C<a> and C<aux> are always set (albeit sometimes empty), so no further checking is required.

=head1 TODO

Remove the dependency to Treex::Block::A2T::CS::FixNumerals by creating a common library (where?)

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
