package Treex::Tool::Align::MonolingualGreedy;
use Modern::Perl;
use Moose;
use MooseX::SemiAffordanceAccessor;
use List::MoreUtils qw(all any);
use Carp;

has score_limit => (
    is            => 'ro',
    isa           => 'Num',
    default       => 8,
    documentation => 'minimum score for a node pair to be aligned',
);

has weights => (
    is            => 'ro',
    isa           => 'HashRef',
    lazy_build    => 1,
    documentation => 'weight vector of the features',
);

has punct_tag_regex => (
    is            => 'ro',
    default       => '^([.,;?!]$|SENT$|Z:)',
    documentation => 'which POS tags represent punctuation symbols',
);

has debug => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'debug level, by default 0=no messages',
);

sub _build_weights {
    return {
        lemma_similarity       => 7,
        tag_similarity         => 6,
        aligned_left_neighbor  => 3,
        aligned_right_neighbor => 3,
        ord_similarity         => 5,
    };
}

# other factors apart from forms
my @FACTORS = qw(lemmas tags);

sub align_sentence {
    my ( $self, $args ) = @_;
    $self->_check_args($args);
    my ( $hlast, $rlast ) = ( $args->{hlast}, $args->{rlast} );
    $args->{align} = [ map {-1} ( 0 .. $hlast ) ];

    # We need to know which nodes are still unaligned, i.e. free
    # TODO banchmark using hash instead of array (values %free_h)
    $args->{free_h} = [ 0 .. $hlast ];
    $args->{free_r} = [ 0 .. $rlast ];

    # First, try super-greedy alignment (to make it faster):
    # If there is only one node with the same form, align it.
    # Then similarly for lemmas.
    $self->prealign_same( $args, 'forms' );
    $self->prealign_same( $args, 'lemmas' );

    # Pre-computed scores for all pairs of free nodes
    my $max_score = 0;
    my ( $max_h, $max_r, @score );
    foreach my $h ( @{ $args->{free_h} } ) {
        foreach my $r ( @{ $args->{free_r} } ) {
            my $s = $self->score( $args, $h, $r );
            $score[$h][$r] = $s;
            if ( $s > $max_score ) {
                ( $max_score, $max_h, $max_r ) = ( $s, $h, $r );
            }
        }
    }

    # The main loop
    while ( $max_score >= $self->score_limit ) {

        # Mark the winning alignment pair from the lat iteration.
        $self->_align( $args, $max_h, $max_r, $max_score );

        # The only weights that must be updated are aligned_*_neighbor.
        $score[ $max_h - 1 ][ $max_r - 1 ] += $self->weights->{aligned_right_neighbor} if $max_h && $max_r;
        $score[ $max_h + 1 ][ $max_r + 1 ] += $self->weights->{aligned_left_neighbor} if $max_h != $hlast && $max_r != $rlast;

        # Now find the maximum again
        # TODO use heap instead to make it faster (see Array::Heap or Heap::Simple)
        $max_score = 0;
        foreach my $h ( @{ $args->{free_h} } ) {
            foreach my $r ( @{ $args->{free_r} } ) {
                my $s = $score[$h][$r];
                if ( $s > $max_score ) {
                    ( $max_score, $max_h, $max_r ) = ( $s, $h, $r );
                }
            }
        }
    }

    return $args->{align};
}

sub _check_args {
    my ( $self, $args ) = @_;
    confess 'no args provided' if !$args;
    confess '$args must be a hashref' if ref $args ne 'HASH';
    for my $rh (qw(r h)) {
        my $forms = $args->{ $rh . 'forms' } or confess "${rh}forms is a required arg";
        my $len = @$forms;
        confess "${rh}forms must contain one or more word forms" if $len == 0;

        # remember the index of the last token in a reference/hypothesis sentence
        $args->{"${rh}last"} = $len - 1;

        # check the other factors have the same number of items for the sentence
        for my $factor (@FACTORS) {
            my $f = $args->{ $rh . $factor };
            next if !$f;
            my $f_len = @$f;
            confess "Factor $rh$factor contains $f_len while there are $len forms" if $f_len != $len;
        }

        # Use lowercased forms instead of missing lemmas.
        # By overriding guess_lemma you can also do e.g. stemming.
        if ( !$args->{ $rh . 'lemmas' } ) {
            my @lcforms = map { $self->guess_lemma($_) } @{ $args->{ $rh . 'forms' } };
            $args->{ $rh . 'lemmas' } = \@lcforms;
        }
    }
    return;
}

sub guess_lemma {
    my ( $self, $form ) = @_;
    return lc $form;
}

sub prealign_same {
    my ( $self, $args, $attr ) = @_;
    my %r_forms;
    foreach my $r ( @{ $args->{free_r} } ) {
        my $r_form = $args->{"r$attr"}[$r];
        next if !defined $r_form;    # TODO should be checked earlier
        if ( defined $r_forms{$r_form} ) {
            $r_forms{$r_form} = -2;
        }
        else {
            $r_forms{$r_form} = $r;
        }
    }

    my %h_forms;
    foreach my $h ( @{ $args->{free_h} } ) {
        my $h_form = $args->{"h$attr"}[$h];
        my $r      = $r_forms{$h_form};
        if ( defined $r && $r != -2 ) {
            if ( defined $h_forms{$h_form} ) {
                $h_forms{$h_form} = -2;
            }
            else {
                $h_forms{$h_form} = $h;
            }
        }
    }

    foreach my $h_form ( keys %h_forms ) {
        my $h = $h_forms{$h_form};
        next if $h == -2;
        my $r = $r_forms{$h_form};
        $self->_align( $args, $h, $r, "prealign-$attr" );
    }
    return;
}

sub _align {
    my ( $self, $args, $h, $r, $score ) = @_;
    $args->{align}[$h] = $r;

    # Delete the aligned nodes from the pool of free nodes.
    $args->{free_h} = [ grep { $_ != $h } @{ $args->{free_h} } ];
    $args->{free_r} = [ grep { $_ != $r } @{ $args->{free_r} } ];

    if ( $self->debug ) {
        my ( $hform, $rform ) = ( $args->{hforms}[$h], $args->{rforms}[$r] );
        warn "score=$score\taligning $h-$r: $hform-$rform\n";
        if ( $self->debug > 1 ) {
            my %feats = %{ $self->compute_features( $args, $h, $r ) };
            while ( my ( $f, $v ) = each %feats ) {
                warn sprintf( "$f=%.3f\n", $v ) if $v;
            }
        }
    }
    return;
}

sub score {
    my ( $self, $args, $h, $r ) = @_;
    my %features = %{ $self->compute_features( $args, $h, $r ) };

    my $score = 0;
    foreach my $feature_name ( keys %features ) {
        $score += $features{$feature_name} * $self->weights->{$feature_name};
    }
    return $score;
}

sub compute_features {
    my ( $self, $args, $h, $r ) = @_;
    my ( $hlast, $rlast ) = ( $args->{hlast}, $args->{rlast} );
    my %features;

    $features{lemma_similarity} = $self->lemma_similarity( $args, $h, $r );
    $features{tag_similarity} = $self->tag_similarity( $args, $h, $r );
    $features{aligned_left_neighbor}  = 1 if $h           && $args->{align}[ $h - 1 ] == $r - 1;
    $features{aligned_right_neighbor} = 1 if $h != $hlast && $args->{align}[ $h + 1 ] == $r + 1;
    $features{ord_similarity} = 1 - abs( ( $h / ( $hlast || 1 ) ) - ( $r / ( $rlast || 1 ) ) );
    return \%features;
}

use Text::JaroWinkler;

sub lemma_similarity {
    my ( $self, $args, $h, $r ) = @_;
    my ( $hlemma, $rlemma ) = ( $args->{hlemmas}[$h], $args->{rlemmas}[$r] );
    return 0 if !defined $hlemma || !defined $rlemma;
    my $jw = Text::JaroWinkler::strcmp95( $hlemma, $rlemma, 20 );

    # jw==0.6 means that the two lemmas are too different
    # to be derivations of each other or spelling variants,
    # so the lemma_similarity for such lemmas should be 0.
    my $limit = 0.6;
    return 0 if $jw <= $limit;
    return ( $jw - $limit ) / ( 1 - $limit );
}

sub tag_similarity {
    my ( $self, $args, $h, $r ) = @_;
    my ( $htag, $rtag ) = ( $args->{htags}[$h], $args->{rtags}[$r] );
    return 0 if !defined $htag || !defined $rtag;

    # Same tags have the maximum score of 1
    return 1 if $htag eq $rtag;

    # Punctuation should not be aligned to non-punctuation.
    return -10 if ( ( $htag =~ $self->punct_tag_regex ) != ( $rtag =~ $self->punct_tag_regex ) );

    # If the first letter of POS tag is the same, it usually means coarse-grained POS is the same
    return 0.5 if substr( $htag, 0, 1 ) eq substr( $rtag, 0, 1 );
    return 0;
}

1;

__END__
 
=head1 NAME

Treex::Tool::Align::MonolingualGreedy - align paraphrases, e.g. MT-output and reference

=head1 SYNOPSIS

  use Treex::Tool::Align::MonolingualGreedy;
  my $greedy = Treex::Tool::Align::MonolingualGreedy->new();
  my $args     = {
        hforms  => [qw(William          hates examples)],
        rforms  => [qw(Bill    does not hate  samples)],
        hlemmas => [qw(William          hate  example)],
        rlemmas => [qw(Bill    do   not hate  sample)],
        htags   => [qw(NNP              VBZ   NNS)],
        rtags   => [qw(NNP     VB   RB  VB    NNS)],
    };
  my $ali = $greedy->align_sentence($args);
  print join ' ', map { $ali->[$_] == -1 ? () : $_ . '-' . $ali->[$_] } (0 .. 2);
  # prints 0-0 1-3 2-4

=head1 DESCRIPTION

Aligns two sentences which are suposed to be in a same or similar language.
Only one-to-one alignments are created, but some words may remain unaligned.
Forms, lemmas and tags can be exploited.

The tool scores all possible alignment links
and then greedily chooses the currently highest scoring one,
creating the respective alignment link from word A (in the reference) to word B (in the hypothesis)
and deleting all scores of links from A or to B,
so that one-to-one alignments are enforced.
The process is terminated when no links with a score higher than a given threshold are available,
some words may thus remain unaligned.
The score is computed as a linear combination of the five following features:
word form similarity based on Jaro-Winkler distance,
tag similarity,
similarity in relative position in the sentence,
and an indication whether the word following (or preceding) A was already aligned to the word following (or preceding) B.
Unlike bilingual word aligners, this tool needs no training.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Block::Align::A::MonolingualGreedy>
L<Text::JaroWinkler>

=head1 COPYRIGHT

Copyright 2012 Martin Popel
This file is distributed under the GNU General Public License v2 or later.
