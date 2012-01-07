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
  
  #input documents FOR TEST DATA
#   my %training = (
#   'PDT' => {
#     'charniak' => 16,
#     'stanford' => 14,
#     'mst'      => 15,
#     'malt'     => 16,
#     'zpar'     => 14
#     },
#   'CC' => {
#     'charniak' => 1147,
#   'stanford' => 1026,
#   'mst'      => 977,
#   'malt'     => 904,
#   'zpar'     => 280
#   },
#   'NNP' => {
#     'charniak' => 5598,
#   'stanford' => 5454,
#   'mst'      => 5210,
#   'malt'     => 5159,
#   'zpar'     => 4360
#   },
#   ',' => {
#     'charniak' => 2586,
#   'stanford' => 2389,
#   'mst'      => 1933,
#   'malt'     => 1841,
#   'zpar'     => 2010
#   },
#   'WP$' => {
#     'charniak' => 19,
#   'stanford' => 15,
#   'mst'      => 18,
#   'malt'     => 19,
#   'zpar'     => 0
#   },
#   'VBN' => {
#     'charniak' => 1008,
#   'stanford' => 987,
#   'mst'      => 993,
#   'malt'     => 980,
#   'zpar'     => 970
#   },
#   'WP' => {
#     'charniak' => 93,
#   'stanford' => 89,
#   'mst'      => 89,
#   'malt'     => 92,
#   'zpar'     => 3
#   },
#   'CD' => {
#     'charniak' => 1826,
#   'stanford' => 1783,
#   'mst'      => 1639,
#   'malt'     => 1625,
#   'zpar'     => 1590
#   },
#   'RBR' => {
#     'charniak' => 87,
#   'stanford' => 70,
#   'mst'      => 84,
#   'malt'     => 86,
#   'zpar'     => 77
#   },
#   'RP' => {
#     'charniak' => 175,
#   'stanford' => 173,
#   'mst'      => 177,
#   'malt'     => 174,
#   'zpar'     => 172
#   },
#   'JJ' => {
#     'charniak' => 3537,
#   'stanford' => 3447,
#   'mst'      => 3502,
#   'malt'     => 3481,
#   'zpar'     => 3316
#   },
#   'PRP' => {
#     'charniak' => 1032,
#   'stanford' => 1015,
#   'mst'      => 1020,
#   'malt'     => 1009,
#   'zpar'     => 1007
#   },
#   'TO' => {
#     'charniak' => 1172,
#   'stanford' => 1109,
#   'mst'      => 1132,
#   'malt'     => 1125,
#   'zpar'     => 1099
#   },
#   'EX' => {
#     'charniak' => 55,
#   'stanford' => 56,
#   'mst'      => 57,
#   'malt'     => 57,
#   'zpar'     => 55
#   },
#   'WRB' => {
#     'charniak' => 85,
#   'stanford' => 81,
#   'mst'      => 91,
#   'malt'     => 98,
#   'zpar'     => 6
#   },
#   'RB' => {
#     'charniak' => 1771,
#   'stanford' => 1640,
#   'mst'      => 1673,
#   'malt'     => 1672,
#   'zpar'     => 1655
#   },
#   'FW' => {
#     'charniak' => 11,
#   'stanford' => 9,
#   'mst'      => 12,
#   'malt'     => 5,
#   'zpar'     => 7
#   },
#   'WDT' => {
#     'charniak' => 272,
#   'stanford' => 267,
#   'mst'      => 270,
#   'malt'     => 266,
#   'zpar'     => 26
#   },
#   'VBP' => {
#     'charniak' => 733,
#   'stanford' => 668,
#   'mst'      => 649,
#   'malt'     => 608,
#   'zpar'     => 408
#   },
#   'VBZ' => {
#     'charniak' => 1134,
#   'stanford' => 1077,
#   'mst'      => 1034,
#   'malt'     => 996,
#   'zpar'     => 714
#   },
#   'JJR' => {
#     'charniak' => 175,
#   'stanford' => 160,
#   'mst'      => 148,
#   'malt'     => 139,
#   'zpar'     => 135
#   },
#   'NNPS' => {
#     'charniak' => 41,
#   'stanford' => 40,
#   'mst'      => 42,
#   'malt'     => 40,
#   'zpar'     => 29
#   },
#   '(' => {
#     'charniak' => 53,
#     'stanford' => 54,
#     'mst'      => 39,
#     'malt'     => 42,
#     'zpar'     => 11
#   },
#     'POS' => {
#       'charniak' => 539,
#     'stanford' => 530,
#     'mst'      => 541,
#     'malt'     => 542,
#     'zpar'     => 1
#     },
#     'UH' => {
#       'charniak' => 7,
#     'stanford' => 5,
#     'mst'      => 6,
#     'malt'     => 3,
#     'zpar'     => 3
#     },
#     '$' => {
#       'charniak' => 311,
#     'stanford' => 300,
#     'mst'      => 253,
#     'malt'     => 249,
#     'zpar'     => 196
#     },
#     '``' => {
#       'charniak' => 446,
#     'stanford' => 423,
#     'mst'      => 404,
#     'malt'     => 313,
#     'zpar'     => 393
#     },
#     ':' => {
#       'charniak' => 250,
#     'stanford' => 235,
#     'mst'      => 149,
#     'malt'     => 144,
#     'zpar'     => 174
#     },
#     'JJS' => {
#       'charniak' => 122,
#     'stanford' => 115,
#     'mst'      => 112,
#     'malt'     => 110,
#     'zpar'     => 105
#     },
#     'LS' => {
#       'charniak' => 3,
#     'stanford' => 2,
#     'mst'      => 4,
#     'malt'     => 3,
#     'zpar'     => 3
#     },
#     '.' => {
#       'charniak' => 2270,
#     'stanford' => 2209,
#     'mst'      => 2152,
#     'malt'     => 2006,
#     'zpar'     => 2069
#     },
#     'VB' => {
#       'charniak' => 1470,
#     'stanford' => 1398,
#     'mst'      => 1443,
#     'malt'     => 1437,
#     'zpar'     => 1333
#     },
#     'MD' => {
#       'charniak' => 523,
#     'stanford' => 479,
#     'mst'      => 485,
#     'malt'     => 460,
#     'zpar'     => 301
#     },
#     'NN' => {
#       'charniak' => 7085,
#     'stanford' => 6833,
#     'mst'      => 6694,
#     'malt'     => 6583,
#     'zpar'     => 6345
#     },
#     'NNS' => {
#       'charniak' => 3265,
#     'stanford' => 3139,
#     'mst'      => 3180,
#     'malt'     => 3109,
#     'zpar'     => 2768
#     },
#     'DT' => {
#       'charniak' => 4701,
#     'stanford' => 4646,
#     'mst'      => 4686,
#     'malt'     => 4672,
#     'zpar'     => 4440
#     },
#     'VBD' => {
#       'charniak' => 1712,
#     'stanford' => 1601,
#     'mst'      => 1584,
#     'malt'     => 1519,
#     'zpar'     => 1181
#     },
#     '\'\'' => {
#       'charniak' => 452,
#     'stanford' => 429,
#     'mst'      => 419,
#     'malt'     => 358,
#     'zpar'     => 409
#     },
#     '#' => {
#       'charniak' => 5,
#     'stanford' => 4,
#     'mst'      => 0,
#     'malt'     => 0,
#     'zpar'     => 0
#     },
#     'RBS' => {
#       'charniak' => 27,
#     'stanford' => 23,
#     'mst'      => 28,
#     'malt'     => 28,
#     'zpar'     => 26
#     },
#     'IN' => {
#       'charniak' => 5140,
#     'stanford' => 4605,
#     'mst'      => 4885,
#     'malt'     => 4729,
#     'zpar'     => 4278
#     },
#     ')' => {
#       'charniak' => 51,
#   'stanford' => 56,
#   'mst'      => 34,
#   'malt'     => 40,
#   'zpar'     => 9
#     },
#   'PRP$' => {
#     'charniak' => 497,
#   'stanford' => 489,
#   'mst'      => 491,
#   'malt'     => 493,
#   'zpar'     => 474
#   },
#   'SYM' => {
#     'charniak' => 1,
#   'stanford' => 1,
#   'mst'      => 1,
#   'malt'     => 0,
#   'zpar'     => 0
#   },
#   'VBG' => {
#     'charniak' => 696,
#   'stanford' => 671,
#   'mst'      => 676,
#   'malt'     => 672,
#   'zpar'     => 664
#   },
#   );
		   

  
  #tUNING DATA
  
#   my %training = ('PDT' => {'charniak'     =>3,'stanford'     =>4,'mst'     =>2,'malt'     =>3,'zpar'     =>1},
# 		  'CC' => {'charniak'     =>848,'stanford'     =>762,'mst'     =>722,'malt'     =>502,'zpar'     =>181},
# 		  'NNP' => {'charniak'     =>3826,'stanford'     =>3706,'mst'     =>3621,'malt'     =>3535,'zpar'     =>3035},
# 		  ',' => {'charniak'     =>1788,'stanford'     =>1650,'mst'     =>1385,'malt'     =>1259,'zpar'     =>1292},
# 		  'WP$' => {'charniak'     =>8,'stanford'     =>5,'mst'     =>9,'malt'     =>9,'zpar'     =>0},
# 		  'VBN' => {'charniak'     =>781,'stanford'     =>785,'mst'     =>776,'malt'     =>760,'zpar'     =>730},
# 		  'WP' => {'charniak'     =>74,'stanford'     =>73,'mst'     =>69,'malt'     =>67,'zpar'     =>8},
# 		  'CD' => {'charniak'     =>1765,'stanford'     =>1708,'mst'     =>1591,'malt'     =>1584,'zpar'     =>1572},
# 		  'RBR' => {'charniak'     =>81,'stanford'     =>62,'mst'     =>81,'malt'     =>72,'zpar'     =>71},
# 		  'RP' => {'charniak'     =>123,'stanford'     =>122,'mst'     =>121,'malt'     =>124,'zpar'     =>123},
# 		  'JJ' => {'charniak'     =>2353,'stanford'     =>2294,'mst'     =>2337,'malt'     =>2297,'zpar'     =>2190},
# 		  'PRP' => {'charniak'     =>603,'stanford'     =>591,'mst'     =>588,'malt'     =>569,'zpar'     =>576},
# 		  'TO' => {'charniak'     =>821,'stanford'     =>761,'mst'     =>797,'malt'     =>785,'zpar'     =>782},
# 		  'EX' => {'charniak'     =>31,'stanford'     =>31,'mst'     =>32,'malt'     =>32,'zpar'     =>31},
# 		  'WRB' => {'charniak'     =>59,'stanford'     =>55,'mst'     =>62,'malt'     =>52,'zpar'     =>3},
# 		  'RB' => {'charniak'     =>1151,'stanford'     =>1035,'mst'     =>1066,'malt'     =>1054,'zpar'     =>1073},
# 		  'FW' => {'charniak'     =>2,'stanford'     =>2,'mst'     =>0,'malt'     =>1,'zpar'     =>2},
# 		  'WDT' => {'charniak'     =>170,'stanford'     =>167,'mst'     =>169,'malt'     =>164,'zpar'     =>11},
# 		  'VBP' => {'charniak'     =>297,'stanford'     =>281,'mst'     =>271,'malt'     =>235,'zpar'     =>150},
# 		  'VBZ' => {'charniak'     =>633,'stanford'     =>609,'mst'     =>583,'malt'     =>508,'zpar'     =>404},
# 		  'JJR' => {'charniak'     =>122,'stanford'     =>115,'mst'     =>101,'malt'     =>100,'zpar'     =>96},
# 		  'NNPS' => {'charniak'     =>1,'stanford'     =>1,'mst'     =>1,'malt'     =>1,'zpar'     =>0},
# 		  '(' => {'charniak'     =>42,'stanford'     =>44,'mst'     =>40,'malt'     =>36,'zpar'     =>12},
# 		    'POS' => {'charniak'     =>424,'stanford'     =>417,'mst'     =>424,'malt'     =>425,'zpar'     =>1},
# 		    'UH' => {'charniak'     =>4,'stanford'     =>3,'mst'     =>2,'malt'     =>2,'zpar'     =>3},
# 		    '$' => {'charniak'     =>288,'stanford'     =>271,'mst'     =>228,'malt'     =>207,'zpar'     =>166},
# 		    '``' => {'charniak'     =>217,'stanford'     =>204,'mst'     =>195,'malt'     =>155,'zpar'     =>193},
# 		    ':' => {'charniak'     =>161,'stanford'     =>140,'mst'     =>54,'malt'     =>44,'zpar'     =>111},
# 		    'JJS' => {'charniak'     =>80,'stanford'     =>80,'mst'     =>76,'malt'     =>76,'zpar'     =>73},
# 		    'LS' => {'charniak'     =>5,'stanford'     =>3,'mst'     =>4,'malt'     =>5,'zpar'     =>5},
# 		    'VB' => {'charniak'     =>905,'stanford'     =>870,'mst'     =>885,'malt'     =>836,'zpar'     =>789},
# 		    '.' => {'charniak'     =>1603,'stanford'     =>1562,'mst'     =>1512,'malt'     =>1205,'zpar'     =>1437},
# 		    'MD' => {'charniak'     =>311,'stanford'     =>282,'mst'     =>281,'malt'     =>231,'zpar'     =>167},
# 		    'NNS' => {'charniak'     =>2305,'stanford'     =>2216,'mst'     =>2255,'malt'     =>2161,'zpar'     =>1961},
# 		    'NN' => {'charniak'     =>5353,'stanford'     =>5139,'mst'     =>5087,'malt'     =>4943,'zpar'     =>4720},
# 		    'DT' => {'charniak'     =>3424,'stanford'     =>3399,'mst'     =>3414,'malt'     =>3390,'zpar'     =>3215},
# 		    'VBD' => {'charniak'     =>1610,'stanford'     =>1508,'mst'     =>1472,'malt'     =>1228,'zpar'     =>1061},
# 		    '\'\'' => {'charniak'     =>213,'stanford'     =>192,'mst'     =>197,'malt'     =>181,'zpar'     =>193},
# 		    '#' => {'charniak'     =>7,'stanford'     =>7,'mst'     =>0,'malt'     =>0,'zpar'     =>0},
# 		    'RBS' => {'charniak'     =>12,'stanford'     =>13,'mst'     =>12,'malt'     =>14,'zpar'     =>15},
# 		    'IN' => {'charniak'     =>3546,'stanford'     =>3145,'mst'     =>3321,'malt'     =>3259,'zpar'     =>3006},
# 		    'PRP$' => {'charniak'     =>284,'stanford'     =>274,'mst'     =>273,'malt'     =>280,'zpar'     =>261},
# 		    ')' => {'charniak'     =>42,'stanford'     =>46,'mst'     =>34,'malt'     =>34,'zpar'     =>13},
# 		  'VBG' => {'charniak'     =>498,'stanford'     =>477,'mst'     =>497,'malt'     =>447,'zpar'     =>459},);

  #Japenese data
  
#   my %training = ('N' => {'mstproj'     =>875,'mstnonproj'     =>717,'nivreeager'     =>965,'nivrestandard'     =>967,'stacklazy'     =>958,'stackeager'     =>967,'stackproj'     =>954,'planar'     =>939,'2planar'     =>935,'covnonproj'     =>966,'covproj'     =>964},
# 		  'ITJ' => {'mstproj'     =>213,'mstnonproj'     =>217,'nivreeager'     =>217,'nivrestandard'     =>218,'stacklazy'     =>217,'stackeager'     =>218,'stackproj'     =>214,'planar'     =>218,'2planar'     =>218,'covnonproj'     =>217,'covproj'     =>218},
# 		  'V' => {'mstproj'     =>341,'mstnonproj'     =>321,'nivreeager'     =>375,'nivrestandard'     =>375,'stacklazy'     =>377,'stackeager'     =>377,'stackproj'     =>374,'planar'     =>371,'2planar'     =>345,'covnonproj'     =>376,'covproj'     =>379},
# 		  '--' => {'mstproj'     =>4,'mstnonproj'     =>3,'nivreeager'     =>3,'nivrestandard'     =>3,'stacklazy'     =>2,'stackeager'     =>2,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},
# 		  'UNIT' => {'mstproj'     =>17,'mstnonproj'     =>18,'nivreeager'     =>21,'nivrestandard'     =>21,'stacklazy'     =>21,'stackeager'     =>21,'stackproj'     =>21,'planar'     =>21,'2planar'     =>19,'covnonproj'     =>21,'covproj'     =>21},
# 		  'CD' => {'mstproj'     =>257,'mstnonproj'     =>235,'nivreeager'     =>283,'nivrestandard'     =>277,'stacklazy'     =>281,'stackeager'     =>275,'stackproj'     =>277,'planar'     =>278,'2planar'     =>275,'covnonproj'     =>281,'covproj'     =>278},
# 		  'CNJ' => {'mstproj'     =>97,'mstnonproj'     =>103,'nivreeager'     =>80,'nivrestandard'     =>96,'stacklazy'     =>85,'stackeager'     =>82,'stackproj'     =>77,'planar'     =>73,'2planar'     =>78,'covnonproj'     =>82,'covproj'     =>94},
# 		  '.' => {'mstproj'     =>703,'mstnonproj'     =>708,'nivreeager'     =>708,'nivrestandard'     =>708,'stacklazy'     =>708,'stackeager'     =>708,'stackproj'     =>708,'planar'     =>708,'2planar'     =>708,'covnonproj'     =>708,'covproj'     =>708},
# 		  'GR' => {'mstproj'     =>11,'mstnonproj'     =>11,'nivreeager'     =>11,'nivrestandard'     =>11,'stacklazy'     =>11,'stackeager'     =>11,'stackproj'     =>11,'planar'     =>11,'2planar'     =>11,'covnonproj'     =>11,'covproj'     =>11},
# 		  'NT' => {'mstproj'     =>44,'mstnonproj'     =>42,'nivreeager'     =>56,'nivrestandard'     =>55,'stacklazy'     =>56,'stackeager'     =>55,'stackproj'     =>56,'planar'     =>56,'2planar'     =>56,'covnonproj'     =>55,'covproj'     =>56},
# 		  'NAME' => {'mstproj'     =>180,'mstnonproj'     =>173,'nivreeager'     =>198,'nivrestandard'     =>194,'stacklazy'     =>193,'stackeager'     =>198,'stackproj'     =>194,'planar'     =>199,'2planar'     =>198,'covnonproj'     =>197,'covproj'     =>192},
# 		  'ADV' => {'mstproj'     =>183,'mstnonproj'     =>167,'nivreeager'     =>219,'nivrestandard'     =>221,'stacklazy'     =>223,'stackeager'     =>224,'stackproj'     =>220,'planar'     =>199,'2planar'     =>193,'covnonproj'     =>220,'covproj'     =>219},
# 		  'VAUX' => {'mstproj'     =>81,'mstnonproj'     =>76,'nivreeager'     =>86,'nivrestandard'     =>85,'stacklazy'     =>86,'stackeager'     =>86,'stackproj'     =>86,'planar'     =>85,'2planar'     =>83,'covnonproj'     =>87,'covproj'     =>86},
# 		  'P' => {'mstproj'     =>826,'mstnonproj'     =>732,'nivreeager'     =>953,'nivrestandard'     =>950,'stacklazy'     =>955,'stackeager'     =>957,'stackproj'     =>951,'planar'     =>925,'2planar'     =>927,'covnonproj'     =>970,'covproj'     =>954},
# 		  'ADJ' => {'mstproj'     =>171,'mstnonproj'     =>176,'nivreeager'     =>209,'nivrestandard'     =>207,'stacklazy'     =>209,'stackeager'     =>208,'stackproj'     =>206,'planar'     =>206,'2planar'     =>195,'covnonproj'     =>209,'covproj'     =>205},
# 		  'VS' => {'mstproj'     =>78,'mstnonproj'     =>78,'nivreeager'     =>94,'nivrestandard'     =>96,'stacklazy'     =>92,'stackeager'     =>93,'stackproj'     =>96,'planar'     =>93,'2planar'     =>92,'covnonproj'     =>94,'covproj'     =>95},
# 		  'PV' => {'mstproj'     =>337,'mstnonproj'     =>343,'nivreeager'     =>349,'nivrestandard'     =>348,'stacklazy'     =>347,'stackeager'     =>347,'stackproj'     =>348,'planar'     =>344,'2planar'     =>343,'covnonproj'     =>348,'covproj'     =>349},
# 		  'VADJ' => {'mstproj'     =>41,'mstnonproj'     =>40,'nivreeager'     =>41,'nivrestandard'     =>41,'stacklazy'     =>41,'stackeager'     =>41,'stackproj'     =>41,'planar'     =>37,'2planar'     =>35,'covnonproj'     =>41,'covproj'     =>41},
# 		  'PS' => {'mstproj'     =>424,'mstnonproj'     =>417,'nivreeager'     =>428,'nivrestandard'     =>435,'stacklazy'     =>443,'stackeager'     =>443,'stackproj'     =>431,'planar'     =>434,'2planar'     =>427,'covnonproj'     =>441,'covproj'     =>441},);
  
  #Italian
  my %training = ('S' => {'mstproj'     =>1025,'mstnonproj'     =>976,'nivreeager'     =>1076,'nivrestandard'     =>992,'stacklazy'     =>995,'stackeager'     =>81,'stackproj'     =>81,'planar'     =>1077,'2planar'     =>81,'covnonproj'     =>81,'covproj'     =>81},
		  'A' => {'mstproj'     =>277,'mstnonproj'     =>272,'nivreeager'     =>274,'nivrestandard'     =>274,'stacklazy'     =>274,'stackeager'     =>3,'stackproj'     =>3,'planar'     =>275,'2planar'     =>3,'covnonproj'     =>3,'covproj'     =>3},
		  'PU' => {'mstproj'     =>557,'mstnonproj'     =>435,'nivreeager'     =>660,'nivrestandard'     =>660,'stacklazy'     =>662,'stackeager'     =>1,'stackproj'     =>1,'planar'     =>664,'2planar'     =>1,'covnonproj'     =>1,'covproj'     =>1},
		  'N' => {'mstproj'     =>121,'mstnonproj'     =>106,'nivreeager'     =>135,'nivrestandard'     =>136,'stacklazy'     =>136,'stackeager'     =>6,'stackproj'     =>6,'planar'     =>133,'2planar'     =>6,'covnonproj'     =>6,'covproj'     =>6},
		  'P' => {'mstproj'     =>102,'mstnonproj'     =>109,'nivreeager'     =>162,'nivrestandard'     =>120,'stacklazy'     =>128,'stackeager'     =>1,'stackproj'     =>1,'planar'     =>159,'2planar'     =>1,'covnonproj'     =>1,'covproj'     =>1},
		  'E' => {'mstproj'     =>557,'mstnonproj'     =>495,'nivreeager'     =>608,'nivrestandard'     =>586,'stacklazy'     =>581,'stackeager'     =>4,'stackproj'     =>4,'planar'     =>603,'2planar'     =>4,'covnonproj'     =>4,'covproj'     =>4},
		  'B' => {'mstproj'     =>149,'mstnonproj'     =>137,'nivreeager'     =>157,'nivrestandard'     =>148,'stacklazy'     =>150,'stackeager'     =>0,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},
		  'V' => {'mstproj'     =>398,'mstnonproj'     =>415,'nivreeager'     =>464,'nivrestandard'     =>422,'stacklazy'     =>402,'stackeager'     =>226,'stackproj'     =>226,'planar'     =>475,'2planar'     =>226,'covnonproj'     =>226,'covproj'     =>226},
		  'SA' => {'mstproj'     =>2,'mstnonproj'     =>2,'nivreeager'     =>2,'nivrestandard'     =>2,'stacklazy'     =>2,'stackeager'     =>0,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},
		  'C' => {'mstproj'     =>85,'mstnonproj'     =>71,'nivreeager'     =>110,'nivrestandard'     =>94,'stacklazy'     =>95,'stackeager'     =>0,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},
		  'D' => {'mstproj'     =>41,'mstnonproj'     =>37,'nivreeager'     =>41,'nivrestandard'     =>37,'stacklazy'     =>37,'stackeager'     =>0,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},
		  'R' => {'mstproj'     =>328,'mstnonproj'     =>320,'nivreeager'     =>370,'nivrestandard'     =>246,'stacklazy'     =>217,'stackeager'     =>0,'stackproj'     =>0,'planar'     =>0,'2planar'     =>0,'covnonproj'     =>0,'covproj'     =>0},);
  
  foreach my $id ( keys %training ) {
  $fcm->add_document( $id, $training{$id} );
  }
  
  my $num_cluster = 8;
  my $num_iter    = 40;
  $fcm->do_clustering( $num_cluster, $num_iter );
  
 # show clustering result
 foreach my $id ( sort { $a cmp $b } keys %{ $fcm->memberships } ) {
   printf "%s\t%s\n", $id,
   join "\t", map { sprintf "%.4f", $_ } @{ $fcm->memberships->{$id} };
 }
  
  #show cluster centroids
  foreach my $centroid ( @{ $fcm->centroids } ) {
   print join "\t", map { sprintf "%s:%.4f", $_, $centroid->{$_} }
   keys %{$centroid};
   print "\n";
  }
}

sub get_clusters{

  return $fcm;
}

							 1;
							 
							 __END__
							 