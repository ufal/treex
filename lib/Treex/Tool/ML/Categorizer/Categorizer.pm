use strict;
use warnings;
require AI::Categorizer;
require AI::Categorizer::Learner::NaiveBayes;
require AI::Categorizer::Document;
require AI::Categorizer::KnowledgeSet;
require Lingua::StopWords;

# set up features:
#    - give different weights to subjects and bodies
#    - use stop words
my %features = (content_weights => {subject => 2,
body => 1},
stopwords => Lingua::StopWords::getStopWords('en'),
stemming => 'porter',
);

# this is the raw data to train with, which associates
# numerical categories with subjects and bodies
my $chaps = 
{ 6 => {subject => q{Data Type Utilities},
body => q{Date Time Math List Tree Algorithm Sort},
},
10 => {subject => q{File Names Systems Locking},
body => q{Directory Dir Stat cwd},
},
12 => {subject => q{Opt Arg Param Proc},
body => q{Option Argument Argv Config Getopt},
},
14 => {subject => q{Security and Encryption},
body => q{Authentication Crypt Digest PGP Des},
},
15 => {subject => q{World Wide Web HTML HTTP CGI},
body => q{WWW Apache MIME Kwiki URI URL},
},
17 => {subject => q{Archiving and Compression},
body => q{tar gzip gz zip bzip},
},
18 => {subject => q{Images Pixmaps Bitmaps},
body => q{Chart Graphic},
},
19 => {subject => q{Mail and Usenet News},
body => q{Sendmail NNTP SMTP IMAP POP3 MIME},
},
};

# create documents from $chaps to train with
my $docs;
foreach my $cat(keys %$chaps) {
  $docs->{$cat} = {categories => [$cat],
  content => {subject => $chaps->{$cat}->{subject},
  body => $chaps->{$cat}->{body},
  },
  };
}
my $c = 
AI::Categorizer->new(
knowledge_set => 
AI::Categorizer::KnowledgeSet->new( name => 'CSL'),
		      verbose => 1,
		      );
		      while (my ($name, $data) = each %$docs) {
			$c->knowledge_set->make_document(name => $name, %$data, %features);
		      }
		      my $learner = $c->learner;
		      $learner->train;
		      
		      # this is a test data set to categorize,
		      # based on the training done above
		      my $test_set = 
		      {'Math::Complex' => {content => 
		      {subject => q{Math},
		      body => q{Complex number data type}
		      } },
		      'Archive::Zip' => {content => 
		      {subject => q{Compression},
		      body => q{Interface to ZIP archive files}
		      } },
		      'Apache2::URI' => {content => 
		      {subject => q{Apache},
		      body => q{Perl API for manipulating URIs}
		      } },
		      'MIME::Lite' => {content => 
		      {subject => q{Mail},
		      body => q{Create MIME/SMTP mails w/attachements}
} },
};

# see what category each element of $test_set gets put into,
# using a threshold score of 0.9
my $threshold = 0.9;
while (my ($name, $data) = each %$test_set) {
  my $doc = AI::Categorizer::Document->new(name => $name,
					    content => $data->{content},
					    %features);
					    my $r = $learner->categorize($doc);
					    $r->threshold($threshold);
					    my $b = $r->best_category;
					    next unless $r->in_category($b);
					    printf("%s is in category %d, with score %.3f\n",
					    $name, $b, $r->scores($b));
}