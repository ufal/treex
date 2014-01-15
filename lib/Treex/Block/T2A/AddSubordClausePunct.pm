package Treex::Block::T2A::AddSubordClausePunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'open_punct' => ( is => 'ro', 'isa' => 'Str', default => '^[‘“]$' );

has 'close_punct' => ( is => 'ro', 'isa' => 'Str', default => '^[’”]$' );

sub process_zone {

    my ( $self, $zone ) = @_;
    my ( $open_punct, $close_punct ) = ( $self->open_punct, $self->close_punct );

    my $aroot          = $zone->get_atree();
    my @anodes         = $aroot->get_descendants( { ordered => 1 } );
    my @clause_numbers = map { $_->clause_number } @anodes;
    ##my @afuns          = map { $_->afun || '' } @anodes;
    my @lemmas = map { lc( $_->lemma || '' ) } @anodes;
    push @lemmas, 'dummy';

    foreach my $i ( 0 .. $#anodes - 1 ) {

        # Skip if we are not at the clause boundary
        next if $clause_numbers[$i] == $clause_numbers[ $i + 1 ];

        # Skip words with clause_number=0 (e.g. brackets separating clauses)
        next if !$clause_numbers[ $i + 1 ];

        # Now, we are at the clause boundary
        # ($nodes[$i] and $nodes[$i+1] have different clause_number).
        # However, on some boundaries the comma is not needed/allowed:

        # left or right token is a punctuation (e.g. three dots)
        next if any { $_ =~ /^[,:;.?!-]/ } @lemmas[ $i, $i + 1 ];

        # left token is an opening quote or bracket
        next if $lemmas[$i] =~ /$open_punct/ || $lemmas[$i] eq '(';

        # right token is a closing bracket or quote followed by period (end of sentence)
        next if $lemmas[ $i + 1 ] eq ')' || ( $lemmas[ $i + 1 ] =~ /$close_punct/ && $lemmas[ $i + 2 ] eq '.' );

        # left token is a closing quote or bracket preceeded by a comma (inserted in the last iteration)
        next if ( $lemmas[$i] =~ /$close_punct/ || $lemmas[$i] eq ')' ) && $i && $anodes[$i]->get_prev_node->lemma eq ',';

        # any other language-dependent reason (e.g. coordinations)
        next if $self->no_comma_between( $anodes[$i], $anodes[ $i + 1 ] );

        # Comma's parent should be the highest of left/right clause roots
        my $left_clause_root  = $anodes[$i]->get_clause_root();
        my $right_clause_root = $anodes[ $i + 1 ]->get_clause_root();
        my $the_higher_clause_root =
            $left_clause_root->get_depth() > $right_clause_root->get_depth()
            ? $left_clause_root : $right_clause_root;

        my $comma = $the_higher_clause_root->create_child(
            {   'form'          => ',',
                'lemma'         => ',',
                'afun'          => 'AuxX',
                'morphcat/pos'  => 'Z',
                'clause_number' => 0,
            }
        );

        $comma->shift_after_node( $anodes[$i] );

        $self->postprocess_comma( $anodes[$i], $comma );

    }

    $self->postprocess_sentence($aroot);
    return;
}

# To be overridden in language-specific blocks
sub no_comma_between {
    my ( $self, $left_node, $right_node ) = @_;
    return 0;
}

sub postprocess_comma {
    my ( $self, $anode, $comma ) = @_;
    return;
}

sub postprocess_sentence {
    my ( $self, $aroot ) = @_;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSubordClausePunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas on clause boundaries
(boundaries of relative clauses as well as
of clauses introduced with subordination conjunction).

This block contains language-independent code, it is to be overridden
for individual languages.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
