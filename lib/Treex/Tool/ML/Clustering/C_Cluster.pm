package Treex::Tool::ML::Clustering::C_Cluster;
use Moose;
use Treex::Core::Common;
use Algorithm::FuzzyCmeans;
use strict;
use warnings;

my $fcm ;
my %training ;
sub BUILD {
  my ( $self, $params ) = @_;
  $fcm = Algorithm::FuzzyCmeans->new(
  distance_class => 'Algorithm::FuzzyCmeans::Distance::Cosine',
					m              => 2.0,
					);  cluster();

}

sub cluster {
  
  # input documents
  my %training = (
  'PDT' => {
    'charniak' => 16,
    'stanford' => 14,
    'mst'      => 15,
    'malt'     => 16,
    'zpar'     => 14
    },
  'CC' => {
    'charniak' => 1147,
  'stanford' => 1026,
  'mst'      => 977,
  'malt'     => 904,
  'zpar'     => 280
  },
  'NNP' => {
    'charniak' => 5598,
  'stanford' => 5454,
  'mst'      => 5210,
  'malt'     => 5159,
  'zpar'     => 4360
  },
  ',' => {
    'charniak' => 2586,
  'stanford' => 2389,
  'mst'      => 1933,
  'malt'     => 1841,
  'zpar'     => 2010
  },
  'WP$' => {
    'charniak' => 19,
  'stanford' => 15,
  'mst'      => 18,
  'malt'     => 19,
  'zpar'     => 0
  },
  'VBN' => {
    'charniak' => 1008,
  'stanford' => 987,
  'mst'      => 993,
  'malt'     => 980,
  'zpar'     => 970
  },
  'WP' => {
    'charniak' => 93,
  'stanford' => 89,
  'mst'      => 89,
  'malt'     => 92,
  'zpar'     => 3
  },
  'CD' => {
    'charniak' => 1826,
  'stanford' => 1783,
  'mst'      => 1639,
  'malt'     => 1625,
  'zpar'     => 1590
  },
  'RBR' => {
    'charniak' => 87,
  'stanford' => 70,
  'mst'      => 84,
  'malt'     => 86,
  'zpar'     => 77
  },
  'RP' => {
    'charniak' => 175,
  'stanford' => 173,
  'mst'      => 177,
  'malt'     => 174,
  'zpar'     => 172
  },
  'JJ' => {
    'charniak' => 3537,
  'stanford' => 3447,
  'mst'      => 3502,
  'malt'     => 3481,
  'zpar'     => 3316
  },
  'PRP' => {
    'charniak' => 1032,
  'stanford' => 1015,
  'mst'      => 1020,
  'malt'     => 1009,
  'zpar'     => 1007
  },
  'TO' => {
    'charniak' => 1172,
  'stanford' => 1109,
  'mst'      => 1132,
  'malt'     => 1125,
  'zpar'     => 1099
  },
  'EX' => {
    'charniak' => 55,
  'stanford' => 56,
  'mst'      => 57,
  'malt'     => 57,
  'zpar'     => 55
  },
  'WRB' => {
    'charniak' => 85,
  'stanford' => 81,
  'mst'      => 91,
  'malt'     => 98,
  'zpar'     => 6
  },
  'RB' => {
    'charniak' => 1771,
  'stanford' => 1640,
  'mst'      => 1673,
  'malt'     => 1672,
  'zpar'     => 1655
  },
  'FW' => {
    'charniak' => 11,
  'stanford' => 9,
  'mst'      => 12,
  'malt'     => 5,
  'zpar'     => 7
  },
  'WDT' => {
    'charniak' => 272,
  'stanford' => 267,
  'mst'      => 270,
  'malt'     => 266,
  'zpar'     => 26
  },
  'VBP' => {
    'charniak' => 733,
  'stanford' => 668,
  'mst'      => 649,
  'malt'     => 608,
  'zpar'     => 408
  },
  'VBZ' => {
    'charniak' => 1134,
  'stanford' => 1077,
  'mst'      => 1034,
  'malt'     => 996,
  'zpar'     => 714
  },
  'JJR' => {
    'charniak' => 175,
  'stanford' => 160,
  'mst'      => 148,
  'malt'     => 139,
  'zpar'     => 135
  },
  'NNPS' => {
    'charniak' => 41,
  'stanford' => 40,
  'mst'      => 42,
  'malt'     => 40,
  'zpar'     => 29
  },
  '(' => {
    'charniak' => 53,
    'stanford' => 54,
    'mst'      => 39,
    'malt'     => 42,
    'zpar'     => 11
  },
    'POS' => {
      'charniak' => 539,
    'stanford' => 530,
    'mst'      => 541,
    'malt'     => 542,
    'zpar'     => 1
    },
    'UH' => {
      'charniak' => 7,
    'stanford' => 5,
    'mst'      => 6,
    'malt'     => 3,
    'zpar'     => 3
    },
    '$' => {
      'charniak' => 311,
    'stanford' => 300,
    'mst'      => 253,
    'malt'     => 249,
    'zpar'     => 196
    },
    '``' => {
      'charniak' => 446,
    'stanford' => 423,
    'mst'      => 404,
    'malt'     => 313,
    'zpar'     => 393
    },
    ':' => {
      'charniak' => 250,
    'stanford' => 235,
    'mst'      => 149,
    'malt'     => 144,
    'zpar'     => 174
    },
    'JJS' => {
      'charniak' => 122,
    'stanford' => 115,
    'mst'      => 112,
    'malt'     => 110,
    'zpar'     => 105
    },
    'LS' => {
      'charniak' => 3,
    'stanford' => 2,
    'mst'      => 4,
    'malt'     => 3,
    'zpar'     => 3
    },
    '.' => {
      'charniak' => 2270,
    'stanford' => 2209,
    'mst'      => 2152,
    'malt'     => 2006,
    'zpar'     => 2069
    },
    'VB' => {
      'charniak' => 1470,
    'stanford' => 1398,
    'mst'      => 1443,
    'malt'     => 1437,
    'zpar'     => 1333
    },
    'MD' => {
      'charniak' => 523,
    'stanford' => 479,
    'mst'      => 485,
    'malt'     => 460,
    'zpar'     => 301
    },
    'NN' => {
      'charniak' => 7085,
    'stanford' => 6833,
    'mst'      => 6694,
    'malt'     => 6583,
    'zpar'     => 6345
    },
    'NNS' => {
      'charniak' => 3265,
    'stanford' => 3139,
    'mst'      => 3180,
    'malt'     => 3109,
    'zpar'     => 2768
    },
    'DT' => {
      'charniak' => 4701,
    'stanford' => 4646,
    'mst'      => 4686,
    'malt'     => 4672,
    'zpar'     => 4440
    },
    'VBD' => {
      'charniak' => 1712,
    'stanford' => 1601,
    'mst'      => 1584,
    'malt'     => 1519,
    'zpar'     => 1181
    },
    '\'\'' => {
      'charniak' => 452,
    'stanford' => 429,
    'mst'      => 419,
    'malt'     => 358,
    'zpar'     => 409
    },
    '#' => {
      'charniak' => 5,
    'stanford' => 4,
    'mst'      => 0,
    'malt'     => 0,
    'zpar'     => 0
    },
    'RBS' => {
      'charniak' => 27,
    'stanford' => 23,
    'mst'      => 28,
    'malt'     => 28,
    'zpar'     => 26
    },
    'IN' => {
      'charniak' => 5140,
    'stanford' => 4605,
    'mst'      => 4885,
    'malt'     => 4729,
    'zpar'     => 4278
    },
    ')' => {
      'charniak' => 51,
  'stanford' => 56,
  'mst'      => 34,
  'malt'     => 40,
  'zpar'     => 9
    },
  'PRP$' => {
    'charniak' => 497,
  'stanford' => 489,
  'mst'      => 491,
  'malt'     => 493,
  'zpar'     => 474
  },
  'SYM' => {
    'charniak' => 1,
  'stanford' => 1,
  'mst'      => 1,
  'malt'     => 0,
  'zpar'     => 0
  },
  'VBG' => {
    'charniak' => 696,
  'stanford' => 671,
  'mst'      => 676,
  'malt'     => 672,
  'zpar'     => 664
  },
  );
		   

foreach my $id ( keys %training ) {
  $fcm->add_document( $id, $training{$id} );
  }
  
  my $num_cluster = 3;
  my $num_iter    = 20;
  $fcm->do_clustering( $num_cluster, $num_iter );
  
  # show clustering result
 # foreach my $id ( sort { $a cmp $b } keys %{ $fcm->memberships } ) {
 #   printf "%s\t%s\n", $id,
 #   join "\t", map { sprintf "%.4f", $_ } @{ $fcm->memberships->{$id} };
 # }
  
  # show cluster centroids
  #foreach my $centroid ( @{ $fcm->centroids } ) {
  #  print join "\t", map { sprintf "%s:%.4f", $_, $centroid->{$_} }
  #  keys %{$centroid};
  #  print "\n";
  #}
}

sub get_clusters{

  return $fcm;
}

							 1;
							 
							 __END__
							 