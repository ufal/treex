package Treex::Block::HamleDT::UdepIT;
use utf8;
use open ':utf8';
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::PragueToUD;
extends 'Treex::Core::Block';

#!!!To avoid non-useful warnings
no warnings qw(uninitialized);

has store_orig_filename => (is=>'ro', isa=>'Bool', default=>1);

has 'last_loaded_from' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'     => ( is => 'rw', isa => 'Int', default => 0 );

#We open a file to signal cases where we can not disambiguate the sentence's structure automatically and require manual intervention
open my $log, ">", 'Cases_for_manual_intervention.txt' or die 'The "cases" file can not be opened!' ;

#------------------------------------------------------------------------------
# Reads a Prague-style tree and transforms it to Universal Dependencies.
#------------------------------------------------------------------------------
sub process_atree {
    my ($self, $root) = @_;

    log_warn("Sentence ".$root->id()) ;


    # Add the name of the input file and the number of the sentence inside
    # the file as a comment that will be written in the CoNLL-U format.
    # (In any case, Write::CoNLLU will print the sentence id. But this additional
    # information is also very useful for debugging, as it ensures a user can find the sentence in Tred.)
    if ($self->store_orig_filename){
        my $bundle = $root->get_bundle();
        my $loaded_from = $bundle->get_document()->loaded_from(); # the full path to the input file
        my $file_stem = $bundle->get_document()->file_stem(); # this will be used in the comment
        if($loaded_from eq $self->last_loaded_from()) {
            $self->set_sent_in_file($self->sent_in_file() + 1);
        } else {
            $self->set_last_loaded_from($loaded_from);
            $self->set_sent_in_file(1);
        }
        my $sent_in_file = $self->sent_in_file();
        my $comment = "orig_file_sentence $file_stem\#$sent_in_file";
        my @comments;
        if(defined($bundle->wild()->{comment})) {
            @comments = split(/\n/, $bundle->wild()->{comment});
        }
        if (! any {$_ eq $comment} (@comments)) {
            push(@comments, $comment);
            $bundle->wild()->{comment} = join("\n", @comments);
        }
    }

    
    # Now the harmonization proper.
    $self->exchange_tags($root);
    $self->fix_symbols($root);
    $self->fix_annotation_errors($root);
    #
    $self->remove_coordination_from_root($root) ; 
    $self->reattach_overabundant_node_children($root) ;
    $self->treat_coordination_chains($root) ;
    $self->treat_apposition($root) ;
    #
    $self->convert_deprels($root);
    $self->remove_null_pronouns($root);
    $self->relabel_appos_name($root);
    # The most difficult part is detection of coordination, prepositional and
    # similar phrases and their interaction. It will be done bottom-up using
    # a tree of phrases that will be then projected back to dependencies, in
    # accord with the desired annotation style. See Phrase::Builder for more
    # details on how the source tree is decomposed. The construction parameters
    # below say how should the resulting dependency tree look like. The code
    # of the builder knows how the INPUT tree looks like (including the deprels
    # already converted from Prague to the UD set).
    my $builder = Treex::Tool::PhraseBuilder::PragueToUD->new(
        'prep_is_head'           => 0,
        'cop_is_head'            => 0,
        'coordination_head_rule' => 'first_conjunct',
        'counted_genitives'      => $root->language ne 'la'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # The 'cop' relation can be recognized only after transformations.
    $self->tag_copulas_aux($root);
    # Look for prepositional objects (must be done after transformations).
    $self->relabel_prepositional_objects($root);
    $self->change_case_to_mark_under_verb($root);
    $self->dissolve_chains_of_auxiliaries($root);
    $self->fix_jak_znamo($root);
    $self->classify_numerals($root);
    $self->relabel_subordinate_clauses($root);
    #
    #$self->relabel_elliptical_comparative_constructions($root);
    $self->treat_gerundive_passive_periphrastics($root);
    $self->correct_false_indirect_objects($root);
    $self->post_treatment_of_appositions($root) ;
    #
    $self->check_ncsubjpass_when_auxpass($root);
    $self->raise_punctuation_from_coordinating_conjunction($root);
    #
    ###!!! The EasyTreex extension of Tred currently does not display values of the deprel attribute.
    ###!!! Copy them to conll/deprel (which is displayed) until we make Tred know deprel.
    my @nodes = $root->get_descendants({'ordered' => 1});
    if(1)
    {
        foreach my $node (@nodes)
        {
            my $upos = $node->iset()->upos();
            my $ufeat = join('|', $node->iset()->get_ufeatures());
            $node->set_tag($upos);
            $node->set_conll_cpos($upos);
            $node->set_conll_feat($ufeat);
            $node->set_conll_deprel($node->deprel());
            $node->set_afun(undef); # just in case... (should be done already)
        }
    }
    # Some of the above transformations may have split or removed nodes.
    # Make sure that the full sentence text corresponds to the nodes again.
    ###!!! Note that for the Prague treebanks this may introduce unexpected differences.
    ###!!! If there were typos in the underlying text or if numbers were normalized from "1,6" to "1.6",
    ###!!! the sentence attribute contains the real input text, but it will be replaced by the normalized word forms now.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Replaces the tag from the original corpus by the corresponding Universal POS
# tag; saves the original tag in conll/pos instead. This would be done also in
# Write::CoNLLU. But even if we write Treex and view it in Tred, we want the UD
# tree to display the UPOS tags.
#------------------------------------------------------------------------------
sub exchange_tags
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $original_tag = $node->tag();
        $node->set_tag($node->iset()->get_upos());
        ###!!! Do not do this now! If we were converting via Prague, the $original_tag now contains a PDT-style tag.
        ###!!! On the other hand, already the Prague harmonization stored the really original tag in conll/pos.
        #$node->set_conll_pos($original_tag);
    }
}



#------------------------------------------------------------------------------
# Some treebanks do not distinguish symbols from punctuation. This method fixes
# this for a few listed symbols. Some other treebanks tag symbols as the words
# they substitute for (e.g. '%' is NOUN but it should be SYM).
#------------------------------------------------------------------------------
sub fix_symbols
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # '%' (percent) and '$' (dollar) will be tagged SYM regardless their
        # original part of speech (probably PUNCT or NOUN). Note that we do not
        # require that the token consists solely of the symbol character.
        # Especially with '$' there are tokens like 'US$', 'CR$' etc. that
        # should be included.
        if($node->form() =~ m/[\$%]$/)
        {
            $node->iset()->set('pos', 'sym');
            # If the original dependency relation was AuxG, it should be changed but there is no way of knowing the correct relation.
            # The underlying words are nouns, hence they could be Sb, Obj, Adv, Atr, Apposition or even Pnom.
        }
        elsif($node->is_punctuation())
        {
            # Note that some characters cannot be decided in this simple way.
            # For example, '-' is either punctuation (hyphen) or symbol (minus)
            # but we cannot tell them apart automatically if we do not understand the sentence.
            if($node->form() =~ m/^[\+=]$/)
            {
                $node->iset()->set('pos', 'sym');
                if($node->deprel() eq 'AuxG')
                {
                    $node->set_deprel('AuxY');
                }
            }
            # Slash '/' can be punctuation or mathematical symbol.
            # It is difficult to tell automatically but we will make it a symbol if it is not leaf (and does not head coordination).
            elsif($node->form() eq '/' && !$node->is_leaf() && $node->deprel() !~ m/^(Coord|Apos)$/)
            {
                $node->iset()->set('pos', 'sym');
                if($node->deprel() eq 'AuxG')
                {
                    $node->set_deprel('AuxY');
                }
                my $parent = $node->parent();
                my @children = $node->children();
                foreach my $child (@children)
                {
                    $child->set_parent($parent);
                }
            }
        }
        # The letter 'x' sometimes substitutes the multiplication symbol '×'.
        elsif($node->form() eq 'x' && $node->is_conjunction())
        {
            $node->iset()->set('pos', 'sym');
            if($node->deprel() eq 'AuxG')
            {
                $node->set_deprel('AuxY');
            }
        }
    }
}

#------------------------------------------------------------------------------
#We have to solve the very frequent case in which a sentence begins with a co-ordination linking 
#it with the previous sentence, whose child node is not labelled as a member. Such a "root co-ordination"
#should modify the whole sentence. It needs to be made a leaf of its only child. 
#We have to take into account that HarmonizeIT changed the deprel from Coord to AuxY.
#root->Coord->...
#------------------------------------------------------------------------------

sub remove_coordination_from_root
{

	#log_warn('Checking for false root co-ordinations...') ;
	my $self = shift;
	my $root = shift;

	my @root_coords = grep {$_->is_coordinator()} $root->children() ;

	if(scalar(@root_coords)==1)
	{
		my $root_coord = $root_coords[0] ;
		#log_warn('False root co-ordination detected: '.$root_coord->form()) ;
		
		my @root_coord_members = grep {$_->is_member()} $root_coord->children() ;
		my @root_coord_coord = grep {lc($_->deprel()) eq 'coord'} $root_coord->children() ;

		my @root_coord_children = sort {$a->ord() <=> $b->ord()} $root_coord->children() ;

		if(!@root_coord_members)
		{
			#This first case is actually redundant; coord children can be treated like every other node
			if(scalar(@root_coord_coord)==1000)
			{
				my $new_root = $root_coord_coord[0] ;
				$new_root->set_parent($root) ;
				$root_coord->set_parent($new_root) ;
				log_warn('False root co-ordination '.$root_coord->form().' moved down the tree') ;
				
			}
			elsif(scalar(@root_coord_children)==1)
			{
				$root_coord_children[0]->set_is_member(1) ;
				$root_coord->set_deprel('Coord') ;
				log_warn('False root co-ordination '.$root_coord->form().' assigned a member') ;
			}
			
			
		}
	}
}


#------------------------------------------------------------------------------
#Appositions in PDT have a structure similar to co-ordinations, but their members are not at the same levels, 
#so we have to restructure them before applying the UD conversion 
#------------------------------------------------------------------------------
sub treat_apposition
{
	my $self = shift;
	my $root = shift;

	my @sentence = ($root, $root->get_descendants()) ;
	
	foreach my $node (@sentence)
	{

		my $coordinated_app = $node->is_member() && $node->parent()->deprel() eq 'Coord' ;
log_warn('Appositivo: '.$node->form().' , '.$node->wild()->{apos}) if(exists($node->wild()->{apos})) ;
log_warn('Copulativo: '.$node->form().' , '.$node->wild()->{appcop}) if(exists($node->wild()->{appcop})) ;

		#We reattach annoying AuxZ like non to the first apposition members to avoid interferences
		if($node->wild()->{apos} eq 'apposed' && any {!$_->is_member() && $_->deprel() eq 'Neg'} $node->children())
		{
			my @app_memb = sort {$a->ord() <=> $b->ord()} grep {$_->is_member()} $node->children() ;
			my $good_memb = $app_memb[0]->deprel!~m/Aux[CP]/ ? $app_memb[0] :
					(sort {$a->ord() <=> $b->ord()} grep {$_->deprel()!~m/Aux[CP]/} $app_memb[0]->children())[0] ; 
log_warn('Un buon partito: '.$good_memb->form()) ;
			foreach my $non (grep {!$_->is_member() && $_->deprel() eq 'Neg'} $node->children()) 
			{
				$non -> set_parent($good_memb) ;
			}
		}

		#Treating copulae, so that they pass thei appos-ity to the actual predicate
		if($node->lemma() eq 'sum' && $node->wild()->{apos} eq 'apped')
		{
			my @pnom_child = sort {$a->ord() <=> $b->ord()} grep {lc($_->deprel()) eq 'pnom'} $node->children() ;
	
			if(@pnom_child)
			{
				$node->wild()->{apos} = '' ;
				$pnom_child[0]->wild()->{apos} = 'apped' ;	
				$pnom_child[0]->wild()->{appcop} = 'cop' ;
log_warn('Riaggiustato: '.$node->form().' , '.$node->wild()->{apos}.' , '.$pnom_child[0]->form().' , '.$pnom_child[0]->wild()->{apos});			
			}
		}

		
		#The children of an apposal co-ordination are part of the apposition, too
		if($node->wild()->{apos} eq 'apped' && $node->deprel() eq 'Coord')
		{
			foreach my $coappnode (grep {$_->is_member()} $node->children())
			{
				$coappnode->wild()->{apos} = 'apped' ;
			}	
		}
		elsif(exists($node->wild()->{apos}) && $node->wild()->{apos} eq 'apposed')
		{
			log_warn("Restructured apposition at ".$node->form()) ;	

#my @coform = map {$_->form(),$_->deprel(),$_->is_member(),$_->wild()->{apos}} $node->children(); log_warn("Discendenti: ".($node->form())." -> "."@coform");			

			#What follows tries to identify the splitting point between the node and its apposition; usually given by a punctuation
			#mark before the connecting element 
			my @kids = $node->children ;
	
			my @members_indices = grep {$kids[$_]->is_member()} 0..$#kids ; 
			my $head_index = $members_indices[0] ;
			my $head = $kids[$head_index] ; 
			my $posthead_index = $members_indices[$#members_indices] ;
			my $posthead = $kids[$posthead_index] ; 

			if($head_index == $posthead_index)
			{
				log_warn("Error: Apposition with a single member!") ;
				return;
			}

			my @nucleus = @kids[$head_index+1 .. $posthead_index-1] ; 

			my $punct_index = 0 ;
			if(@nucleus)
			{
				$punct_index = scalar(@nucleus)-1 ;
				--$punct_index until $nucleus[$punct_index]->deprel() eq 'AuxX' || $punct_index == 0 ;
			}


			my @pre_appos = @kids[0 .. $head_index+$punct_index] ;
			my @post_appos = @kids[ $head_index+$punct_index+1 .. $#kids] ;


			#foreach my $appnode (reverse $node->children())
			#{
				
				
				#if($appnode->ord()<$node->ord() && !($appnode->deprel() eq 'AuxX' && ( $appnode->ord()==$node->ord()-1 || ) ) )
				#{
				#	push @pre_appos, $appnode ;
				#}
				#else
				#{
				#	push @post_appos, $appnode ;
				#}
			#}

#my @appmembri = grep {$_->is_member()} $node->children() ; 
#my @appm = map {$_->form()} @appmembri; log_warn("Membri dell'apposizione: ".($node->form())." -> "."@appm");
#my @comemb = map {$_->form()} @pre_appos; log_warn("Argomento: ".($node->form())." -> "."@comemb");
#my @superf = map {$_->form()} @post_appos; log_warn("Apposto: ".($node->form())." -> "."@superf");

			#my $head_index = 0 ;
			#++$head_index until $pre_appos[$head_index]->is_member() ;
			#my $head = $pre_appos[$head_index] ;

			#my $posthead_index = 0 ;
			#++$posthead_index until $post_appos[$posthead_index]->is_member() ;
			#my $posthead = $post_appos[$posthead_index] ;



#log_warn("Testa: ".$head->form()) ;
#log_warn("Coda: ".$posthead->form()) ;



			splice @pre_appos, $head_index, 1 ;
			#splice @post_appos, $posthead_index, 1 ;
			splice @post_appos, scalar(@nucleus)-$punct_index, 1 ;

			foreach my $subappnode (@pre_appos)
			{
				$subappnode->set_parent($head) ;
				log_warn("Pre-reattached ".$subappnode->form()." to ".$head->form()) ;
			}

			$head->set_parent($node->parent()) ; 
			$head->set_is_member(1) if($coordinated_app) ;
			log_warn("Head ".$head->form()." reattached to ".($node->parent()->is_root() ? 'root' : $node->parent()->form())) ;
			$posthead->set_parent($head) ;
			log_warn("Apposition ".$posthead->form()." reattached to ".$head->form()) ;

			$node->parent()->wild()->{apos} = 'apposited' ;

			#the "scilicet" element must not depend on a function word, lest the structure is later wrongly reinterpreted
			#Anomalous case in the IT-TB: habet as Apos in "per hoc autem evacuatur quorundam philosophorum..."
			my $newnodeparent = $posthead ;
			while($newnodeparent->children() && $newnodeparent->deprel()=~m/^(Aux|Coord)/i)
			{
				$newnodeparent = (sort {$a->ord() <=> $b->ord()} 
					grep {$_->deprel()!~m/^(Aux|Coord)/i || $_->children()} $newnodeparent->children())[0] ;
			}
			$node->set_parent($newnodeparent) ;

			$node->wild()->{apos} = 'apponent' ;
			log_warn("Connector ".$node->form()." reattached to ".$newnodeparent->form()) ;
			$node->set_is_member(undef) if($coordinated_app) ;

			foreach my $subappnode (@post_appos)
			{
				$subappnode->set_parent($posthead) ;
				log_warn("Post-reattached ".$subappnode->form()." to ".$posthead->form()) ;
			}

#log_warn("->".$node->form()." , ".$node->wild()->{apos}) ;		
#my @supperf = map {$_->form(),$_->deprel(),$_->wild()->{apos}} $head->children(); log_warn("Postumi: ".($head->form())." -> "."@supperf");



		}
	}

}



#------------------------------------------------------------------------------
#Sub detect_root_phrase in Treex::Tool:PhraseBuilder::PrageuToUD checks for phrases attached to the root and chooses
#the leftmost one as the only root's child, reattacing the others. This interacts badly with elliptic verbal constructions like 
#"ad quintum dicendum quod...", where dicendum should be the root, but ad quintum is chosen. This happens because 
#an "est", which would be the direct son of the root, is missing, and so dependencies collapse onto the (artificial) root.
#We reduce all the roots with more than one children to having only one.
#We perform the same operation for all nodes having elliptical children, whenever this is possible.
#Co-ordinative structures need a special treatment: before conflating nodes together, we make an estimate of how many members there might be
#------------------------------------------------------------------------------
sub reattach_overabundant_node_children
{
	my $self = shift;
	my $root = shift;

	#Precedences for promotion in case of ellipsis, as from the documentations
	#Readpated for POS tags as we perform this operation before deprel conversion

	my @sentence = ($root, $root->get_descendants()) ;

	foreach my $node (@sentence)
	{

		#This process must not be repeated recursively on nodes that have already been subject to an ellipsis rearrangement
		next if($node->wild()->{rearranged}) ;

		my @children = $node->children() ;
		my $verbal_root = $node->is_verb() ;

		#We have to consider prepositional phrases or phrases introduced by a subordinative conjunction
		#We also consider co-ordinated phrases in the ellipsis
		#We need to refer to the children of possible AuxP, AuxC and co-ordinations.
		my %mapnodes = () ;
		for(my $i = 0; $i<=$#children; $i++)
		{
			if(lc($children[$i]->deprel()) eq 'coord')
			{
				my @coordchildren = grep {$_->is_member()} $children[$i]->children() ; #!!!Only limited to members?
				$mapnodes{$i} = (all {$_->iset()->{pos} eq $coordchildren[0]->iset()->{pos}} @coordchildren ) ? 						$coordchildren[0] : $children[$i] ;
			}
			elsif($children[$i]->deprel()=~m/^Aux[CP]/)
			{
				my @ExDdependents = grep {$_->deprel() eq 'ExD'} $children[$i]->children() ;
				$mapnodes{$i} = @ExDdependents ? $ExDdependents[0] : $children[$i] ;
			}
			else
			{
				$mapnodes{$i} = $children[$i] ;
			}
		}

		my $is_et = lc($node->deprel()) eq 'coord' ;
		my $is_apos = exists($node->wild()->{apos}) && $node->wild()->{apos} eq 'apposed' ;
		my @coord_members = grep {$_->is_member()} @children ;
		my @coord_members_indexes = grep {$children[$_]->is_member()} 0..$#children ;
		
		#First indices...
		my @ExDs = grep { $mapnodes{$_}->deprel() eq 'ExD'} 0..$#children ;
		my @ExDssurface =  map { $children[$_] } @ExDs ;
		#... then actual nodes, modulo co-ordinations
		@ExDs = map { (lc($children[$_]->deprel()) eq 'coord') ? $mapnodes{$_} : $children[$_] } @ExDs ;
		
		my $allmembersExDs = all {$mapnodes{$_}->deprel() eq 'ExD' } @coord_members_indexes ;

#log_warn(scalar(@coord_members)) if(@coord_members);
#my @comemb = map {$_->form()} @coord_members; log_warn("Membri coord: ".($node->form())." -> "."@comemb");
#my @superf = map {$_->form()} @ExDs; log_warn("ExD profondi: ".($node->form())." -> "."@superf");
#@superf = map {$_->form()} @ExDs; log_warn("ExD profondi: ".($node->deprel())." -> "."@superf");
#log_warn("Membri: ".scalar(@coord_members)." ExD: ".scalar(@ExDs)." ".$allmembersExDs);
		
		#We try an estimate of how many co-ordination members the ExD nodes will form
		my $estimate = 1 ;
		if($is_et && scalar(@ExDs) > 1)
		{

			my @sorted_children = sort {$a->ord() <=> $b->ord()} @children ;
#my @sorci = map {$_->form()} @sorted_children; log_warn("Figli coord: ".($node->form())." -> "."@sorci");
			my @sorted_members = grep {$sorted_children[$_]->is_member()} 0..$#children ;
			my $leftmost_member = $sorted_members[0] ; 
			splice @sorted_children, 0, $leftmost_member+1 ; 

#@sorci = map {$_->form()} @sorted_children; log_warn("Figli coord: ".($node->form())." -> "."@sorci");
#@sorci = map {$_->deprel()} @sorted_children; log_warn("Figli coord: ".($node->form())." -> "."@sorci");
#log_warn("Taglio: "."$leftmost_member");

			my $notExDmembers = scalar(grep {$children[$_]->is_member() 
							&& !($mapnodes{$_}->deprel() eq 'ExD')} 0..$#children) ;


			#Only commas are accepted as AuxX's according to the guidelines, but we have other punctuation signs sometimes
			my $coord_auxx_ne = scalar(grep {$_->deprel() eq 'AuxX'
							&& $_->lemma() ne $node->lemma()} @sorted_children) ;
			my $coord_auxx_eq = scalar(grep {$_->deprel() eq 'AuxX'
							&& $_->lemma() eq $node->lemma()} @sorted_children) ;
			my $coord_auxy = scalar(grep {$_->lemma()=~m/^(aut|et|nec|neque|quam|sive|vel|velut|tam)$/ 
							&& $_->deprel() eq 'AuxY'} @sorted_children) ; 
			
			#print $log "$coord_auxx_ne, $coord_auxx_eq, $coord_auxy, $notExDmembers \n" ;
		
			$coord_auxx_ne = max($coord_auxx_ne-1, 0) ; #$coord_auxx_ne > 0 ? $coord_auxx_ne - 1 : 0 ;

			$estimate = 2 + $coord_auxx_eq + $coord_auxy + $coord_auxx_ne - $notExDmembers ;

			#We report unsolvable cases to the log.
			if($estimate > 1)
			{

				my $warning = $estimate == scalar(@ExDs) ?
					"W#2: ExD co-ordination should have been handled correctly automatically for sentence ".$root->id()."\n"
				      : "W#1: Possibly manual disambiguation needed for sentence ".$root->id()."\n" ;
				print $log $warning ;
				my $ExDestimate = max(2, int(scalar(@ExDs)/2)) ;
				print $log "Estimated elliptical co-ordination members: ".$estimate." of possible ".$ExDestimate." to ".scalar(@ExDs)."\n" ;
				print $log "Co-ordination root: ".($node->is_root() ? "root" : $node->form())."\n";
				my @chforms = map {$_->form()} sort {$a->ord() <=> $b->ord()} @children ;
				print $log "Children: @chforms \n" ;
				print $log "\n\n";	
			}




		}


		#If the node is a co-ordination, it must retain at least two member children.
		#If there are more than three children and all of them are "elliptical" (= ExDs), we can not decide
		#a sensible repartition a priori and keep the children isolated
		#Nodes (AuxP, AuxC, Coord) which are parents of other co-ordinated members already obtained
		#a true is_member value during harmonization to Prague
		if(scalar(@ExDs) > 1 && !( $is_et && $allmembersExDs) && !( $is_apos && scalar(@coord_members)==2) && $estimate==1 )
		#!($is_et && scalar(@coord_members) == 2)#!($is_et && scalar(@coord_members) == scalar(@ExDs)))
		{

			#For the log
			print $log "W#3: ExD co-ordination should have been handled correctly for sentence ".$root->id()." (only one member)\n" ;
			print $log "Co-ordination root: ".($node->is_root() ? "root" : $node->form())."\n";
			my @chforms = map {$_->form()} sort {$a->ord() <=> $b->ord()} @children ;
			print $log "Children: @chforms \n" ;
			#

			my @verbals = grep {$_->is_verb() && !$_->is_infinitive()} (@ExDs) ;
			#Adjectives, nouns and pronouns all take declensions and behave in a similar way 
			#(We mirror here the tripartite classification of Index Thomisticus.)
			my @nominals = grep {$_->is_noun() || $_->is_pronoun() || $_->is_adjective()} (@ExDs) ;
			my @obliques = grep {$_->is_adposition()} (@ExDs) ;
			my @adverbials = grep {$_->is_adverb()} (@ExDs) ;
			my @infinitives = grep {$_->is_verb() && $_->is_infinitive()} (@ExDs) ;
			my @conjunctivals = grep {$_->is_conjunction()} (@ExDs) ;

			my @forms = map {$_->form()} @ExDs; log_warn(($node->form())." -> "."@forms");
			my @deprels = map {$_->deprel()} @ExDs; log_warn(($node->deprel())." -> "."@deprels");

			print $log "Probable verb ellipsis\n" if (!$verbal_root) ;
			print $log "Probable noun ellipsis\n" if ($verbal_root) ;
			my $logwarn = '' ;

			if(@verbals)
			{ 
				my $verbindex = (grep {$ExDs[$_]->is_verb() && !($ExDs[$_]->is_infinitive())} 0..$#ExDs)[0] ;
				my $newroot = splice @ExDssurface , $verbindex, 1 ;
				#This process must not be repeated on elliptical nodes that were already rearranged
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{ 
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;
					
					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}

					#In the case of gerundives or participles, the ellipsis is that of an auxiliary and the head 
					#will be the verbal form in any case
					if(!($newroot->conll_feat()=~m/(modD|modM|modE|modN|modO|modP|modG)/))
					{
						$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
						$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/
										&& !!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC')) ;
					}
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}		
			}
			#The preferential order for POS's is noun, pronoun, adjective
			#The preferential order for cases is nominative, accusative, dative, ablative, genitive
			#Case trumps part of speech
			elsif(@nominals)
			{
				my @nounindexes = grep {$ExDs[$_]->is_noun() || $ExDs[$_]->is_pronoun() || $ExDs[$_]->is_adjective()} 0..$#ExDs ;

				my @nounroot = grep {$ExDs[$_]->iset()->case() eq 'nom'} @nounindexes ;
				@nounroot = (grep {$ExDs[$_]->iset()->case() eq 'acc'} @nounindexes) if(!@nounroot) ;
				@nounroot = (grep {$ExDs[$_]->iset()->case() eq 'dat'} @nounindexes) if(!@nounroot) ;
				@nounroot = (grep {$ExDs[$_]->iset()->case() eq 'abl'} @nounindexes) if(!@nounroot) ;
				@nounroot = (grep {$ExDs[$_]->iset()->case() eq 'gen'} @nounindexes) if(!@nounroot) ;
	
				my @nounroot_best = (grep {$ExDs[$_]->is_noun()} @nounroot) ;
				@nounroot_best = (grep {$ExDs[$_]->is_pronoun()} @nounroot) if(!@nounroot_best) ;
				@nounroot_best = (grep {$ExDs[$_]->is_adjective()} @nounroot) if(!@nounroot_best) ;

				my $newroot = splice @ExDssurface , $nounroot_best[0], 1 ;
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;

					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}

					$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/ 
										&& !($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}		
			}
			elsif(@obliques)
			{
				my $oblindex = (grep {$ExDs[$_]->is_adposition()} 0..$#ExDs)[0] ;
				my $newroot = splice @ExDssurface , $oblindex, 1 ;
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;
					
					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}
					$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/
										&& !($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC')) ;
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}					
			}
			elsif(@adverbials)
			{
				my $adverbindex = (grep {$ExDs[$_]->is_adverb()} 0..$#ExDs)[0] ;
				my $newroot = splice @ExDssurface , $adverbindex, 1 ;
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;

					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}

					$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/
										&& !($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}		
			}
			elsif(@infinitives)
			{
				my $infindex = (grep {$ExDs[$_]->is_verb() && $ExDs[$_]->is_infinitive()} 0..$#ExDs)[0] ;
				my $newroot = splice @ExDssurface , $infindex, 1 ;
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;

					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}

					$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/
										&& !($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC')) ;
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}		
			}
			elsif(@conjunctivals)
			{
				my $conjindex = (grep {$ExDs[$_]->is_conjunction()} 0..$#ExDs)[0] ;
				my $newroot = splice @ExDssurface , $conjindex, 1 ;
				$newroot->wild()->{rearranged} = 'rearranged' ;
				foreach my $nvb (@ExDssurface)
				{
					$nvb->set_parent($newroot) ;
					$nvb->set_is_member(undef) ;

					my $nnvb = $nvb ;
					while($nnvb->deprel()!~m/ExD/i)
					{
						$nnvb = (sort {$a->ord() <=> $b->ord()} 
								grep {$_->deprel() eq 'ExD' || $_->children()} $nnvb->children())[0] ;
					}

					$nnvb->wild()->{toExD} = 'orphan' if(!($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$nnvb->set_deprel('orphan') if($nnvb->iset()->{pos}=~m/(noun|adj|adv|verb|pron)/
										&& !($nnvb->ord() == $nvb->ord() || $nvb->deprel() eq 'AuxC'));
					$logwarn = "Overcrowded node (ellipsis?): reattached ".$nvb->form()." to ".$newroot->form()
							.($node->is_root() ? " at root" : "") ;
				}		
			}
			#In any remaining (improbable) case, nothing is done.
			else
			{
				;
			}

			print $log $logwarn ;
			print $log "\n\n";

		}
	}
}

#------------------------------------------------------------------------------
#We try to solve the problem of co-ordinations which are themselves part of other co-ordinations
#by readjusting the tree in a fashion more similar to UD. This will also help later
#during deprel conversion, when adjudicating deprels on the basis of parent nodes features.
#- Also:
#Sometimes a parenthetical clause presents a co-ordination (true, with actual members, or at sentence level),
#but since members are not always labelled as such, while the conjunction is, 
#co-ordinating elements are wrongly attached to the preceeding node.
#- Also:
#We identify the case of a negation non modifying a co-ordination member that is itself introduced by an AuxC or AuxP element. 
#This causes an interference in the conversion process, so that non ends up as the head of its modified member.
#Therefore, we reattach it to the _Co node before the conversion takes place.
#At this point, the AuxY afun of non was already changed to Neg
#- Also:
#It might happen that the member of a co-ordination is introduced by an Aux which is the head of another co-ordination. In 
#this case, the membership of the Aux gets lost. We try to restore it.
#------------------------------------------------------------------------------
sub treat_coordination_chains
{
	my $self = shift;
	my $root = shift;

	my @sentence = ($root, $root->get_descendants()) ;
	
	foreach my $node (@sentence)
	{ 
		my $coord = lc($node->deprel()) eq 'coord' ;
		my $appo = $node->wild()->{apos} eq 'apposed' ;
		my @membra = grep {$_->is_member()} $node->children() ;
		my @membra_aux = grep {$_->is_member() && lc($_->deprel())=~m/aux[pc]/} $node->children() ;
		my @coord_children = grep {lc($_->deprel()) eq 'coord'} $node->children() ;
		my @parenth = grep {$_->is_parenthesis_root()} $node->children() ;

		if($coord && scalar(@membra)<=1 && scalar(@coord_children)==1)
		{
			log_warn('Set membership in co-ordination chain '.$node->form().' -> '.$coord_children[0]->form()) ;
			$coord_children[0]->set_is_member(1) ;

		}
		elsif($coord && !@membra && @parenth )
		{
			foreach my $parino (@parenth)
			{
				$parino->set_is_member(1) ;
			}
		}
		
		if( $coord && @membra_aux)
		{
			foreach my $aux_co (@membra_aux)
			{
				my @non = grep {$_->deprel()=~m/(Neg|Adv)/ && !$_->is_verb() && !$_->is_noun() && !$_->is_pronoun() && !$_->is_adjective()} $aux_co->children() ;	
				my @non_non = grep {$_->deprel()!~m/(Neg|Adv)/ || $_->is_verb() || $_->is_noun() || $_->is_pronoun() || $_->is_adjective() } $aux_co->children() ;
				
				if(@non && $non_non[0])
				{
					foreach my $nn (@non)
					{
						$nn->set_parent($non_non[0]) ;
					}
				}

			}
		}
		
		if($coord && @membra && defined($node->parent()->parent()))
		{
			my $grandparent = $node->parent()->parent() ;
			my $parent = $node->parent() ;

			if($grandparent->deprel() eq 'Coord' && !$parent->is_member() && $parent->deprel()=~m/Aux[P|C]/)
			{
				$parent->set_is_member(1) ;
			}			
		}
	}

}


#------------------------------------------------------------------------------
# Convert analytical functions to universal dependency relations.
# This new version (2015-03-25) is meant to act before any structural changes,
# even before coordination gets reshaped.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    # We will need to query the original Prague deprel (afun) of parent nodes in certain situations.
    # It will not be guaranteed that the parent deprel has not been converted by then. Therefore we will make a copy now.
    # Make sure that the copy is defined even if the parent is root.
    $root->wild()->{prague_deprel} = 'AuxS';
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel() // '';
        $node->wild()->{prague_deprel} = $deprel;
    }
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        $deprel = '' if(!defined($deprel));
        my $parent = $node->parent();

#log_warn("Nodo ".$node->form().", ".$node->deprel()." ".($node->is_coordinator()? '(coordina)' : '(niente)').", discende da ".$parent->form());
#my @cform = map {$_->form(),$_->is_member()} $node->children() ; log_warn("Figli: @cform") ;
#log_warn('Nodo '.$node->form().', ellissi: '.$node->wild()->{toExD});
	#We have to construct some instruments to treat co-ordinations: 
	#if the node is a member, the true parent is one or more levels upwards in the tree;
	#if the node is a shared modifier of co-ordinated elements, it shall refer to one of them for adjudicating UD deprels	
	my $adparent = $parent->is_adposition() ;
	#We save the preposition parent	
	my $adparent_node = $adparent ? $node->parent() : '' ; 
	$parent = $parent->parent() if($adparent && defined($parent->parent())) ;
	my $conjpar = '' ;
	my @parent_chain = ($parent) ;
	#$parent->is_root() ? push @parent_chain, $node : push @parent_chain, $parent ; 
	if(lc($parent->deprel()) eq 'coord')
	{
		if($node->is_member() || ( $adparent && $adparent_node->is_member() ) )
		{
			$conjpar = $parent ;
			do
			{
			$conjpar  = $conjpar->parent() ;
			push @parent_chain, $conjpar;	
			}
			until(lc($conjpar->deprel()) ne 'coord' || $conjpar->is_root()) ;

			#log_warn("Oltre la congiunzione ".$node->form()." -> ".$parent->form()." -> ".$conjpar->form());
			#log_warn("Roots, bloody roots!") if($conjpar->is_root());
		}
		else
		{
			my @member_siblings = grep {$_->is_member && !($_->deprel() eq 'ExD')} $parent->children() ; 
			$conjpar = $member_siblings[0] if(@member_siblings) ;
			push @parent_chain, $conjpar if($conjpar) ;
			#log_warn("Accanto alla congiunzione ".$node->form()." -> ".$parent->form()." -> ".$conjpar->form());

		}
	} 

	$parent = $conjpar unless(!$conjpar || $conjpar->is_root());
	#For cases of preposition and co-ordination chains: mittit ad senatores et equites (senatores->(et->ad->)mittit) 
	#We have to be careful not to rewrite this information with regard to a node which is the direct son of an adposition
	$adparent = $parent->is_adposition() if(!$adparent) ;
	$parent = $parent->parent() if($parent->is_adposition() && defined($parent->parent())) ;

#my @cpform = map {$_ ? $_->form() : $node->form()} @parent_chain ; log_warn(scalar(@parent_chain)." avi: @cpform") ;

	#For the log: co-ordinations with no members, changed to AuxY during harmonization, originated from wrong annotation
	if($node->is_coordinator() && lc($deprel) eq 'auxy' && lc($node->parent()->deprel()) ne 'coord' )	
	{
		print $log "W#4: Possibly wrongly relabelled co-ordinator and co-ordination members in sentence ".$root->id()." (parenthesis?)\n" ;
		print $log "Co-ordinator: ".($node->is_root() ? "root" : $node->form())."\n";
		my @chforms = map {$_->form()} sort {$a->ord() <=> $b->ord()} $node->children() ;
		print $log "Children: @chforms \n" ;
		print $log "\n\n";
	}
	#

        # The top nodes (children of the root) must be labeled 'root'.
        # However, this will be solved elsewhere (and tree transformations may
        # result in a different node being attached to the root), so we will
        # now treat the labels as if nothing were attached to the root.
	
	# Punctuation is always 'punct' unless it depends directly on the root (which should happen only if there is just one node and the root).
        # We will temporarily extend the label if it heads coordination so that the coordination can later be reshaped properly.
        if($node->is_punctuation())
        {
            if($deprel eq 'Coord')
            {
                $deprel = 'coord';
            }
            else
            {
                $deprel = 'punct';
            }
        }
        # Coord marks the conjunction that heads a coordination.
        # (Punctuation heading coordination has been processed earlier.)
        # Coordinations will be later restructured and the conjunction will be attached as 'cc'.
        elsif($deprel eq 'Coord')
        {
            $deprel = 'coord';
        }
        # AuxP marks a preposition. There are two possibilities:
        # 1. It heads a prepositional phrase. The relation of the phrase to its parent is marked at the argument of the preposition.
        # 2. It is a leaf, attached to another preposition, forming a multi-word preposition. (In this case the word can be even a noun.)
        # Prepositional phrases will be later restructured. In the situation 1, the preposition will be attached to its argument as 'case'.
        # In the situation 2, the first word in the multi-word prepositon will become the head and all other parts will be attached to it as 'fixed'.
        elsif($deprel eq 'AuxP')
        {

	    $deprel = 'case';
	    
        }
        # AuxC marks a subordinating conjunction that heads a subordinate clause.
        # It will be later restructured and the conjunction will be attached to the subordinate predicate as 'mark'.
	# There are also some fixed expressions led by an AuxP, as in "secundum quod", with quod AuxC, not qui. We have to restructure this case.
        elsif($deprel eq 'AuxC')
        {

	    if($node->lemma() eq 'quod' && $node->parent()->lemma() eq 'secundum')
	    {
		my $secundum = $node->parent() ;
		$node->parent()->set_deprel('fixed') ;	
		$node->set_parent($secundum->parent()) if(defined($secundum->parent())) ;
		$secundum->set_parent($node) ;
		$node->set_is_member(1) if($secundum->is_member()) ;	
		$secundum->set_is_member(undef) if($secundum->is_member()) ;
				
	    }



	    $deprel = 'mark';
	    
        }
        # Predicate: If the node is not the main predicate of the sentence and it has the Pred deprel,
        # then it is probably the main predicate of a parenthetical expression.
        # Exception: predicates of coordinate main clauses. This must be solved after coordinations have been reshaped. ###!!! TODO
        elsif($deprel eq 'Pred')
        {
            $deprel = 'parataxis';
        }
        # Subject: nsubj, nsubj:pass, csubj, csubj:pass
        elsif($deprel eq 'Sb')
        {
            # Is the parent a passive verb?
            # Note that this will not catch all passives (e.g. reflexive passives).
            # Thus we will later check whether there is an aux:pass sibling.
            if($parent->iset()->is_passive())
            {
		if($parent->lemma()=~/.*or/) #Parent is a deponent verb (passive voice, active meaning): the subject must not have the "pass" extension
		{
			$deprel = $node->is_verb() ? 'csubj' : 'nsubj';
		}
		else
		{
			# If this is a verb (including infinitive) then it is a clausal subject.
                	$deprel = $node->is_verb() ? 'csubj:pass' : 'nsubj:pass';
	
		}		
            }
            else # Parent is not passive.
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $deprel = $node->is_verb() ? 'csubj' : 'nsubj';
            }
        }
        # Object: obj, iobj, ccomp, xcomp
        elsif($deprel eq 'Obj')
        {
            ###!!! If a verb has two or more objects, we should select one direct object and the others will be indirect.
            ###!!! We would probably have to consider all valency frames to do that properly.
            ###!!! TODO: An approximation that we probably could do in the meantime is that
            ###!!! if there is one accusative and one or more non-accusatives, then the accusative is the direct object.
	    #Treatment of OComp (secondary predicates): they are xcomps and not objs. Ex: "Hunc dicimus _deum_".
	    #To treat Ocomp, during Prague harmonization we store a wild value 'ocomp' to preserve this information,
	    #which is otherwise not retrievable from the Obj deprel alone. 
            if(exists($node->wild()->{ocomp}) && $node->wild()->{ocomp} eq 'predicative')
	    {
		$deprel = 'xcomp' ;
	    }
	    elsif($node->is_verb())
            {
                # If this is an infinitive then it is an xcomp (controlled clausal complement) - not always, see below
                # If this is a verb form other than infinitive then it is a ccomp.
                ###!!! TODO: But if the infinitive is part of periphrastic future, then it is ccomp, not xcomp!
		#We have to take into account the construction of accusativus cum infinito: "dicunt deum bona facere", where deum is the subject 
		#and esse is not an xcomp, since its subject is different from that of the main verb. Only modal verbs should have an xcomp, else 
		#ccomp is required.
		#We have to look at the possible parent verb. Not only modals require an xcomp.
		#Old: $deprel = $node->is_infinitive() ? 'xcomp' : 'ccomp'
		#The list of xcomp-governing verbs might be still incomplete
                if ($node->is_infinitive())
		{

			if ($parent->is_verb() && ($parent->iset()->verbtype() eq 'mod' || $parent->lemma()=~/intendo|nitor|incipio|desino|deficio|cesso/ ))
			{
				$deprel = 'xcomp' ;
			}
			#If there is an explicit subject, it is most probably the case of an Accusativus cum infinitvo, so a ccomp
			#The only exception is when the explicit subject is "se" (reflexive; se <-> sui in ITTB)
			else 
			{
				my $subject = ( grep {$_->deprel()=~m/(Sb|nsubj)/} $node->children() )[0] ; #There can be only one subject
				$deprel = ( $subject && $subject->lemma() ne 'se') ? 'ccomp' : 'xcomp' ;
			}
		}
		#Sometimes, we have a gerund(ive) construction that depends on a verb as an Obj, with a final or other sense. 
		#Since we treat them as implicit verbal clauses, and since they are introduced by a prepositional element, 
		#we have to define them as advcl:arg, parallelly to obl:arg constructions for verbs and adjectives 
		elsif ($node->iset()->verbform() eq 'ger' && $adparent)
		{
			$deprel = 'advcl:arg' ;
		}
		else 
		{
			$deprel = 'ccomp' ;
		}
            }
	    
            else # nominal object
            {
                # New in UD 2.1 for case-marking Indo-European languages:
                # Prepositional objects are no longer "obj" but they are also not plain "obl".
                # Instead, they get a special subtype, "obl:arg".
                # We convert deprels before the structure is changed, so we can
                # ask whether the direct parent node is a preposition.
                ###!!! This will not work properly if there is coordination!
                ###!!! We should recheck the structure when it has been transformed
                ###!!! to UD, and see whether there are any "case" dependents.

		#Needed to check for intransitive-transitive constructions
		my @objects = grep {$_->deprel()=~m/^[Oo]bj/} $parent->children() ;

		#An obj might be reinterpreted as an nmod, since sometimes it depends on an adjective or a noun bearing valency
		if(!($parent->is_verb()))
		{
			if($adparent)
			{
				$deprel = ($parent->is_adjective() || $parent->is_adverb()) ? 'obl:arg' : 'nmod' ;
			}
			else
			{
				$deprel = 'nmod' ;
			}	
		}
		#"Direct" dative objects in presence of other objects should be labelled iobj
		elsif( ($node->is_noun()||$node->is_pronoun()) && $node->iset()->case() eq 'dat' 
							       && !$adparent && scalar(@objects) > 1) 
		{
			$deprel = 'iobj' ; 
		}
		else
		{
                	$deprel = $adparent ? 'obl:arg' : 'obj';	
		}
            }
        }
        # Nominal predicate attached to a copula verb.
        elsif($deprel eq 'Pnom')
        {
            # We will later transform the structure so that copula depends on the nominal predicate.
            # The 'pnom' label will disappear and the inverted relation will be labeled 'cop'.

	    #Pnom is also used for predicative complements of verbs in passive form (the active counterpart of OComp)
	    #Yet sometimes, a copula acts as a predicative complement xcomp
	    #There can be some cases where a Pnom apposition is reattached (by sub treat_apposition) to another non-verb node:
	    #if this happens, we do not want a copula-like restructuring to take place
	    if(exists($node->parent()->wild()->{apos}) && $node->parent()->wild()->{apos} eq 'apped'
		&& exists($node->wild()->{apos}) && $node->wild()->{apos} eq 'apped')
	    {
		$deprel = 'xcomp' ; #It will later be substituted by appos or a related label
	    }
	    elsif($parent-> is_verb() && $parent->lemma() ne 'sum' && ($node->is_pronoun() || $node->is_noun() || $node->is_adjective() || $node->is_numeral() ))
	    {
		$deprel = 'xcomp' ;
	    }
	    #Passive periphrastics: Carthago delenda est. est will be an auxiliary 
	    elsif($node->is_verb() && $node->iset()->verbform() eq 'gdv' && $parent->lemma() eq 'sum')
	    {
		$deprel = 'pnom';
	    }
 	    # We cannot do this if the predicate is a subordinate clause ("[my opinion]-nsubj is [that we should not go there]-Pnom"). 
	    # Then a verb would have two subjects.
	    # However, we want verbal verbal predicates of non-copulae ([hoc]-nsubj videtur [esse bonum]-Pnom) to function as xcomps, not ccomps
            elsif($node->is_verb() && !$node->is_participle())
            {
                $deprel = $parent->lemma() eq 'sum' ? 'ccomp' : 'xcomp' ;
            }
            # The symbol "=" is tagged SYM and substitutes a verb ("equals to"). This verb is not considered copula (only "to be" is copula).
            # Hence we will re-classify the relation as object.
            elsif(!$parent->is_root() && $parent->form() eq '=')
            {
                $deprel = 'obj';
            }
            else
            {
                $deprel = 'pnom';
            }
        }
        # Adverbial modifier: advmod, obl, advcl
        elsif($deprel eq 'Adv')
        {
            ###!!! Manual disambiguation is needed here. For example, in Czech:
            ###!!! Úroda byla v tomto roce o mnoho lepší než loni.
            ###!!! There should be obl(lepší, roce) but nmod(lepší, mnoho).
	    
	    #Sometimes dative pronouns are adverbial but should be indirect objects.
	    if($node->is_pronoun() && $node->iset()->case() eq 'dat' && !$adparent) 
	    {
		my @objects = grep {$_->deprel()=~m/^[Oo]bj/} $parent->children() ;
		$deprel = @objects ? 'iobj' : 'obj' ;
	    }
	    else
	    {
            	$deprel = $node->is_verb() ? 'advcl' : ($node->is_noun() || $node->is_adjective() || $node->is_numeral()) ? 'obl' : 'advmod';
	    }
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($deprel eq 'Atr')
        {
	    if($adparent && (!$node->is_verb()))
	    {
		$deprel = 'nmod' ;
	    }
            # Cardinal number is nummod, ordinal number is amod. It should not be a problem because Interset 
	    #should categorize ordinals as special types of adjectives.
            # But we cannot use the is_numeral() method because it returns true if pos=num or if numtype is not empty.
            # We also want to exclude pronominal numerals (kolik, tolik, mnoho, málo). These should be det.
            elsif($node->iset()->pos() eq 'num')
            {
                if($node->iset()->prontype() eq '')
                {
                    # If we later push the numeral down, we will label it nummod:gov.
                    $deprel = 'nummod';
                }
                else
                {
                    # If we later push the quantifier down, we will label it det:numgov.
                    $deprel = 'det:nummod';
                }
            }
	    #Pronouns have a double nature. When they occur as adjectives, as in "per _illud_ nomen", we want them to be treated as determiners, 
	    #thus putting deprel=det,
	    #and not as nmod (as it would be with the last catch-all else). To do this, we check the agreement between a pronoun 
	    #and its parent noun.
	    #The function agreestrict has to be used, since in "de eo" we want eo to have no agreement with de, while sub agree 
	    #would give us a false positive.
	    elsif($node->is_pronoun() && $self->agreestrict($node, $parent, 'case') && $self->agreestrict($node, $parent, 'gender') )
	    {
		$deprel = 'det' ;

	    }	
            elsif($node->iset()->nametype() =~ m/(giv|sur|prs)/ &&
                  $parent->iset()->nametype() =~ m/(giv|sur|prs)/)
            {
                $deprel = 'flat';
            }
            elsif($node->is_foreign() && $parent->is_foreign() ||
                  $node->is_foreign() && $node->is_adposition() && $parent->is_proper_noun())
                  ###!!! van Gogh, de Gaulle in Czech text; but it means we will have to reverse the relation left-to-right!
                  ###!!! Another solution would be to label the relation "case". But foreign prepositions do not have this function in Czech.
            {
                $deprel = 'flat:foreign';
            }
	    #Since the IT-TB does not give the type of information checked for above, we have to look for appositions and names in another way
	    #We have to exclude double genitives, since they are most probably true attributive constructions
	    elsif($node->is_noun() && $parent->is_noun() && $node->iset()->get('case') ne 'gen'
			&& $self->agreestrict($node, $parent, 'case') && $self->agreestrict($node, $parent, 'number') )
	    { 
		$deprel = ($node->iset()->{nountype} eq 'prop' || $parent->iset()->{nountype} eq 'prop') 
				&& abs($node->ord() - $parent->ord()) == 1 ? 'flat' : 'appos' ;
	    }
	    
	    #Our only determiner is the spurious "ly", an interference coming from the Italian definite article "il".
	    #(Thomas Aquinas writes in XIII century)
            elsif($node->is_determiner())
            {
                $deprel = 'det';
            }
	    #Sometimes adjectives behave more like nouns, in that they are used independently and not as modifiers.
	    #This is very frequently the case in Latin.
            elsif($node->is_adjective())
            {		
		#($parent->wild()->{prague_deprel} eq 'AuxP') ? 'nmod' :
                $deprel = ($self->agreestrict($node, $parent, 'case') && $self->agreestrict($node, $parent, 'gender')) ? 'amod' : 'nmod';
            }
            elsif($node->is_adverb())
            {
                $deprel = 'advmod';
            }
	    #We want to distinguish relative clauses with acl:relcl. They are introduced by relative pronouns (children of the predicate).
	    #Relative clauses with cuius or quorum etc. ("whose") are more complex, since cuius might be attribute of a noun, but in this case
	    #it is the grandchildren of the examined node.
	    #This is valid also for non-possessive constructions, like quae capere non potest, where quae depends on capere in the ITTB.
            elsif($node->is_verb())
            {
		my $cuius = '' ;
		foreach my $ch ( $node->children() ) 
		{
			if( any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'}  $ch->children() ) #&& $_->iset()->case() eq 'gen'} 
			{
				$cuius = 'cuius' ;
				last;
			}
		}
		$deprel = ( ( any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'} ($node->children()) ) || $cuius ) ? 'acl:relcl' : 'acl';
            }
            else
            {
                $deprel = 'nmod';
            }
        }
	# AuxA is not an official deprel used in HamleDT 2.0. Nevertheless it has been introduced in some (not all)
        # languages by people who want to use the resulting data in TectoMT. It marks articles attached to nouns.
        elsif($deprel eq 'AuxA')
        {
            $deprel = 'det';
        }
        # Verbal attribute is analyzed as secondary predication.
        ###!!! TODO: distinguish core arguments (xcomp) from non-core arguments and adjuncts (acl/advcl).
	#This attribute is not always verbal. It may fall under the cases of amod or nmod, but we use the deprel
	#amod:advmod and nmod:advmod to retain the original semantic shade.
	#Ex: per solam gloriam; id uniatur corpori ut forma
        elsif($deprel =~ m/^AtvV?$/)
        {
            $deprel = $parent->is_verb() ? 'xcomp' : $node->is_adjective() ? 'amod:advmod' : 'nmod:advmod' ;
        }
        # Auxiliary verb "být" ("to be"): aux, aux:pass
        elsif($deprel eq 'AuxV')
        {
            $deprel = $parent->iset()->is_passive() ? 'aux:pass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with inherently reflexive verbs.
        # Unfortunately, previous harmonization to the Prague style abused the AuxT label to also cover Germanic verbal particles and other compound-like stuff with verbs.
        # We have to test for reflexivity if we want to output expl:pv!
        elsif($deprel eq 'AuxT')
        {
            # This appears in Slavic languages, although in theory it could be used in some Romance and Germanic languages as well.
            # It actually also appears in Dutch (but we mixed it with verbal particles there).
            # Most Dutch pronouns used with this label are tagged as reflexive but a few are not.
            if($node->is_reflexive() || $node->is_pronoun())
            {
                $deprel = 'expl:pv';
            }
            # The Tamil deprel CC (compound) has also been converted to AuxT. 11 out of 12 occurrences are tagged as verbs.
            elsif($node->is_verb())
            {
                $deprel = 'compound';
            }
            # Germanic verbal particles can be tagged as various parts of speech, including adpositions. Hence we cannot distinguish them from
            # preposition between finite verb and infinitive, which appears in Portuguese. Examples: continua a manter; deixa de ser
            # en: 1181 PART, 28 ADP, 28 ADV, 3 ADJ; 27 different lemmas: 418 up, 261 out, 141 off...
            # de: 4002 PART; 138 different lemmas: 528 an, 423 aus, 350 ab...
            # nl: 1097 ADV, 460 PRON, 397 X, 176 ADJ, 157 NOUN, 99 ADP, 42 VERB, 9 SCONJ; 368 different lemmas: 402 zich, 178 uit, 167 op, 112 aan...
            # pt: 587 ADP, 53 SCONJ, 1 ADV; 5 different lemmas: 432 a, 114 de, 56 que, 38 por, 1 para
            else
            {
                $deprel = 'compound:prt';
            }
        }
        # Reflexive pronoun "se", "si" used for reflexive passive.
        elsif($deprel eq 'AuxR')
        {
            $deprel = 'expl:pass';
        }
        # AuxZ: intensifier or negation
        elsif($deprel eq 'AuxZ')
        {
            my $lemma = $node->lemma();
            # AuxZ is an emphasizing word (“especially on Monday”).
            # It also occurs with numbers (“jen čtyři firmy”, “jen několik procent”).
            # The word "jen" ("only") is not necessarily a restriction. It rather emphasizes that the number is a restriction.
            # On the tectogrammatical layer these words often get the functor RHEM (rhematizer / rematizátor = něco, co vytváří réma, fokus).
            # But this is not a 1-1 mapping.
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch10s06.html
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch07s07s05.html
            # Most frequent lemmas with AuxZ: i (4775 výskytů), jen, až, pouze, ani, už, již, ještě, také, především (689 výskytů)
            # Most frequent t-lemmas with RHEM: #Neg (7589 výskytů), i, jen, také, už, již, ani, až, pouze, například (500 výskytů)
            $deprel = 'advmod:emph';
        }
        # Neg: used in Prague-style harmonization of some treebanks (e.g. Romanian) for negation (elsewhere it may be AuxZ or Adv).
        elsif($deprel eq 'Neg')
        {
            # There was a separate 'neg' relation in UD v1 but it was removed in UD v2.
            $deprel = 'advmod';
        }
        # The AuxY deprel is used in various situations, see below.
        elsif($deprel eq 'AuxY')
        {
            # When it is attached to a subordinating conjunction (AuxC), the two form a multi-word subordinator.
            # Index Thomisticus examples: ita quod (so that), etiam si (even if), quod quod (what is that), ac si (as if), et si (although)
            if($parent->wild()->{prague_deprel} eq 'AuxC')
            {
                # The phrase builder will later transform it to MWE.
                $deprel = 'mark';
            }
            # When it is attached to a complement (Atv, AtvV), it is usually an equivalent of the subordinating conjunction "as" and it should be 'mark'.
            # Czech: "jako" ("as"); sometimes it is attached even to Obj (of verbal adjectives). It should never get the 'cc' deprel, so we will mention it explicitly.
            # Index Thomisticus examples: ut (as), sicut (as), quasi (as), tanquam (like), utpote (as) etc.
	    #!!!: Doubtful, as mark only introduces clauses
            #elsif($parent->wild()->{prague_deprel} =~ m/^AtvV?$/ ||
            #      lc($node->form()) =~ m/^(jako|ut|sicut|quasi|tanquam|utpote)$/)
            #{
            #    $deprel = 'mark';
            #}
   	    elsif($parent->wild()->{prague_deprel} =~ m/^AtvV?$/ ||
                 lc($node->form()) =~ m/^(jako|ut|sicut|quasi|tanquam|utpote)$/)
            {
              $deprel   = 'advmod';
            }

            # AuxY may be a preposition attached to an adverb; unlike normal AuxP prepositions, this one is not the head.
            # Index Thomisticus: ad invicem (each other); "invicem" is adverb that could be roughly translated as "mutually".
	    # It is a fixed expression.
            elsif($node->is_adposition())
            {
                $deprel = ($node->lemma()=~m/a(d|b)/ && $parent->lemma() eq 'invicem') ? 'fixed' : 'case';
            }
            # When it is attached to a verb, it is a sentence adverbial, disjunct or connector.
            # Index Thomisticus examples: igitur (therefore), enim (indeed), unde (whence), sic (so, thus), ergo (therefore).
            elsif($parent->is_verb() && !$node->is_coordinator())
            {
                $deprel = 'advmod';
            }
            # Non-head conjunction in coordination is probably the most common usage.
            # Index Thomisticus examples: et (and), enim (indeed), vel (or), igitur (therefore), neque (neither).
            else
            {
                $deprel = 'cc';
            }
        }
        # AuxO: redundant "to" or "si" ("co to znamená pátý postulát dokázat").
        elsif($deprel eq 'AuxO')
        {
            $deprel = 'discourse';
        }
        # Apposition #!!!It does not seem to be accepted as a deprel during harmonization, so it needs to be treated otherwise.
        elsif($deprel eq 'Apposition')
        {
            $deprel = 'appos';
        }
        # Punctuation
        ###!!! Since we now label all punctuation (decided by Interset) as punct,
        ###!!! here we only get non-punctuation labeled (by mistake?) AuxG, AuxX or AuxK. What to do with this???
        elsif($deprel eq 'AuxG')
        {
            # AuxG is intended for graphical symbols other than comma and the sentence-terminating punctuation.
            # It is mostly assigned to punctuation but sometimes to symbols (% $ + x) or even alphanumeric tokens (1 2 3).
            # The 'punct' deprel should be used only for punctuation.
            # We do not really know what the label should be in this case.
            # For mathematical operators (+ - x /) it should be probably 'cc'.
            # (But we cannot distinguish minus from hyphen, so with '-' we will not get here. Same for '/'.)
            # For % and $ it could be any label used with noun phrases.
            if($node->form() =~ m/^[+x]$/)
            {
                $deprel = 'cc';
            }
            else
            {
                $deprel = 'nmod'; ###!!! or nsubj or obj or whatever
            }
        }
        elsif($deprel =~ m/^Aux[XK]$/)
        {
            # AuxX is reserved for commas.
            # AuxK is used for sentence-terminating punctuation, usually a period, an exclamation mark or a question mark.
            log_warn("Node '".$node->form()."' has deprel '$deprel' but it is not punctuation.");
            $deprel = 'punct';
        }
        ###!!! TODO: ExD with chains of orphans should be stanfordized!
	###We try to use some heuristics to sort ellipses, but manual intervention might be necessary to solve some imprecisions
        elsif($deprel eq 'ExD')
        { 
	    #This check seems to be problematic as sometimes it fails to find an object, but it is always done correctly elsewhere
	    if( ( grep {$_->is_parenthesis_root()} @parent_chain ) && lc($parent->deprel()) eq 'coord')
	    {
		#For the log
		print $log "W#5: Possibly manual disambiguation needed for elliptical parenthetical clause with co-ordination in sentence ".$root->id()."\n" ;
		my @parenth = grep {$_->is_parenthesis_root()} @parent_chain ;
		my @parenthform = map {$_->form()} @parenth ;
		print $log "Parenthesis root: @parenthform\n";
		my @chforms = map {$_->form()} sort {$a->ord() <=> $b->ord()} $parenth[0]->children() ;
		print $log "Parenthesis root children: @chforms \n" ;
		print $log "\n\n" ;
		#
	    }

	    #We attach oblique orphan arguments only to verbs
	    if(defined($node->wild()->{toExD}) && $node->wild()->{toExD} eq 'orphan')
	    {
		$deprel = 'orphan' ;		
	    }
	    #If we have an elliptic parenthesis, it still inherits the parataxis tag from the elided component
	    elsif(grep {$_->is_parenthesis_root()} @parent_chain)
	    {
		$deprel = 'parataxis' ;
	    }
	    #Probable subordinate clauses with verb ellipsis
	    elsif( $parent->wild()->{prague_deprel} eq 'AuxC' )
            {
                $deprel = 'advcl' ; 
            }
	    #More verb nodes attached to the root might be a case of parataxis. This will be taken care of later
	    #by Treex::Tool::PhraseBuilder::PragueToUD
 	    elsif($node->is_verb() )
	    {

		my $cuius = '' ;
		foreach my $ch ( $node->children() ) 
		{
			if( any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'}  ($ch->children()) ) #&& $_->iset()->case() eq 'gen'} 
			{
				$cuius = 'cuius' ;
				last;
			}
		}

		$deprel = ($parent->is_root()) ? 'pnom' : 
				($parent->is_verb() && $node->iset()->verbform() eq 'gdv' && $node->iset()->case() eq 'acc') ? 'ccomp' : 
				($parent->is_verb()) ? 'advcl' : 
				( (any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'} $node->children()) || $cuius) ? 'acl:relcl' : 'acl' ;
		#$deprel = 'orphan' ;
	    }
 	    elsif($node->is_conjunction())
	    {
		$deprel = 'mark' ;
	    }
	    elsif($adparent || $node->iset()->case() eq 'abl')
            {
		$deprel = (defined($parent) && $parent->is_verb()) ? 'obl' : 'orphan' ;
            }
	    #Probable elliptic accusativus cum infinitivo if there are dependents (which are labeled as orphans)
	    elsif($node->iset()->case() eq 'acc')
            {
		$deprel =  (any {$_->wild()->{toExD} eq 'orphan'} $node->children()) ? 'ccomp' : 'orphan' ;
            }
	    # Some ExD are vocatives.
            elsif($node->iset()->case() eq 'voc')
            {
                $deprel = 'vocative';
            }
	    #As ExDs arise from ellipsis, a term that isn't part of a co-ordination (and so conj)
	    #is likely to miss a syntactically relevant head
            else
            {
                $deprel = 'orphan' ;#'dep';
            }
	    
	    delete($root->wild()->{toExD});

        }
        # Set up a fallback so that $deprel is always defined.
	#There is a small problems with not recognized variants (introduced by :) and some UD tags like orphan and appos
        else
        {
            $deprel = 'dep:'.lc($deprel) if($deprel!~m/(orphan|advmod:appos|appos|acl:appos)/); #During ellipsis treatment we already defined some orphans
        }
        # Save the universal dependency relation label with the node.
        $node->set_deprel($deprel);
    }

    # Now that all deprels have been converted we do not need the copies of the original deprels any more. Delete them.
    delete($root->wild()->{prague_deprel});
    foreach my $node (@nodes)
    {
        delete($node->wild()->{prague_deprel});
    }
}



#------------------------------------------------------------------------------
# Prepositional objects are considered oblique in many languages, although this
# is not a universal rule. They should be labeled "obl:arg" instead of "obj".
# We have tried to identify them during deprel conversion but some may have
# slipped through because of interaction with coordination or apposition.
#------------------------------------------------------------------------------
sub relabel_prepositional_objects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^i?obj(:|$)/)
        {
            ###!!! In Slavic languages, thhis condition does not work well with
            ###!!! some quantified noun phrases, e.g. in Czech:
            ###!!! Výbuch zranil kolem padesáti lidí.
            ###!!! ("Kolem padesáti lidí" = "around fifty people" acts externally
            ###!!! as neuter singular accusative, but internally its head "lidí"
            ###!!! is masculine plural genitive and has a prepositional child.)
            if(any {$_->deprel() =~ m/^case(:|$)/} ($node->children()))
            {
                $node->set_deprel('obl:arg');
            }
        }
    }
}

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
sub relabel_elliptical_comparative_constructions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
	my $deprel = $node->deprel();
        $deprel = '' if(!defined($deprel));
	my $parent = $node->parent();

	if( ( any {$_->lemma() eq 'quam'} ($node->children()) ) && !($node->deprel() eq 'advcl')
								   && defined($node->parent()) && $parent->iset()->degree() eq 'cmp'  )
	{
		$node->set_deprel('advcl') ;
	}
	else
	{
		;
	}
    }
}

#------------------------------------------------------------------------------
#Passive periphrastics: Carthago delenda est
#If the gerundive is the root, we have to correct the cop est into an aux:pass.
#We also treat some similar cases, like verbs who were assigned afun ExD and later in this conversion script advcl,
#but which should actually receive acl, acl:relcl, ccomp or csubj
#------------------------------------------------------------------------------
sub treat_gerundive_passive_periphrastics
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
	my $deprel = $node->deprel();
        $deprel = '' if(!defined($deprel));
	my $parent = $node->parent();

	if( $node->lemma() eq 'sum' && $deprel eq 'cop' && $parent->is_verb() && $parent->iset()->verbform() eq 'gdv') 
	{
	    $node->set_deprel('aux:pass') ;
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
	}	
	#We have to take also copulas into account
	elsif( ( $node->is_verb() || (any {$_->deprel() eq 'cop'} ($node->children())) ) && $deprel eq 'advcl')
	{

		my $cuius = '' ;
		foreach my $ch ( $node->children() ) 
		{
			if( any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'}  ($ch->children()) ) #&& $_->iset()->case() eq 'gen'} 
			{
				$cuius = 'cuius' ;
				last;
			}
		}

		#Relabel quod clauses arisen from ExDs as either csubj or ccomp
		#Some quods introduce adverbial clauses, and we should try not to overwrite them
		if( (any {$_->lemma() eq 'quod'} ($node->children())))
		{
			if($parent->is_verb() && $node->deprel() ne 'advcl')
			{
				($parent->iset()->voice() eq 'pass') ? $node->set_deprel('csubj:pass') : $node->set_deprel('ccomp') ;
			}
		}
		#Relabel elliptical relative clauses
		#Sometimes a relative pronoun occurs in an adverbial clause introduced by a conjunction: we have to ignore this case
		elsif( ( ( any {$_->is_pronoun() && $_->iset()->prontype() eq 'rel'} ($node->children()) ) || $cuius ) 
			   && !(any {$_->deprel eq 'mark'} ($node->children())) )
		{
			$node->set_deprel('acl:relcl') ;
		}
	}
	#Sometimes a clause has not been labelled as a passive subject because of the interference of an AuxC
	#or of an ellipsis
	elsif($node->is_verb() && $deprel=~m/(csubj|orphan)/ && $parent->iset()->is_passive() && $parent->lemma()!~/.*or/)
	{
		$node->set_deprel('csubj:pass') ;
	}
	else
	{
		;
	}
    }
}

#------------------------------------------------------------------------------
#Treex::Tool::PhraseBuilder::PragueToUD checks for double objects and heuristically changes one into iobj.
#This interacts badly with secondary predicates, xcomp and ccomp, so that we have to re-correct those accusative iobjs to objs
#------------------------------------------------------------------------------
sub correct_false_indirect_objects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
	my $deprel = $node->deprel();
        $deprel = '' if(!defined($deprel));
	my $parent = $node->parent();

	if( $node->deprel() eq 'iobj' && $node->iset()->case() eq 'acc' && !(any {$_->is_adposition()} ($node->children())) ) 
	{
	    $node->set_deprel('obj') ;
	}	
	else
	{
		;
	}
    }
}



#------------------------------------------------------------------------------
# Since UD v2, verbal copulas must be tagged AUX and not VERB. We cannot check
# this during the deprel conversion because we do not always see the real
# copula as the parent of the Pnom node (hint: coordination).
#------------------------------------------------------------------------------
sub tag_copulas_aux
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'cop' && $node->is_verb())
        {
            $node->iset()->set('verbtype', 'aux');
            $node->set_tag('AUX');
        }
    }
}



#------------------------------------------------------------------------------
# The AnCora treebanks of Catalan and Spanish contain empty nodes representing
# elided subjects. These nodes are typically leaves (but I don't know whether
# it is guaranteed). Remove them.
#------------------------------------------------------------------------------
sub remove_null_pronouns
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->form() eq '_' && $node->is_pronoun())
        {
            if($node->is_leaf())
            {
                $node->remove();
            }
            else
            {
                log_warn('Cannot remove NULL node that is not leaf.');
            }
        }
    }
}


#------------------------------------------------------------------------------
# In the Croatian SETimes corpus, given name of a person depends on the family
# name, and the relation is labeled as apposition. Change the label to 'flat'.
# This should be done before we start structural transformations.
#------------------------------------------------------------------------------
sub relabel_appos_name
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if(defined($deprel) && $deprel eq 'appos')
        {
            my $parent = $node->parent();
            next if($parent->is_root());
            if($node->is_proper_noun() && $parent->is_proper_noun() && $self->agree($node, $parent, 'case'))
            {
                $node->set_deprel('flat');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Makes sure that a preposition attached to a verb is labeled 'mark' and not
# 'case'. It is difficult to enforce during restructuring of Aux[PC] phrases
# because there are things like coordinations of AuxP-AuxC chains, so it is not
# immediately apparent that the final head will be a verb.
#------------------------------------------------------------------------------
sub change_case_to_mark_under_verb
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case' && $node->parent()->is_verb())
        {
            $node->set_deprel('mark');
        }
    }
}



#------------------------------------------------------------------------------
# If a verb has an aux:pass or expl:pass child, its subject must be also *pass.
# We try to get the subjects right already during deprel conversion, checking
# whether the parent is a passive participle. But that will not work for
# reflexive passives, where we have to wait until the reflexive pronoun has its
# deprel. Probably it will also not work if the participle does not have the
# voice feature because its function is not limited to passive (such as in
# English). This method will fix it. It should be called after the main part of
# conversion is done (otherwise coordination could obscure the passive
# auxiliary).
#------------------------------------------------------------------------------
sub check_ncsubjpass_when_auxpass
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my @children = $node->children();
        my @auxpass = grep {$_->deprel() =~ m/^(aux|expl):pass$/} (@children);
        if(scalar(@auxpass) > 0)
        {
            foreach my $child (@children)
            {
                if($child->deprel() eq 'nsubj')
                {
                    $child->set_deprel('nsubj:pass');
                }
                elsif($child->deprel() eq 'csubj')
                {
                    $child->set_deprel('csubj:pass');
                }
                # Specific to some languages only: if the oblique agent is expressed, it is a bare instrumental noun phrase.
                # In the Prague-style annotation, it would be labeled as "obj" when we come here.
                elsif($child->deprel() eq 'obj' && $child->is_instrumental())
                {
                    $child->set_deprel('obl:agent');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# UD guidelines disallow chains of auxiliary verbs. Regardless whether there is
# hierarchy in application of grammatical rules, all auxiliaries should be
# attached directly to the main verb (example [en] "could have been done").
#------------------------------------------------------------------------------
sub dissolve_chains_of_auxiliaries
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # An auxiliary verb may be attached to another auxiliary verb in coordination ([cs] "byl a bude prodáván").
        # Thus we must check whether the deprel is aux (or aux:pass). We also cannot dissolve the chain if the
        # grandparent is root.
        if($node->iset()->is_auxiliary() && $node->parent()->iset()->is_auxiliary() && $node->deprel() =~ m/^aux/ && !$node->parent()->parent()->is_root())
        {
            $node->set_parent($node->parent()->parent());
        }
    }
}



#------------------------------------------------------------------------------
# Punctuation in coordination is sometimes attached to a non-head conjunction
# instead to the head (e.g. in Index Thomisticus). Now all coordinating
# conjunctions are attached to the first conjunct and so should be commas.
#------------------------------------------------------------------------------
sub raise_punctuation_from_coordinating_conjunction
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'punct')
        {
            my $parent = $node->parent();
            my $pdeprel = $parent->deprel() // '';
            if($pdeprel eq 'cc')
            {
                $node->set_parent($parent->parent());
            }
        }
    }
}

#------------------------------------------------------------------------------
# We have to relabel the heads and introducing particles of appositions after
#all other constructions (co-ordinations etc.) have been resolved
#In the case of ellipsis, more than one node are labelled as apponent members, but we can check if they received the label orphan
#------------------------------------------------------------------------------
sub post_treatment_of_appositions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if(exists($node->wild()->{apos}) && $node->wild()->{apos} eq 'apponent' && !$node->is_punctuation())
        {
		#The status of this connecting element is still unclear with regard to the guidelines
		$node->parent()->wild()->{oldExD} eq 'yes' ? $node->set_deprel('orphan') : $node->set_deprel('advmod:cc') ;      
        }
	elsif(exists($node->parent()->wild()->{apos}) && $node->parent()->wild()->{apos} eq 'apped'
		&& exists($node->wild()->{apos}) && $node->wild()->{apos} eq 'apped' && $node->deprel() !~ m/(orphan|conj|cc)/)
	{
		#The definition of appos in the guidlines is very restrictive, so we have to find alternatives to label PDT appositions
		if($node->parent()->is_noun())
		{
			($node->is_verb() || $node->wild()->{oldExD} eq 'yes' || $node->wild()->{appcop} eq 'cop') ?  $node->set_deprel('acl:appos') : $node->set_deprel('appos') ;
		}
		elsif($node->parent()->is_adjective() || $node->parent()->is_pronoun())
		{
			($node->is_verb() || $node->wild()->{oldExD} eq 'yes' || $node->wild()->{appcop} eq 'cop') ?  $node->set_deprel('acl:appos') : $node->set_deprel('nmod:appos') ;
		}
		elsif($node->parent()->is_adverb() || $node->parent()->is_verb())
		{
			($node->is_verb() || $node->wild()->{oldExD} eq 'yes' || $node->wild()->{appcop} eq 'cop') ?  $node->set_deprel('advcl:appos') : $node->set_deprel('advmod:appos') ;
		}
		else
		{
			($node->is_verb() || $node->wild()->{oldExD} eq 'yes' || $node->wild()->{appcop} eq 'cop') ?  $node->set_deprel('advcl:appos') : $node->set_deprel('nmod:appos') ;
		}
	}

    }
}


#------------------------------------------------------------------------------
# The two Czech words "jak známo" ("as known") are attached as ExD siblings in
# the Prague style because there is missing copula. However, in UD the nominal
# predicate "známo" is the head.
#------------------------------------------------------------------------------
sub fix_jak_znamo
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<$#nodes; $i++)
    {
        my $n0 = $nodes[$i];
        my $n1 = $nodes[$i+1];
        if(defined($n0->form()) && lc($n0->form()) eq 'jak' &&
           defined($n1->form()) && lc($n1->form()) eq 'známo' &&
           $n0->parent() == $n1->parent())
        {
            $n0->set_parent($n1);
            $n0->set_deprel('mark');
            $n1->set_deprel('advcl') if(!defined($n1->deprel()) || $n1->deprel() eq 'dep');
            # If the expression is delimited by commas, the commas should be attached to "známo".
            if($i>0 && $nodes[$i-1]->parent() == $n1->parent() && defined($nodes[$i-1]->form()) && $nodes[$i-1]->form() =~ m/^[-,]$/)
            {
                $nodes[$i-1]->set_parent($n1);
                $nodes[$i-1]->set_deprel('punct');
            }
            if($i+2<=$#nodes && $nodes[$i+2]->parent() == $n1->parent() && defined($nodes[$i+2]->form()) && $nodes[$i+2]->form() =~ m/^[-,]$/)
            {
                $nodes[$i+2]->set_parent($n1);
                $nodes[$i+2]->set_deprel('punct');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Splits numeral types that have the same tag in the PDT tagset and the
# Interset decoder cannot distinguish them because it does not see the word
# forms.
#------------------------------------------------------------------------------
sub classify_numerals
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $iset = $node->iset();
        # Separate multiplicative numerals (jednou, dvakrát, třikrát) and
        # adverbial ordinal numerals (poprvé, podruhé, potřetí).
        if($iset->numtype() eq 'mult')
        {
            # poprvé, podruhé, počtvrté, popáté, ..., popadesáté, posté
            # potřetí, potisící
            if($node->form() =~ m/^po.*[éí]$/i)
            {
                $iset->set('numtype', 'ord');
            }
        }
        # Separate generic numerals
        # for number of kinds (obojí, dvojí, trojí, čtverý, paterý) and
        # for number of sets (oboje, dvoje, troje, čtvery, patery).
        elsif($iset->numtype() eq 'gen')
        {
            if($iset->variant() eq '1')
            {
                $iset->set('numtype', 'sets');
            }
        }
        # Separate agreeing adjectival indefinite numeral "nejeden" (lit. "not one" = "more than one")
        # from indefinite/demonstrative adjectival ordinal numerals (několikátý, tolikátý).
        elsif($node->is_adjective() && $iset->contains('numtype', 'ord') && $node->lemma() eq 'nejeden')
        {
            $iset->add('pos' => 'num', 'numtype' => 'card', 'prontype' => 'ind');
        }
    }
}



#------------------------------------------------------------------------------
# Checks agreement between two nodes in one Interset feature. An empty value
# agrees with everything (because it can be interpreted as "any value").
#------------------------------------------------------------------------------
sub agree
{
    my $self = shift;
    my $node1 = shift;
    my $node2 = shift;
    my $feature = shift;
    my $i1 = $node1->iset();
    my $i2 = $node2->iset();
    return 1 if($i1->get($feature) eq '' || $i2->get($feature) eq '');
    return 1 if($i1->get_joined($feature) eq $i2->get_joined($feature));
    # If one or both the nodes have multiple values of the feature and their
    # intersection is not empty, take it as agreement.
    my @v1 = $i1->get_list($feature);
    foreach my $v1 (@v1)
    {
        return 1 if($i2->contains($feature, $v1));
    }
    return 0;
}

#------------------------------------------------------------------------------
# Another version of the above agree function, where empty values yield a "false" value (i.e. there can not be any agreement).
#------------------------------------------------------------------------------
sub agreestrict
{
    my $self = shift;
    my $node1 = shift;
    my $node2 = shift;
    my $feature = shift;
    my $i1 = $node1->iset();
    my $i2 = $node2->iset();
    return 0 if($i1->get($feature) eq '' || $i2->get($feature) eq '');
    return 1 if($i1->get_joined($feature) eq $i2->get_joined($feature));
    # If one or both the nodes have multiple values of the feature and their
    # intersection is not empty, take it as agreement.
    my @v1 = $i1->get_list($feature);
    foreach my $v1 (@v1)
    {
        return 1 if($i2->contains($feature, $v1));
    }
    return 0;
}




#------------------------------------------------------------------------------
# Fixes annotation errors. In the Czech PDT, abbreviations are sometimes
# confused with prepositions. For example, "s.r.o." ("společnost s ručením
# omezeným" = "Ltd.") is tokenized as "s . r . o ." and both "s" and "o" could
# also be prepositions. Sometimes it happens that morphological analysis is
# correct (abbreviated NOUN resp. ADJ) but syntactic analysis is not (the
# incoming edge is labeled AuxP).
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
	
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $pos  = $node->iset()->pos();
        my $deprel = $node->deprel();
        if($form =~ m/^[so]$/i && !$node->is_adposition() && $deprel eq 'AuxP')
        {
            # We do not know what the correct deprel would be. There is a chance it would be Apposition or Atr but it is not guaranteed.
            # On the other hand, any of the two, even if incorrect, is much better than AuxP, which would trigger various transformations,
            # inappropriate in this context.
            $node->set_deprel('Atr');
        }
        # Fix unknown tags of punctuation. If the part of speech is unknown and the form consists only of punctuation characters,
        # set the part of speech to PUNCT. This occurs in the Ancient Greek Dependency Treebank.
        elsif($pos eq '' && $form =~ m/^\pP+$/)
        {
            $node->iset()->set_pos('punc');
        }
        # Czech "jakmile" is always tagged SCONJ (although one could also argue that it is a relative adverb of time).
        # In 55 cases it is attached as AuxC and in 1 case as Adv; but this 1 case is not different, it is an error.
        # Changing Adv to AuxC would normally also involve moving the conjunction between the subordinate predicate and
        # its parent, but we do not need to do that because our target style is UD and there both AuxC (mark) and Adv (advmod)
        # will be attached as children of the subordinate predicate.
        elsif(lc($form) eq 'jakmile' && $pos eq 'conj' && $deprel eq 'Adv')
        {
            $node->set_deprel('AuxC');
        }
        # In the Czech PDT, there is one occurrence of English "Devil ' s Hole", with the dependency AuxT(Devil, s).
        # Since "s" is not a reflexive pronoun, the convertor would convert the AuxT to compound:prt, which is not allowed in Czech.
        # Make it Atr instead. It will be converted to foreign.
        elsif($form eq 's' && $node->deprel() eq 'AuxT' && $node->parent()->form() eq 'Devil')
        {
            $node->set_deprel('Atr');
        }
        # In AnCora (ca+es), the MWE "10_per_cent" will have the lemma "10_%", which is a mismatch in number of elements.
        elsif($form =~ m/_(per_cent|por_ciento)$/i && $lemma =~ m/_%$/)
        {
            $lemma = lc($form);
            $node->set_lemma($lemma);
        }
    }
}



#------------------------------------------------------------------------------
# Relabel subordinate clauses. In the Croatian SETimes corpus, their predicates
# are labeled 'Pred', which translates as 'parataxis'. But we want to
# distinguish the various types of subordinate clauses instead.
#------------------------------------------------------------------------------
sub relabel_subordinate_clauses
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel eq 'parataxis')
        {
            my $parent = $node->parent();
            next if($parent->is_root());
            my @marks = grep {$_->deprel() eq 'mark'} ($node->children());
            # We do not know what to do when there is no mark. Perhaps it is indeed a parataxis?
            next if(scalar(@marks)==0);
            # Relative clauses modify a noun. They substitute for an adjective.
            if($parent->is_noun())
            {
                $node->set_deprel('acl');
                foreach my $mark (@marks)
                {
                    # The Croatian treebank analyzes both subordinating conjunctions and relative pronouns
                    # the same way. We want to separate them again. Pronouns should not be labeled 'mark'.
                    # They probably fill a slot in the frame of the subordinate verb: 'nsubj', 'obj' etc.
                    if($mark->is_pronoun() && $mark->is_noun())
                    {
                        my $case = $mark->iset()->case();
                        if($case eq 'nom' || $case eq '')
                        {
                            $mark->set_deprel('nsubj');
                        }
                        else
                        {
                            $mark->set_deprel('obj');
                        }
                    }
                }
            }
            # Complement clauses depend on a verb that requires them as argument.
            # Examples: he says that..., he believes that..., he hopes that...
            elsif(any {my $l = $_->lemma(); defined($l) && $l eq 'da'} (@marks))
            {
                $node->set_deprel('ccomp');
            }
            # Adverbial phrases modify a verb. They substitute for an adverb.
            # Example: ... if he passes the exam.
            else
            {
                $node->set_deprel('advcl');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::Udep

Converts dependency trees from the HamleDT/Prague style to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
