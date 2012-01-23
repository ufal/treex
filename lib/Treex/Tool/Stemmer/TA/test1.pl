use Moose;
use utf8;
use Treex::Tool::Stemmer::TA::Simple;

# stem a given document. output is written to a new file
Treex::Tool::Stemmer::TA::Simple::stem_document("sample.txt", "sample.stm.txt");

# restore the original document. 
Treex::Tool::Stemmer::TA::Simple::restore_document("sample.stm.txt", "sample.res.txt");
