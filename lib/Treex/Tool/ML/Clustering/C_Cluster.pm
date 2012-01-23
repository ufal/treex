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
  
  my %training = ('N' => {'mstproj'     =>821,'mstnonproj'     =>661,'nivreeager'     =>921,'nivrestandard'     =>924,'stacklazy'     =>938,'stackeager'     =>931,'stackproj'     =>924,'planar'     =>895,'2planar'     =>890,},
		  'ITJ' => {'mstproj'     =>151,'mstnonproj'     =>153,'nivreeager'     =>152,'nivrestandard'     =>153,'stacklazy'     =>154,'stackeager'     =>153,'stackproj'     =>149,'planar'     =>153,'2planar'     =>153,},
		  'V' => {'mstproj'     =>305,'mstnonproj'     =>305,'nivreeager'     =>366,'nivrestandard'     =>368,'stacklazy'     =>369,'stackeager'     =>367,'stackproj'     =>365,'planar'     =>365,'2planar'     =>351,},
		  '--' => {'mstproj'     =>5,'mstnonproj'     =>4,'nivreeager'     =>3,'nivrestandard'     =>4,'stacklazy'     =>3,'stackeager'     =>4,'stackproj'     =>1,'planar'     =>4,'2planar'     =>3,},
		  'UNIT' => {'mstproj'     =>17,'mstnonproj'     =>18,'nivreeager'     =>19,'nivrestandard'     =>19,'stacklazy'     =>19,'stackeager'     =>19,'stackproj'     =>19,'planar'     =>18,'2planar'     =>18,},
		  'CD' => {'mstproj'     =>178,'mstnonproj'     =>171,'nivreeager'     =>213,'nivrestandard'     =>211,'stacklazy'     =>210,'stackeager'     =>211,'stackproj'     =>211,'planar'     =>209,'2planar'     =>208,},
		  'CNJ' => {'mstproj'     =>53,'mstnonproj'     =>61,'nivreeager'     =>69,'nivrestandard'     =>75,'stacklazy'     =>70,'stackeager'     =>67,'stackproj'     =>64,'planar'     =>65,'2planar'     =>66,},
		  '.' => {'mstproj'     =>498,'mstnonproj'     =>500,'nivreeager'     =>500,'nivrestandard'     =>500,'stacklazy'     =>500,'stackeager'     =>500,'stackproj'     =>500,'planar'     =>500,'2planar'     =>500,},
		  'GR' => {'mstproj'     =>5,'mstnonproj'     =>5,'nivreeager'     =>5,'nivrestandard'     =>5,'stacklazy'     =>5,'stackeager'     =>5,'stackproj'     =>5,'planar'     =>5,'2planar'     =>5,},
		  'NT' => {'mstproj'     =>45,'mstnonproj'     =>44,'nivreeager'     =>54,'nivrestandard'     =>54,'stacklazy'     =>53,'stackeager'     =>54,'stackproj'     =>54,'planar'     =>53,'2planar'     =>52,},
		  'ADV' => {'mstproj'     =>177,'mstnonproj'     =>163,'nivreeager'     =>201,'nivrestandard'     =>203,'stacklazy'     =>205,'stackeager'     =>204,'stackproj'     =>202,'planar'     =>187,'2planar'     =>188,},
		  'NAME' => {'mstproj'     =>94,'mstnonproj'     =>87,'nivreeager'     =>103,'nivrestandard'     =>101,'stacklazy'     =>102,'stackeager'     =>102,'stackproj'     =>101,'planar'     =>101,'2planar'     =>102,},
		  'VAUX' => {'mstproj'     =>80,'mstnonproj'     =>80,'nivreeager'     =>82,'nivrestandard'     =>81,'stacklazy'     =>81,'stackeager'     =>81,'stackproj'     =>81,'planar'     =>81,'2planar'     =>81,},
		  'P' => {'mstproj'     =>785,'mstnonproj'     =>684,'nivreeager'     =>891,'nivrestandard'     =>884,'stacklazy'     =>900,'stackeager'     =>897,'stackproj'     =>882,'planar'     =>853,'2planar'     =>858,},
		  'ADJ' => {'mstproj'     =>177,'mstnonproj'     =>172,'nivreeager'     =>189,'nivrestandard'     =>189,'stacklazy'     =>189,'stackeager'     =>190,'stackproj'     =>188,'planar'     =>190,'2planar'     =>182,},
		  'VS' => {'mstproj'     =>65,'mstnonproj'     =>64,'nivreeager'     =>72,'nivrestandard'     =>73,'stacklazy'     =>72,'stackeager'     =>72,'stackproj'     =>73,'planar'     =>72,'2planar'     =>72,},
		  'PV' => {'mstproj'     =>330,'mstnonproj'     =>342,'nivreeager'     =>351,'nivrestandard'     =>350,'stacklazy'     =>351,'stackeager'     =>351,'stackproj'     =>344,'planar'     =>348,'2planar'     =>344,},
		  'VADJ' => {'mstproj'     =>52,'mstnonproj'     =>49,'nivreeager'     =>55,'nivrestandard'     =>55,'stacklazy'     =>55,'stackeager'     =>55,'stackproj'     =>55,'planar'     =>54,'2planar'     =>49,},
		  'PS' => {'mstproj'     =>370,'mstnonproj'     =>375,'nivreeager'     =>410,'nivrestandard'     =>401,'stacklazy'     =>402,'stackeager'     =>406,'stackproj'     =>382,'planar'     =>394,'2planar'     =>385,},);
#   
#   #Italian
#   my %training = ('A' => {'mstproj'     =>639,'mstnonproj'     =>629,'nivreeager'     =>639,'nivrestandard'     =>637,'stacklazy'     =>634,'stackeager'     =>642,'stackproj'     =>637,'planar'     =>643,'2planar'     =>645,},
# 		  'S' => {'mstproj'     =>2147,'mstnonproj'     =>2148,'nivreeager'     =>2283,'nivrestandard'     =>2270,'stacklazy'     =>2285,'stackeager'     =>2290,'stackproj'     =>2285,'planar'     =>2287,'2planar'     =>2303,},
# 		  'PU' => {'mstproj'     =>1206,'mstnonproj'     =>1049,'nivreeager'     =>1390,'nivrestandard'     =>1380,'stacklazy'     =>1377,'stackeager'     =>1380,'stackproj'     =>1383,'planar'     =>1390,'2planar'     =>1394,},
# 		  'N' => {'mstproj'     =>233,'mstnonproj'     =>228,'nivreeager'     =>230,'nivrestandard'     =>234,'stacklazy'     =>235,'stackeager'     =>232,'stackproj'     =>232,'planar'     =>230,'2planar'     =>242,},
# 		  'X' => {'mstproj'     =>1,'mstnonproj'     =>0,'nivreeager'     =>1,'nivrestandard'     =>1,'stacklazy'     =>1,'stackeager'     =>1,'stackproj'     =>1,'planar'     =>1,'2planar'     =>1,},
# 		  'P' => {'mstproj'     =>359,'mstnonproj'     =>361,'nivreeager'     =>377,'nivrestandard'     =>370,'stacklazy'     =>374,'stackeager'     =>373,'stackproj'     =>372,'planar'     =>379,'2planar'     =>379,},
# 		  'B' => {'mstproj'     =>387,'mstnonproj'     =>392,'nivreeager'     =>425,'nivrestandard'     =>415,'stacklazy'     =>421,'stackeager'     =>413,'stackproj'     =>412,'planar'     =>424,'2planar'     =>420,},
# 		  'E' => {'mstproj'     =>1136,'mstnonproj'     =>990,'nivreeager'     =>1215,'nivrestandard'     =>1199,'stacklazy'     =>1205,'stackeager'     =>1201,'stackproj'     =>1211,'planar'     =>1213,'2planar'     =>1230,},
# 		  'V' => {'mstproj'     =>849,'mstnonproj'     =>832,'nivreeager'     =>931,'nivrestandard'     =>902,'stacklazy'     =>889,'stackeager'     =>898,'stackproj'     =>910,'planar'     =>918,'2planar'     =>948,},
# 		  'SA' => {'mstproj'     =>2,'mstnonproj'     =>3,'nivreeager'     =>7,'nivrestandard'     =>10,'stacklazy'     =>9,'stackeager'     =>9,'stackproj'     =>10,'planar'     =>8,'2planar'     =>8,},
# 		  'C' => {'mstproj'     =>231,'mstnonproj'     =>216,'nivreeager'     =>314,'nivrestandard'     =>293,'stacklazy'     =>297,'stackeager'     =>305,'stackproj'     =>304,'planar'     =>297,'2planar'     =>293,},
# 		  'D' => {'mstproj'     =>113,'mstnonproj'     =>114,'nivreeager'     =>115,'nivrestandard'     =>116,'stacklazy'     =>117,'stackeager'     =>117,'stackproj'     =>117,'planar'     =>115,'2planar'     =>116,},
# 		  'R' => {'mstproj'     =>809,'mstnonproj'     =>815,'nivreeager'     =>828,'nivrestandard'     =>825,'stacklazy'     =>825,'stackeager'     =>827,'stackproj'     =>826,'planar'     =>830,'2planar'     =>829,},);
  
  foreach my $id ( keys %training ) {
  $fcm->add_document( $id, $training{$id} );
  }
  
  my $num_cluster = 3;
  my $num_iter    = 20;
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
							 