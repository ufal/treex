# This program simply stems a given sentence

use Moose;
use utf8;
use Treex::Tool::Stemmer::TA::Simple;

my $sentence = "patikkinRa pazakkan enakku irukkiRaTu.";

my $stemmed_sentence = Treex::Tool::Stemmer::TA::Simple::stem_sentence($sentence);

print "Stemmed sentence: " . $stemmed_sentence . "\n";
