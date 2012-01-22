use Moose;
use utf8;
use Treex::Tool::Stemmer::TA::Simple;

my $sentence = "patikkinRa pazakkan enakku irukkiRaTu.";

my $stemmed_sentence = Treex::Tool::Stemmer::TA::Simple::stem_sentence($sentence);
Treex::Tool::Stemmer::TA::Simple::stem_document("sample.txt", "sample.txt.1");
print "Stemmed sentence: " . $stemmed_sentence . "\n";
