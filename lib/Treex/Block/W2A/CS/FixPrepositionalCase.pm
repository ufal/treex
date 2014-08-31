package Treex::Block::W2A::CS::FixPrepositionalCase;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;

use CzechMorpho;

extends 'Treex::Core::Block';

has '_analyzer' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub { CzechMorpho::Analyzer->new() } );

sub process_anode {

    my ( $self, $anode ) = @_;

    return if ( $anode->is_root );

    my ($aparent) = $anode->get_eparents( { or_topological => 1 } );

    return if ( $aparent->is_root );

    # capture only prepositional groups ...
    if ( $aparent->tag !~ m/[NAC]/ and $aparent->afun eq 'AuxP' and $anode->afun ne 'AuxP' ) {

        my ($case)     = ( $anode->tag   =~ m/^[NAPC]...([1-7])/ );
        my ($prepcase) = ( $aparent->tag =~ m/....([^X])/ );

        # where the case is not right ...
        if ( $case and $prepcase and $prepcase ne $case ) {

            # and try to correct it
            $self->_try_correct_case( $anode, $aparent, $case, $prepcase );
        }
    }
    return;
}

# Try to correct the case indication if it is not consistent with the preposition
sub _try_correct_case {

    my ( $self, $word, $prep, $wordcase, $prepcase ) = @_;

    my ( $pos, $num, $gen ) = ( $word->tag =~ m/(.).(.)(.)/ );
    my ( $tags_word, $lemmas_word ) = $self->_get_possible_cases( $word->form, $pos, $num, $gen, $word->lemma );
    my ( $tags_prep, $lemmas_prep ) = $self->_get_possible_cases( $prep->form, 'R' );

    # correct the tag: use the preposition's case if it's OK with the word form
    if ( $tags_word->{$prepcase} ) {
        $word->set_tag( $tags_word->{$prepcase} );
        $word->set_lemma( $lemmas_word->{$prepcase} );
        return;
    }

    # do not correct anything if the form would be 's' with genitive/accusative
    return if ( $prep->form =~ m/^se?$/ and $wordcase =~ m/[24]/ );

    # do not correct case of prepositions that have (other) children with a matching case
    my @echildren = $prep->get_echildren();
    return if ( any { $_->tag =~ m/^....$prepcase/ } @echildren );

    # correct the tag: use the word's case if it's OK with the preposition
    if ( $tags_prep->{$wordcase} ) {
        $prep->set_tag( $tags_prep->{$wordcase} );
        $prep->set_lemma( $lemmas_prep->{$wordcase} );
        return;
    }

    # find common case for word and preposition (first matching)
    my ($common_case) = grep { $tags_prep->{$_} and $tags_word->{$_} } ( 1, 2, 3, 4, 5, 6, 7 );

    # if there is a possible common case, fix both the word and the preposition
    if ($common_case) {
        $prep->set_tag( $tags_prep->{$common_case} );
        $prep->set_lemma( $lemmas_prep->{$common_case} );
        $word->set_tag( $tags_word->{$common_case} );
        $word->set_lemma( $lemmas_word->{$common_case} );
    }
    return;
}

# Return a hash with keys set for cases this word form might be in (limit to the given POS) and
# values containg the corresponding tags
sub _get_possible_cases {

    my ( $self, $form, $orig_pos, $orig_num, $orig_gen, $orig_lemma ) = @_;

    my $dists  = {};
    my $tags   = {};
    my $lemmas = {};

    my @analyses = $self->_analyzer->analyze($form);

    foreach my $analysis (@analyses) {

        if ( my ( $gen, $num, $case ) = ( $analysis->{tag} =~ m/^$orig_pos.(.)(.)([1-7X])/ ) ) {

            # keep the distance from the current number and gender as small as possible
            my $dist = 0;
            $dist++ if ( $orig_num and $orig_num ne $num );

            # changing gender/lemma is more than changing number
            $dist += 2 if ( ( $orig_gen and $orig_gen ne $gen ) or ( $orig_lemma and $orig_lemma ne $analysis->{lemma} ) );

            if ( ( not $tags->{$case} ) or $dist < $dists->{$case} ) {
                $tags->{$case}   = $analysis->{tag};
                $lemmas->{$case} = $analysis->{lemma};
                $dists->{$case}  = $dist;
            }
        }
    }
    return ( $tags, $lemmas );
}

## Just for debugging purposes - given some a-nodes, print the whole sentence with lemma and tag of these nodes
#sub _log_sent {
#    my ($nodes) = @_;
#
#    my %nodes_map = map { $_->id => 1 } @{$nodes};
#    my @nodes = $nodes->[0]->get_root()->get_descendants( { ordered => 1 } );
#    my $str = '';
#
#    foreach my $node (@nodes) {
#        $str .= $node->form;
#        if ( $nodes_map{ $node->id } ) {
#            $str .= '[' . $node->lemma . ' ' . $node->tag . ']';
#        }
#        $str .= $node->no_space_after() ? '' : ' ';
#    }
#    return $str;
#}
#
## Just for debugging purposes - log applications of preposition correcting rules
#sub _log_application {
#    my ( $caption, $case, $word, $prep ) = @_;
#
#    my ($gold_word) = $word->get_aligned_nodes();
#    $gold_word = $gold_word->[0];
#    my ($gold_prep) = $prep->get_aligned_nodes();
#    $gold_prep = $gold_prep->[0];
#
#    log_warn( join( "\t", ( $caption, $case, $word->tag, $gold_word->tag, $prep->tag, $gold_prep->tag, _log_sent( [ $word, $prep ] ) ) ) );
#}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::CS::FixPrepositionalCase

=head1 DESCRIPTION

Correction of wrong POS in prepositional phrases.

This block looks for all nodes that depend on a preposition and do not match its case. If their form can match the preposition's
case with a different tag or the preposition can have a different case so that the two are congruent, the case of the
node and/or its preposition is changed.

=head1 PARAMETERS

=TODO

A better testing / evaluation is required. Possibly this should be done the other way round -- looking at prepositions
and examining their children. 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
