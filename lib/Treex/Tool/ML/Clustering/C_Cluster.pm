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
    'Charniak' => 16,
    'Stanford' => 14,
    'Mst'      => 15,
    'Malt'     => 16,
    'Zpar'     => 14
    },
  'CC' => {
    'Charniak' => 1147,
  'Stanford' => 1026,
  'Mst'      => 977,
  'Malt'     => 904,
  'Zpar'     => 280
  },
  'NNP' => {
    'Charniak' => 5598,
  'Stanford' => 5454,
  'Mst'      => 5210,
  'Malt'     => 5159,
  'Zpar'     => 4360
  },
  ',' => {
    'Charniak' => 2586,
  'Stanford' => 2389,
  'Mst'      => 1933,
  'Malt'     => 1841,
  'Zpar'     => 2010
  },
  'WP$' => {
    'Charniak' => 19,
  'Stanford' => 15,
  'Mst'      => 18,
  'Malt'     => 19,
  'Zpar'     => 0
  },
  'VBN' => {
    'Charniak' => 1008,
  'Stanford' => 987,
  'Mst'      => 993,
  'Malt'     => 980,
  'Zpar'     => 970
  },
  'WP' => {
    'Charniak' => 93,
  'Stanford' => 89,
  'Mst'      => 89,
  'Malt'     => 92,
  'Zpar'     => 3
  },
  'CD' => {
    'Charniak' => 1826,
  'Stanford' => 1783,
  'Mst'      => 1639,
  'Malt'     => 1625,
  'Zpar'     => 1590
  },
  'RBR' => {
    'Charniak' => 87,
  'Stanford' => 70,
  'Mst'      => 84,
  'Malt'     => 86,
  'Zpar'     => 77
  },
  'RP' => {
    'Charniak' => 175,
  'Stanford' => 173,
  'Mst'      => 177,
  'Malt'     => 174,
  'Zpar'     => 172
  },
  'JJ' => {
    'Charniak' => 3537,
  'Stanford' => 3447,
  'Mst'      => 3502,
  'Malt'     => 3481,
  'Zpar'     => 3316
  },
  'PRP' => {
    'Charniak' => 1032,
  'Stanford' => 1015,
  'Mst'      => 1020,
  'Malt'     => 1009,
  'Zpar'     => 1007
  },
  'TO' => {
    'Charniak' => 1172,
  'Stanford' => 1109,
  'Mst'      => 1132,
  'Malt'     => 1125,
  'Zpar'     => 1099
  },
  'EX' => {
    'Charniak' => 55,
  'Stanford' => 56,
  'Mst'      => 57,
  'Malt'     => 57,
  'Zpar'     => 55
  },
  'WRB' => {
    'Charniak' => 85,
  'Stanford' => 81,
  'Mst'      => 91,
  'Malt'     => 98,
  'Zpar'     => 6
  },
  'RB' => {
    'Charniak' => 1771,
  'Stanford' => 1640,
  'Mst'      => 1673,
  'Malt'     => 1672,
  'Zpar'     => 1655
  },
  'FW' => {
    'Charniak' => 11,
  'Stanford' => 9,
  'Mst'      => 12,
  'Malt'     => 5,
  'Zpar'     => 7
  },
  'WDT' => {
    'Charniak' => 272,
  'Stanford' => 267,
  'Mst'      => 270,
  'Malt'     => 266,
  'Zpar'     => 26
  },
  'VBP' => {
    'Charniak' => 733,
  'Stanford' => 668,
  'Mst'      => 649,
  'Malt'     => 608,
  'Zpar'     => 408
  },
  'VBZ' => {
    'Charniak' => 1134,
  'Stanford' => 1077,
  'Mst'      => 1034,
  'Malt'     => 996,
  'Zpar'     => 714
  },
  'JJR' => {
    'Charniak' => 175,
  'Stanford' => 160,
  'Mst'      => 148,
  'Malt'     => 139,
  'Zpar'     => 135
  },
  'NNPS' => {
    'Charniak' => 41,
  'Stanford' => 40,
  'Mst'      => 42,
  'Malt'     => 40,
  'Zpar'     => 29
  },
  '(' => {
    'Charniak' => 53,
    'Stanford' => 54,
    'Mst'      => 39,
    'Malt'     => 42,
    'Zpar'     => 11
  },
    'POS' => {
      'Charniak' => 539,
    'Stanford' => 530,
    'Mst'      => 541,
    'Malt'     => 542,
    'Zpar'     => 1
    },
    'UH' => {
      'Charniak' => 7,
    'Stanford' => 5,
    'Mst'      => 6,
    'Malt'     => 3,
    'Zpar'     => 3
    },
    '$' => {
      'Charniak' => 311,
    'Stanford' => 300,
    'Mst'      => 253,
    'Malt'     => 249,
    'Zpar'     => 196
    },
    '``' => {
      'Charniak' => 446,
    'Stanford' => 423,
    'Mst'      => 404,
    'Malt'     => 313,
    'Zpar'     => 393
    },
    ':' => {
      'Charniak' => 250,
    'Stanford' => 235,
    'Mst'      => 149,
    'Malt'     => 144,
    'Zpar'     => 174
    },
    'JJS' => {
      'Charniak' => 122,
    'Stanford' => 115,
    'Mst'      => 112,
    'Malt'     => 110,
    'Zpar'     => 105
    },
    'LS' => {
      'Charniak' => 3,
    'Stanford' => 2,
    'Mst'      => 4,
    'Malt'     => 3,
    'Zpar'     => 3
    },
    '.' => {
      'Charniak' => 2270,
    'Stanford' => 2209,
    'Mst'      => 2152,
    'Malt'     => 2006,
    'Zpar'     => 2069
    },
    'VB' => {
      'Charniak' => 1470,
    'Stanford' => 1398,
    'Mst'      => 1443,
    'Malt'     => 1437,
    'Zpar'     => 1333
    },
    'MD' => {
      'Charniak' => 523,
    'Stanford' => 479,
    'Mst'      => 485,
    'Malt'     => 460,
    'Zpar'     => 301
    },
    'NN' => {
      'Charniak' => 7085,
    'Stanford' => 6833,
    'Mst'      => 6694,
    'Malt'     => 6583,
    'Zpar'     => 6345
    },
    'NNS' => {
      'Charniak' => 3265,
    'Stanford' => 3139,
    'Mst'      => 3180,
    'Malt'     => 3109,
    'Zpar'     => 2768
    },
    'DT' => {
      'Charniak' => 4701,
    'Stanford' => 4646,
    'Mst'      => 4686,
    'Malt'     => 4672,
    'Zpar'     => 4440
    },
    'VBD' => {
      'Charniak' => 1712,
    'Stanford' => 1601,
    'Mst'      => 1584,
    'Malt'     => 1519,
    'Zpar'     => 1181
    },
    '\'\'' => {
      'Charniak' => 452,
    'Stanford' => 429,
    'Mst'      => 419,
    'Malt'     => 358,
    'Zpar'     => 409
    },
    '#' => {
      'Charniak' => 5,
    'Stanford' => 4,
    'Mst'      => 0,
    'Malt'     => 0,
    'Zpar'     => 0
    },
    'RBS' => {
      'Charniak' => 27,
    'Stanford' => 23,
    'Mst'      => 28,
    'Malt'     => 28,
    'Zpar'     => 26
    },
    'IN' => {
      'Charniak' => 5140,
    'Stanford' => 4605,
    'Mst'      => 4885,
    'Malt'     => 4729,
    'Zpar'     => 4278
    },
    ')' => {
      'Charniak' => 51,
  'Stanford' => 56,
  'Mst'      => 34,
  'Malt'     => 40,
  'Zpar'     => 9
    },
  'PRP$' => {
    'Charniak' => 497,
  'Stanford' => 489,
  'Mst'      => 491,
  'Malt'     => 493,
  'Zpar'     => 474
  },
  'SYM' => {
    'Charniak' => 1,
  'Stanford' => 1,
  'Mst'      => 1,
  'Malt'     => 0,
  'Zpar'     => 0
  },
  'VBG' => {
    'Charniak' => 696,
  'Stanford' => 671,
  'Mst'      => 676,
  'Malt'     => 672,
  'Zpar'     => 664
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
							 