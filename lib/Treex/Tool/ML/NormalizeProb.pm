package Treex::Tool::ML::NormalizeProb;
use Treex::Core::Common;
use Readonly;

sub logscores2probs {
    my @scores = @_;
    my $sum;
    foreach my $score (@scores) {
        $sum += exp($score);
    }
    return map {exp($_)/$sum} @scores;
}

Readonly my $LOG2 => log 2;

sub prob2binlog {
    my $prob = shift;
    if ($prob > 1 or $prob <= 0) {
        log_fatal "probability value $prob is not within the required interval";
      }
    return log($prob) / $LOG2;
}



1;




__END__


=pod

=head1 NAME

Treex::Tool::ML::NormalizeProb

=head1 DESCRIPTION

Simple utitilities for normalizing probability distributions.

=over 4

=item  my @probs = Treex::Tool::ML::NormalizeProb::logscores2probs(@scores);

For an array of scores in log space (typically weighted sums of features,
such as in in maxent), an array of probability values prob = exp(score)/Z is
returned in which the normalization constant Z is the sum of exp(score)
for all scores.

=over 4

=item my $logprob = prob2binlog($prob);

Binary logarithm of a probability value.

=back

=head1 AUTHOR

Zdenek Zabokrtsky

=cut


