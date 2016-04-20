package Treex::Block::W2A::EU::FixMultiwordPrepAndConj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Define the pospositions for basque depending on the case the preceding word should have

# Ablatiboa: -tik +
my $POSP_ABL = qr/^(
aparte|aparteko|   # aparte
arteko|   #arte
at|ateko|   #at
aurrera|   #aurre
barna|barnako|   #barna
barrena|barrenako|   #barrena
behera|   #behe
bezala|bezalako|   #bezala
gertu|gertuko|   #gertu  
gora|gorako|   #gora 
hurbil|hurbileko|hurbilean|   #hurbil
kanpo|kanpora|kanpoko|kanpoan|   #kanpo
salbu|   #salbu
urrun|urruneko| #urrun
urruti|urruneko|   #urrun
zehar|zeharreko   #zehar
)$/x;

# Adlatiboa: -ra +
my $POSP_ALA = qr/^(
arte|  #arte
begira|begirako|   #begira
bezala|bezalako|   #bezala
bitarte|bitartean|bitarteko|   #bitarte
buruz|buruzko|   #buruz
salbu   #salbu
)$/x;

# Absotuiboa: -a/ak +
my $POSP_ABS = qr/^(
aldera|aldetik|   #alde
antzera|   #antz
arte|arteko| # arte
bezala|bezalako|   #bezala
bitarte|bitartean|bitarteko|   #bitarte
gabe|gabeko|   #gabe
inguruan|   #inguru
salbu   #salbu
)$/x; 

# Datiboa: -i/ri +
my $POSP_DAT = qr/^(
begira|begirako|   #begira
bezala|bezalako|   #bezala
buruz|buruzko|   #buruz
esker|eskerreko|   #esker
hurbil|hurbileko|   #hurbil
kontra|kontrako|   #kontra
salbu   #salbu
)$/x;

# Destinatiboa: -rentzat +
my $POSP_DES = qr/^(
bezala|bezalako|   #bezala
salbu   #salbu
)$/x;

# Ergatiboa: -e/ek +
my $POSP_ERG = qr/^(
bezala|bezalako|   #bezala
salbu  #salbu
)$/x;

# Genitiboa: -ren/aren/en +
my $POSP_GEN = qr/^(
alboan|alboko|albora|albotik|   # albo
aldamenean|aldameneko|aldamenera|aldamenetik|   # aldamen
alde|aldean|aldeko|aldera|aldetik|aldez|   # alde
antzean|antzeko|antzera|   #antz
arabera|araberako|   #arabera
artean|arteko|artera|artetik|   #arte
atzean|atzeko|atzera|atzetik|   #atze
aurka|aurkako|   #aurka
aurrean|aurreko|aurrera|aurretik|  #aurre
azpian|azpiko|azpira|azpitik   #azpi
barna|barnako|   #barna
barnean|barneko|barnera|barnetik|   #barne
barrenean|barreneko|barrenera|barrenetik| #barren
barrena|barrenako|   #barrena
barruan|barruko|barrura|barrutik|   #barru
begira|begirako|   #begira
beharrean|    #behar
bidez|   #bide
bila|bilako|   #bila
bitartean|bitartez|   #bitarte
bizkar|bizkarretik|bizkarreko   #bizkar
buruan|burutik|buruz|   #buru
erara|eran|   #era
eskuan|eskuko|eskutik|eskuz|   #esku
gain|gainetik|gainera|gaineko|gainean|   #gain
gisa|gisako|   #gisa
gisara|gisarako|   #gisara
ingurutik|ingurura|inguruko|inguruan|   #inguru
kontra|kontrako|   #kontra
lekuan|   #leku
lepotik|lepora|   #lepo
medio|   #medioz
mendetik|mende|mendera|mendeko|mendean|   #mende
menpetik|menpe|menpera|menpeko|menpean|   #menpe
modura|moduko|moduan|   #modu
ondotik|ondora|ondoko|ondoan|   #ondo
ondoren|ondoreneko|   #ondoren
orde|ordeko|   #orde
ordean|   #ordean
ordez|ordezko|   #ordez
ostetik|ostera|osteko|ostean|   #oste
paretik|pare|parera|pareko|parean|   #pare
partean|partetik|partez|   #parte
petik|pera|peko|pean|   #pe
truke|trukeko|trukean|   #truke
zain   #zain
)$/x;

# Leku genitiboa:  -ko +
my $POSP_GEL = qr/^(
bezala|bezalako|   #bezala
erara   #era
)$/x;

# Inesiboa: +an
my $POSP_INE = qr/^(
barna|barnako|   #barna
barrena|barrenako|   #barrena
behera|   #behe
bezala|bezalako|   #bezala
gora|gorako|   #gora
salbu|   #salbu
zehar|zeharreko   #zehar
)$/x;

# Instrumentala: -z +
my $POSP_INS = qr/^(
aparte|aparteko  #aparte
behera|   #behe
bezala|bezalako   #bezala
gain|gainetik|gainera|gaineko|   #gain
gero|geroko|   #gero
geroztik|geroztiko   #geroztik
gora|gorako|   #gora
kanpo|kanpora|kanpoko|kanpoan|   #kanpo
kontra|kontrako|   #kontra
ostean|  #oste
peko|   #pe
salbu   #salbu
)$/x;

# Kausazkoa: -rengatik +
my $POSP_MOT = qr/^(
bezala|bezalako|   #bezala
salbu   #salbu
)$/x;

# Partitiboa: -rik +
my $POSP_PAR = qr/^(
barik|   #barik
ezean|   #ezean
gabe|gabeko   #gabe
)$/x; 


# Soziatiboa: -rekin +
my $POSP_SOZ = qr/^(
batera|   #bat
bezala|bezalako|   #bezala
salbu   #salbu
)$/x;

# Kasu eza: 0 +
my $POSP_ZERO = qr/^(
alboan|alboko|albora|albotik|   # albo
aldamenean|aldameneko|aldemenera|aldamenetik|   # aldamen
aldean|aldeko|aldera|aldetik|aldez|   # alde
antzean|antzeko|antzera|   #antz
arte|artean|arteko|artera|artetik|   #arte
atzean|atzeko|atzera|atzetik|   #atze
aurrean|aurreko|aurrera|aurretik|  #aurre
azpian|azpiko|azpira|azpitik|   #azpi
barik|bariko|bako|   #barik
barna|barnako|   #barna
barnean|barneko|barnera|barnetik|   # barne
barrenean|barreneko|barrenera|barrenetik| #barren
barrena|barrenako|   #barrena
barruan|barruko|barrura|barrutik   #barru
beharrean|    #behar
behera|   #behe
bezala|bezalako|  #bezala
bidez|   #bide
bila|bilako|   #bila
bitarte|bitartean|bitarteko|    #bitarte
gabe|gabeko|   #gabe
gainetik|gainera|gaineko|gainera|   #gain
gisa|gisako|   #gisa
gisara|gisarako|   #gisara
gora|gorako|   #gora
ingurutik|inguru|ingurura|inguruko|inguruan|   #inguru
kanpotik|kanpora|kanpoko|kanpoan|   #kanpo
legez|legezko|   #legez
ondotik|ondora|ondoko|ondoan|   #ondo
ondoren|ondoreneko|   #ondoren
orde|ordeko|   #orde
ordez|ordezko|   #ordez
ostetik|ostera|osteko|ostean|   #oste
paretik|parera|pareko|parean|   #pare
partean|   #parte
salbu|   #salbu
truke|trukeko|trukean|   #truke
zain|   #zain
zehar|zeharreko   #zehar
)$/x;   

=cas
# Muga adlatiboa: 
my $POSP_ABU = qr/^(
)$/x;

# adlatibo bukatuzkoa
my $POSP_ABZ = qr/^(
)$/x;

# Prolatiboa:
my $POSP_PRO = qr/^(
)$/x;
=cut


# Pospositions for subordinate clauses
# -ela +
my $ERL_KONPL = qr/^(bide|bitarte|kausa|medio)$/;

# -en +
my $ERL_MOD = qr/^(antzera|antzean|arte|bide|bezala|bitartean|eredura|ereduz|gisara|gisan|legez|moldean|moldera)$/;


# Define the cases for basque (ter,lat and ess not included due to them not having pospositions above)
#my @CASE = ('abs','erg','dat','abl','all','gen','ben','ine','loc','ins','cau','par','com','');

# Define the cases for basque subordinate clauses
#my @ERL_CASE = ('mod','erlt','mos','konpl' ,'zhg','helb','mod/denb');

# Define a hash tabele for the pospositions_
#        key: The case of the preceding word
#        value: Array of pospositions for the given case
my %prep_hash=('abs' => $POSP_ABS, # ABS: absolutive / absolutivo / absolutua (NOR)
	       'erg' => $POSP_ERG, # ERG: ergative / ergativo / ergatiboa (NORK)
	       'dat' => $POSP_DAT, # DAT: dative / dativo / datiboa (NORI)
	       'abl' => $POSP_ABL, # ABL: ablative / ablativo / ablatiboa (NONDIK)
#	       'ter' => $POSP_ABU, # ABU: terminal allative / adlativo terminal (NORAINO)
#	       'lat' => $POSP_ABZ, # ABZ: directional allative / adlativo direccional / adlatibo bukatuzkoa (NORANTZ)
	       'all' => $POSP_ALA, # ALA: allative / adlativo / adlatiboa (NORA)
	       'gen' => $POSP_GEN, # GEN: genitive / genitivo / genitiboa (NOREN)
	       'ben' => $POSP_DES, # DES: benefactive / destinativo (NORENTZAT)
	       'ine' => $POSP_INE, # INE: inessive / inesivo / inesiboa (NON)
	       'loc' => $POSP_GEL, # other/case = GEL| BNK | DESK ; @ = GEL | 'BNK' = BNK | 'DESK' = DESK  local genitive / genitivo locativo / leku genitiboa (NONGO)
	       'ins' => $POSP_INS, # INS: instrumental / instrumental / instrumentala (NORTAZ)
	       'cau' => $POSP_MOT, # MOT: causative / motivativo / kausazkoetan (NORENGATIK)
	       'par' => $POSP_PAR, # PAR: partitive / partitivo / partitiboa
#	       'ess' => $POSP_PRO, # PRO: essive / prolativo (NORTZAT)
	       'com' => $POSP_SOZ, # SOZ: comitative / asociativo / soziatiboa (NOREKIN)
	       '' => $POSP_ZERO    # 0
    );

# Define a hash table for the pospositions related to subordinate clasues
#        key: The relation of the clause
#        value: Array of pospositions for the given relation
my %erl_hash=('mod' => $ERL_MOD, # -en +
	      'erlt' => $ERL_MOD, # -en +
	      'mos' => $ERL_MOD, # -en +
	      'zhg' => $ERL_MOD,
	      'helb' => $ERL_MOD,
	      'konpl' => $ERL_KONPL, # -ela +
	      'mod/denb' => $ERL_KONPL
    );



#Function to hang all the children of a node from the head
#   conjPos_node: The node which bears the posposition
#   sub_node: Nodes to be hung under the headposposition ( case node or rel node)
#   mode: Boolean value to control de behaviour of the rehanging
#         0: Relation
#         1: Preposition
sub rehang_nodes{
    my ($conjPos_node, $sub_node, $mode) = @_;
    
    # If the parent of the case|erl node is the posposition itself it is correctly hung
    # Otherwise it needs to be rehung
    if (! $sub_node->get_parent()->equals($conjPos_node)){

	# Two scenarios can happen when rehanging the nodes:
	#    1. The sub_node is a descendant of the conjPos node. 
	#       This case requires the relocation of the subtree going from the conjPos node to the sub_node.
	#       Otherwise moving the conjPos node may lead to a cycle
	#    2. The sub_node is not a descendant of the conjPos node.
	#       In this case the conjPos node can be moved to its position without any further problem

	# Rehang the subtree (case 1) if necessary
	if($sub_node->is_descendant_of($conjPos_node)){

	    # Get the children of the conjPos nodes
	    my @child_nodes = $conjPos_node->get_children({ordered=>1});

	    # Select the children which is an ancestor of the sub_node
	    my @subtree_head_node = grep {$sub_node->is_descendant_of($_) || $_->equals($sub_node) } @child_nodes ; 
	    
	    
	    $subtree_head_node[0]->set_parent($conjPos_node->get_parent()) if($subtree_head_node[0] && ! $subtree_head_node[0]->get_parent()->equals($conjPos_node->get_parent()) );

	}

	# Get the element which will be hung from the postposition node
	my $head_node = $sub_node;

	# If the function of the sub node is Aux or
	# If the function of the sub node is Atr and its parent is a noun the head will be this node
	# i.e: programa bati buruz	
	$head_node=$sub_node->get_parent() if ( ($sub_node->afun ~~ /^Aux.$/) || ( ( $mode eq "1") && ( $sub_node->afun eq "Atr" ) && ($sub_node->get_parent() &&  $sub_node->get_parent()->get_attr("iset/pos") eq "noun" ) ) );
	
	
	# Hang the posposition node from the parent of the sub_node (subtree)
	$conjPos_node->set_parent($head_node->get_parent()) if($head_node->get_parent() && ! $conjPos_node->equals($head_node->get_parent()));
	
	# Hang the sub_node (subtree) from the posposition node
	$head_node->set_parent($conjPos_node) if($head_node->get_parent() && ! $head_node->get_parent()->equals($conjPos_node));
	
	# Set the corresponding afun to the conjPos node
	$conjPos_node->set_afun("AuxP") if ($mode eq "0");
	$conjPos_node->set_afun("AuxC") if ($mode eq "1");
    }
    
    return 1;
    
}



sub process_atree {

    my ( $self, $a_root ) = @_;
    my @anodes = $a_root->get_descendants( { ordered => 1 } );
    
    my $starts_at;
 
    for ( $starts_at = 1; $starts_at <= $#anodes; $starts_at++ ) {

	# index of the word with the relation or case
	my $sub_ind = $starts_at - 1;

	# Get the relation from the wild dump
	my $erl = $anodes[$sub_ind]->wild->{erl};
	
	# Get the case of the preceding word
	my $case = $anodes[$sub_ind]->iset->case;
	
	my $postp = lc( $anodes[$starts_at]->lemma );	    

	# Rehang the nodes
	if($anodes[$starts_at] && $anodes[$sub_ind]){
	    rehang_nodes($anodes[$starts_at],$anodes[$sub_ind],0) if($erl && defined($erl_hash{$erl}) && ($erl_hash{$erl} =~ /\Q$postp\E/));
	    rehang_nodes($anodes[$starts_at],$anodes[$sub_ind],1) if($case && defined($prep_hash{$case}) && ($prep_hash{$case} =~ /\Q$postp\E/));								 
	}

   } # end for

    return 1;
}


1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EU::FixMultiwordPrepAndConj

=head1 DESCRIPTION

Normalizes the way how multiword prepositions (such as
'because of') and subordinating conjunctions (such as
'provided that', 'as soon as') are treated: first token
becomes the head and the other ones become its immediate
children, all marked with AuxC afun. Illusory overlapping
of multiword conjunctions (such as in 'as well as if') is
prevented.

In addition to 'as well/long/soon/far as', other spans
that match the pattern 'as X as Y' are being resolved here.
The involved nodes are reorganized as follows: as1<X as2<Y>>.
Afuns for both 'as' are set.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
