package Treex::Tool::Eval::Bleu;

use Treex::Core::Common;
use utf8;
use autodie;

use Readonly;

use List::Util qw(first min max);

Readonly my $NGRAM_BLEU => 4;
Readonly my $NGRAM_DIFF => 3;

Readonly my $LOG2 => log(2);
sub log2 { return log( $_[0] ) / $LOG2; }

my $preserve_case    = 0;    # For NIST this should be 1 (true)
my $total_ref_tokens = 0;
my $total_tst_tokens = 0;
my @ngram_matching;
my @ngram_all;
my @ngram_diff;

sub reset {
    $preserve_case    = 0;
    $total_ref_tokens = 0;
    $total_tst_tokens = 0;
    @ngram_matching   = ();
    @ngram_all        = ();
    @ngram_diff       = ();
}

sub add_segment {
    my ( $tst_text, $ref_text, $is_already_tokenized ) = @_;

    # Normalize (i.e. tokenize and possibly lowercase) test and reference sentences
    if (!$is_already_tokenized){
        ( $tst_text, $ref_text ) = map { normalize_text_international($_) } ( $tst_text, $ref_text );
    }

    # Reference n-grams
    my %ref_count_of;
    my @tokens = split /\s+/, $ref_text;
    $total_ref_tokens += @tokens;
    foreach my $n ( 1 .. $NGRAM_BLEU ) {
        foreach my $ngram ( get_ngrams( $n, @tokens ) ) {
            $ref_count_of{$ngram}++;
            $ngram_diff[$n]{$ngram}++ if $n <= $NGRAM_DIFF;
        }
    }

    # Test n-grams matching the reference
    @tokens = split /\s+/, $tst_text;
    $total_tst_tokens += @tokens;
    my @ngram_matching_segment = ( 0, 0, 0, 0, 0 );
    foreach my $n ( 1 .. $NGRAM_BLEU ) {
        foreach my $ngram ( get_ngrams( $n, @tokens ) ) {
            $ngram_all[$n]++;
            $ngram_diff[$n]{$ngram}-- if $n <= $NGRAM_DIFF;
            next if !$ref_count_of{$ngram};
            $ref_count_of{$ngram}--;
            $ngram_matching[$n]++;
            $ngram_matching_segment[$n]++;
        }
    }
    return @ngram_matching_segment;
}

sub get_bleu {
    my $log_score = 0;
    if ( !$total_ref_tokens || !$total_tst_tokens ) {
        log_warn('No reference or test tokens to evaluate for BLEU!');
        return 0;
    }

    foreach my $n ( 1 .. $NGRAM_BLEU ) {

        # If no reference sentence was longer than n ...
        # This should not happen, but we never want to divide by 0.
        last if !$ngram_all[$n];

        # If no matching n-gram in the whole date ...
        # This also should not normally happen (for n=4, more sentences and reasonable MT system)
        return 0 if !$ngram_matching[$n];

        my $modified_prec = $ngram_matching[$n] / $ngram_all[$n];
        $log_score += log($modified_prec);
    }
    $log_score = $log_score / $NGRAM_BLEU;

    # Brevity penalty
    if ( $total_tst_tokens < $total_ref_tokens ) {
        my $ratio = $total_ref_tokens / $total_tst_tokens;
        $log_score -= $ratio - 1;
    }
    return exp($log_score);
}

sub get_brevity_penalty {
    return 1 if $total_tst_tokens > $total_ref_tokens;
    my $ratio = $total_ref_tokens / $total_tst_tokens;
    return exp( 1 - $ratio );
}

sub get_diff {
    my ( $n, $limit_miss, $limit_extra ) = @_;
    my @ngrams = sort { $ngram_diff[$n]{$b} <=> $ngram_diff[$n]{$a} } keys %{ $ngram_diff[$n] };
    my @miss   = @ngrams[ 0 .. $limit_miss ];
    my @extra  = reverse @ngrams[ $#ngrams - $limit_extra .. $#ngrams ];
    @miss  = map { [ $_, $ngram_diff[$n]{$_} ] } @miss;
    @extra = map { [ $_, $ngram_diff[$n]{$_} ] } @extra;
    return ( \@miss, \@extra );
}

sub get_individual_ngram_prec {
    my ($self) = @_;
    return map { ( $ngram_matching[$_] || 0 ) / ( $ngram_all[$_] || 1 ) } ( 1 .. $NGRAM_BLEU );
}

sub get_ngrams {
    my $n      = shift;
    my @ngrams = ();
    foreach my $start ( 0 .. @_ - $n ) {
        my $ngram = join ' ', @_[ $start .. $start + $n - 1 ];
        push @ngrams, $ngram;
    }
    return @ngrams;
}

# Verbatim copy of mteval-v11b.pl NormalizeText
sub normalize_text {
    my ($norm_text) = @_;

    # language-independent part:
    $norm_text =~ s/<skipped>//g;    # strip "skipped" tags
    $norm_text =~ s/-\n//g;          # strip end-of-line hyphenation and join lines
    $norm_text =~ s/\n/ /g;          # join lines
    $norm_text =~ s/&quot;/"/g;      # convert SGML tag for quote to "
    $norm_text =~ s/&amp;/&/g;       # convert SGML tag for ampersand to &
    $norm_text =~ s/&lt;/</g;        # convert SGML tag for less-than to >
    $norm_text =~ s/&gt;/>/g;        # convert SGML tag for greater-than to <

    # language-dependent part (assuming Western languages):
    $norm_text = " $norm_text ";
    $norm_text =~ tr/[A-Z]/[a-z]/ unless $preserve_case;
    $norm_text =~ s/([\{-\~\[-\` -\&\(-\+\:-\@\/])/ $1 /g;    # tokenize punctuation
    $norm_text =~ s/([^0-9])([\.,])/$1 $2 /g;                 # tokenize period and comma unless preceded by a digit
    $norm_text =~ s/([\.,])([^0-9])/ $1 $2/g;                 # tokenize period and comma unless followed by a digit
    $norm_text =~ s/([0-9])(-)/$1 $2 /g;                      # tokenize dash when preceded by a digit
    $norm_text =~ s/\s+/ /g;                                  # one space only between words
    $norm_text =~ s/^\s+//;                                   # no leading space
    $norm_text =~ s/\s+$//;                                   # no trailing space

    return $norm_text;
}

# We don't want to allow this (as "mteval-v13a.pl -e")
my $split_non_ASCII = 0;

# Verbatim (except for the \p{Hyphen}) copy of mteval-v13a.pl tokenization_international
sub normalize_text_international {
    my ($norm_text) = @_;

    $norm_text =~ s/<skipped>//g;        # strip "skipped" tags
    
    # mteval-v13a uses
    #$norm_text =~ s/\p{Hyphen}\p{Zl}//g; # strip end-of-line hyphenation and join lines
    # but in new perls it generates a warning
    # Use of 'Hyphen' in \p{} or \P{} is deprecated because: Supplanted by Line_Break property values; see www.unicode.org/reports/tr14;
    # New perls (and Unicode 6.0) are correct. Including e.g. NON-BREAKING HYPHEN (\x{2011}) is not proper for the intended goal.
    # But we want to be fully compatible with mteval-v13a.pl --international-tokenization, so let's just silence the warning
    # See http://unicode.org/Public/UNIDATA/PropList.txt and search for "Hyphen".
    $norm_text =~ s/[\x{002D}\x{00AD}\x{058A}\x{1806}\x{2010}\x{2011}\x{2E17}\x{30FB}\x{FE63}\x{FF0D}\x{FF65}]\p{Zl}//g; # strip end-of-line hyphenation and join lines
    
    $norm_text =~ s/\p{Zl}/ /g;          # join lines

    # replace entities
    $norm_text =~ s/&quot;/\"/g;  # quote to "
    $norm_text =~ s/&amp;/&/g;    # ampersand to &
    $norm_text =~ s/&lt;/</g;     # less-than to <
    $norm_text =~ s/&gt;/>/g;     # greater-than to >
    $norm_text =~ s/&apos;/\'/g;  # apostrophe to '

    $norm_text = lc( $norm_text ) unless $preserve_case; # lowercasing if needed
    $norm_text =~ s/([^[:ascii:]])/ $1 /g if ( $split_non_ASCII );

    # punctuation: tokenize any punctuation unless followed AND preceded by a digit
    $norm_text =~ s/(\P{N})(\p{P})/$1 $2 /g;
    $norm_text =~ s/(\p{P})(\P{N})/ $1 $2/g;

    $norm_text =~ s/(\p{S})/ $1 /g; # tokenize symbols

    $norm_text =~ s/\p{Z}+/ /g; # one space only between words
    $norm_text =~ s/^\p{Z}+//; # no leading space
    $norm_text =~ s/\p{Z}+$//; # no trailing space

    return $norm_text;
}



1;

__END__

The official NIST script mteval-v11b.pl is taken as a reference implementation.
In case of multiple reference translations, the BLEU brevity penalty
is not computed as specified in the paper Papineni et al (2001).
Citation:
 We call the closest reference sentence length the “best match length.”
 [...]
 We ﬁrst compute the test corpus’ effective reference length, r,
 by summing the best match lengths for each candidate sentence in the corpus.
 The brevity penalty is a decaying exponential in r/c,
 where c is the total length of the candidate translation corpus.
 
mteval-v11b.pl doesn't count "best match length", but the shortest length
(of all reference translations for a given sentence).

Official NIST score should be computed with preserve-case (unlike BLEU),
but mteval-v11b.pl default is to lowercase all (option -c).

=head1 NAME

Treex::Tool::Eval::Bleu

=head1 VERSION

0.01

=head1 SYNOPSIS

#TODO
 
=head1 AUTHOR

Martin Popel

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
