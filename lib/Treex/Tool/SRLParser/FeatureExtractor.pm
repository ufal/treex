package Treex::Tool::SRLParser::FeatureExtractor;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/ uniq /;

has 'feature_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has 'value_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => '/',
);

has 'debug_printing_mode' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

has '_feature_to_code' => (
    is          => 'ro',
    isa         => 'HashRef',
    default     => sub { {  'ChildrenPOS'       => 'P1',
                            'PredicateChildrenPOS'  => 'P1a',
                            'DepwordChildrenPOS'    => 'P1b',
                            'ChildrenPOSNoDup'  => 'P2',
                            'PredicateChildrenPOSNoDup' => 'P2a',
                            'DepwordChildrenPOSNoDup' => 'P2b',
                            'ConstituentPOSPattern' => 'P3',
                            'ConstituentPOSPattern+DepRelation' => 'P4',
                            'ConstituentPOSPattern+DepwordLemma' => 'P5',
                            'ConstituentPOSPattern+HeadwordLemma' => 'P6',
                            'PredicateConstituentPOSPattern' => 'P3a',
                            'PredicateConstituentPOSPattern+DepRelation' => 'P4a',
                            'PredicateConstituentPOSPattern+DepwordLemma' => 'P5a',
                            'PredicateConstituentPOSPattern+HeadwordLemma' => 'P6a',
                            'DepwordConstituentPOSPattern' => 'P3b',
                            'DepwordConstituentPOSPattern+DepRelation' => 'P4b',
                            'DepwordConstituentPOSPattern+DepwordLemma' => 'P5b',
                            'DepwordConstituentPOSPattern+HeadwordLemma' => 'P6b',
                            'DepRelation' => 'P7',
                            'DepRelation+DepwordLemma' => 'P8',
                            'DepRelation+HeadwordLemma' => 'P9',
                            'DepRelation+HeadwordLemma+DepwordLemma' => 'P10',
                            'Depword' => 'P11',
                            'DepwordLemma' => 'P12',
                            'DepwordLemma+RelationPath' => 'P13',
                            'DepwordPOS' => 'P13',
                            'DepwordPOS+HeadwordPOS' => 'P14',
                            'DownPathLength' => 'P15',
                            'FirstLemma' => 'P16',
                            'FirstPOS' => 'P17',
                            'FirstPOS+DepwordPOS' => 'P18',
                            'HeadwordLemma' => 'P19',
                            'HeadwordLemma+RelationPath' => 'P20',
                            'HeadwordPOS' => 'P21',
                            'LastLemma' => 'P22',
                            'LastPOS' => 'P23',
                            'Path' => 'P24',
                            'Path+RelationPath' => 'P25',
                            'PathLength' => 'P26',
                            'PFEATSplit' => 'P27',
                            'PredicatePFEATSplit' => 'P27a',
                            'DepwordPFEATSplit' => 'P27b',
                            'PositionWithPredicate' => 'P28',
                            'Predicate' => 'P29',
                            'Predicate+PredicateFamilyship' => 'P30',
                            'PredicateLemma' => 'P31',
                            'PredicateLemma+PredicateFamilyship' => 'P32',
                            'PredicateSense' => 'P33',
                            'PredicateSense+DepRelation' => 'P34',
                            'PredicateSense+DepwordLemma' => 'P35',
                            'PredicateSense+DepwordPOS' => 'P36',
                            'RelationPath' => 'P37',
                            'SiblingsRELNoDup' => 'P38',
                            'PredicateSiblingsRELNoDup' => 'P38a',
                            'DepwordSiblingsRELNoDup' => 'P38b',
                            'UpPath' => 'P39',
                            'PredicateUpPath' => 'P39a',
                            'DepwordUpPath' => 'P39b',
                            'UpPathLength' => 'P40',
                            'PredicateUpPathLength' => 'P41a',
                            'DepwordUpPathLength' => 'P41b',
                            'UpRelationPath+HeadwordLemma' => 'P42',
                            'PredicateUpRelationPath+HeadwordLemma' => 'P42a',
                            'DepwordUpRelationPath+HeadwordLemma' => 'P42b',
                            'PredicatePOS' => 'P43',
                            'DepwordFeat' => 'P44',
                            'PredicateFeat' => 'P45',
                            'Distance' => 'P46',
                            'PositionToPredicate' => 'P47',
                            'PredicatePosition' => 'P48',
                            'DepwordPosition' => 'P49',
                            'PredicateHeadword' => 'P50',
                            'PredicateHeadword' => 'P51',
                            'PredicateHeadwordPOS' => 'P52',
                            'PredicateHeadwordLemma' => 'P53',
                            'DepwordConstituentFirstWord' => 'P54',
                            'DepwordConstituentFirstPOS' => 'P55',
                            'DepwordConstituentFirstLemma' => 'P56',
                            'DepwordConstituentLastWord' => 'P57',
                            'DepwordConstituentLastPOS' => 'P58',
                            'DepwordConstituentLastLemma' => 'P59',
                            'IsInFrame' => 'P60',
                            'Frame' => 'P61',
                            'DepwordAfun' => 'P62',
                            'PredicateAfun' => 'P63',
                            'PredicateTagPos' => 'P64',
                            'PredicateTagSubpos' => 'P65',
                            'PredicateTagGender' => 'P66',
                            'PredicateTagNumber' => 'P67',
                            'PredicateTagCase' => 'P68',
                            'PredicateTagPossgender' => 'P69',
                            'PredicateTagPossnumber' => 'P70',
                            'PredicateTagPerson' => 'P71',
                            'PredicateTagTense' => 'P72',
                            'PredicateTagGrade' => 'P73',
                            'PredicateTagNegation' => 'P74',
                            'PredicateTagVoice' => 'P75',
                            'DepwordTagPos' => 'P76',
                            'DepwordTagSubpos' => 'P77',
                            'DepwordTagGender' => 'P78',
                            'DepwordTagNumber' => 'P79',
                            'DepwordTagCase' => 'P80',
                            'DepwordTagPossgender' => 'P81',
                            'DepwordTagPossnumber' => 'P82',
                            'DepwordTagPerson' => 'P83',
                            'DepwordTagTense' => 'P84',
                            'DepwordTagGrade' => 'P85',
                            'DepwordTagNegation' => 'P86',
                            'DepwordTagVoice' => 'P87',
                            'PredicateFamilyship' => 'P88',
                        } },
);

sub extract_features() {
    my ( $self, $a_root, $predicate, $depword ) = @_; 

    # Preprocessing: find out some information about predicate and depword candidates
    # to use in classification features 
    my $headword = $depword->get_parent;
    my $predicate_headword = $predicate->get_parent;
    # deprel = dependency relationship between predicate and depword candidate in a-tree
    my $deprel = (($headword) and ($headword->id eq $predicate->id)) ? $depword->afun : $self->empty_sign;
    my @predicate_children_pos = map { substr($_->tag, 0, 1) } $predicate->get_children( { ordered => 1, add_self => 0 } );
    my @depword_children_pos = map { substr($_->tag, 0, 1) } $predicate->get_children( { ordered => 1, add_self => 0 } );
    my @path = $self->_find_path($a_root, $predicate, $depword, 'start_to_end');
    my @predicate_up_path = $self->_find_path($a_root, $predicate, $depword, 'start_up_path');
    my @depword_up_path = $self->_find_path($a_root, $predicate, $depword, 'end_up_path');
    my @predicate_up_pos_path = map { $_->tag ? substr($_->tag, 0, 1) : $self->empty_sign } @predicate_up_path;
    my @depword_up_pos_path = map { $_->tag ? substr($_->tag, 0, 1) : $self->empty_sign } @depword_up_path;

    my $path_length = @path;
    my @pos_path = map { $_->tag ? substr($_->tag, 0, 1) : $self->empty_sign } @path;
    my @rel_path = map { $_->afun } @path;
    my @predicate_up_rel_path = map { $_->afun } @predicate_up_path;
    my @depword_up_rel_path = map { $_->afun } @depword_up_path;
    my $distance = abs($predicate->ord - $depword->ord);
    my $ord_diff = $predicate->ord - $depword->ord;
    my $depword_pos = substr($depword->tag, 0, 1);
    my $predicate_pos = substr($predicate->tag, 0, 0);
    my $depword_lemma = $self->_get_short_lemma($depword);
    my $predicate_lemma = $self->_get_short_lemma($predicate);
    my $predicate_sense = $predicate->lemma;
    my $familyship = $self->_get_familyship($predicate, $depword);
    # Headword features
    my $headword_pos = $self->empty_sign;
    my $headword_lemma = $self->empty_sign;
    if ($headword) {
        $headword_pos = substr($headword->tag, 0, 1) if $headword->tag;
        $headword_lemma = $self->_get_short_lemma($headword);
    }
    # Predicate headword features
    my $predicate_headword_pos = $self->empty_sign;
    my $predicate_headword_form = $self->empty_sign;
    my $predicate_headword_lemma = $self->empty_sign;
    if ($predicate_headword) {
        $predicate_headword_pos = substr($predicate_headword->tag, 0, 1) if $predicate_headword->tag;
        $predicate_headword_lemma = $self->_get_short_lemma($predicate_headword);
        $predicate_headword_form = $predicate_headword->form if $predicate_headword->form;
    }
    # First = predicate leftmost descendant
    my $predicate_first = $predicate->get_descendants({ first_only => 1 });
    my $predicate_first_pos = $predicate_first ? substr($predicate_first, 0, 1) : $self->empty_sign;
    my $predicate_first_lemma = $predicate_first ? $self->_get_short_lemma($predicate_first) : $self->empty_sign;
    # Last = predicate rightmost descendant
    my $predicate_last = $predicate->get_descendants({ last_only => 1 });
    my $predicate_last_pos = $predicate_last ? substr($predicate_last->tag, 0, 1) : $self->empty_sign;
    my $predicate_last_lemma = $predicate_last ? $self->_get_short_lemma($predicate_last) : $self->empty_sign;
    # DepwordFirst = depword leftmost descendant
    my $depword_first = $depword->get_descendants({ first_only => 1 });
    my $depword_first_pos = $depword_first ? substr($depword_first, 0, 1) : $self->empty_sign;
    my $depword_first_lemma = $depword_first ? $self->_get_short_lemma($depword_first) : $self->empty_sign;
    my $depword_first_form = $depword_first ? $depword_first->form : $self->empty_sign;
    # DepwordLast = depword rightmost descendant
    my $depword_last = $depword->get_descendants({ last_only => 1 });
    my $depword_last_pos = $depword_last ? substr($depword_last->tag, 0, 1) : $self->empty_sign;
    my $depword_last_lemma = $depword_last ? $self->_get_short_lemma($depword_last) : $self->empty_sign;
    my $depword_last_form = $depword_last ? $depword_last->form : $self->empty_sign;
    # Predicate constituent POS pattern
    my @predicate_constituent_pos_pattern = $self->_get_constituent_pos_pattern($predicate);
    # Depword constituent POS pattern
    my @depword_constituent_pos_pattern = $self->_get_constituent_pos_pattern($depword);
 
    my @features;

    ### Features from Che & spol. ###
    # For explanation of these feature names, see paper
    # "A Cascaded Syntactic and Semantic Dependency Parsing System":
    # http://ir.hit.edu.cn/~car/papers/conll08.pdf

    # ChildrenPOS
    push @features, $self->_make_feature('PredicateChildrenPOS', @predicate_children_pos);
    push @features, $self->_make_feature('DepwordChildrenPOS', @depword_children_pos);
    # ChildrenPOSNoDup
    push @features, $self->_make_feature('PredicateChildrenPOSNoDup', uniq @predicate_children_pos);
    push @features, $self->_make_feature('DepwordChildrenPOSNoDup', uniq @depword_children_pos);
    # PredicateConstituentPOSPattern
    push @features, $self->_make_feature('PredicateConstituentPOSPattern',
        @predicate_constituent_pos_pattern);
    # PredicateConstituentPOSPattern+DepRelation
    push @features, $self->_make_feature('PredicateConstituentPOSPattern+DepRelation',
        (@predicate_constituent_pos_pattern, $deprel) );
    # PredicateConstituentPOSPattern+DepwordLemma
    push @features, $self->_make_feature('PredicateConstituentPOSPattern+DepwordLemma',
        (@predicate_constituent_pos_pattern, $depword_lemma ) );
    # PredicateConstituentPOSPattern+HeadwordLemma
    push @features, $self->_make_feature('PredicateConstituentPOSPattern+HeadwordLemma',
        (@predicate_constituent_pos_pattern, $headword_lemma) );
    # DepwordConstituentPOSPattern
    push @features, $self->_make_feature('DepwordConstituentPOSPattern',
        @depword_constituent_pos_pattern);
    # DepwordConstituentPOSPattern+DepRelation
    push @features, $self->_make_feature('DepwordConstituentPOSPattern+DepRelation',
        (@depword_constituent_pos_pattern, $deprel) );
    # DepwordConstituentPOSPattern+DepwordLemma
    push @features, $self->_make_feature('DepwordConstituentPOSPattern+DepwordLemma',
        (@depword_constituent_pos_pattern, $depword_lemma ) );
    # DepwordConstituentPOSPattern+HeadwordLemma
    push @features, $self->_make_feature('DepwordConstituentPOSPattern+HeadwordLemma',
        (@depword_constituent_pos_pattern, $headword_lemma) );
    # DepRelation
    push @features, $self->_make_feature('DepRelation', $deprel);
    # DepRelation+DepwordLemma
    push @features, $self->_make_feature('DepRelation+DepwordLemma', ( $deprel, $depword_lemma )); 
    # DepRelation+HeadwordLemma
    push @features, $self->_make_feature('DepRelation+HeadwordLemma', ( $deprel, $headword_lemma ));
    # DepRelation+HeadwordLemma+DepwordLemma
    push @features, $self->_make_feature('DepRelation+HeadwordLemma+DepwordLemma',
        ( $deprel, $headword_lemma, $depword_lemma));
    # Depword
    push @features, $self->_make_feature('Depword', $depword->form);
    # DepwordLemma
    push @features, $self->_make_feature('DepwordLemma', $depword_lemma);
    # DepwordLemma+RelationPath
    push @features, $self->_make_feature('DepwordLemma+RelationPath', ($depword_lemma, @rel_path));
    # DepwordPOS
    push @features, $self->_make_feature('DepwordPOS', $depword_pos);
    # DepwordPOS+HeadwordPOS
    push @features, $self->_make_feature('DepwordPOS+HeadwordPOS', ( $depword_pos, $headword_pos) ); 
    # DownPathLength
    # is actually contained in either PredicateUpPathLength or DepwordUpPathLength
    # FirstLemma
    push @features, $self->_make_feature('FirstLemma', $predicate_first_lemma);
    # FirstPOS
    push @features, $self->_make_feature('FirstPOS', $predicate_first_pos);
    # FirstPOS+DepwordPOS
    push @features, $self->_make_feature('FirstPOS+DepwordPOS', ($predicate_first_pos, $depword_pos));
    # HeadwordLemma
    push @features, $self->_make_feature('HeadwordLemma', $headword_lemma);
    # HeadwordLemma+RelationPath
    push @features, $self->_make_feature('HeadwordLemma+RelationPath', ( $headword_lemma, @rel_path ));
    # HeadwordPOS
    push @features, $self->_make_feature('HeadwordPOS', $headword_pos);
    # LastLemma
    push @features, $self->_make_feature('LastLemma', $predicate_last_lemma);
    # LastPOS
    push @features, $self->_make_feature('LastPOS', $predicate_last_pos);
    # Path
    push @features, $self->_make_feature('Path', @pos_path);
    # Path+RelationPath
    push @features, $self->_make_feature('Path+RelationPath', (@pos_path, @rel_path));
    # PathLength
    push @features, $self->_make_feature('PathLength', $path_length);
    # PFEATSplit
    # see features P64 to P87
    # PositionWithPredicate
    # see feature PositionToPredicate
    # Predicate
    push @features, $self->_make_feature('Predicate', $predicate->form);
    # Predicate+PredicateFamilyship
    push @features, $self->_make_feature('Predicate+PredicateFamilyship',
        ( $predicate->form, $familyship ));
    # PredicateLemma
    push @features, $self->_make_feature('PredicateLemma', $predicate_lemma);
    # PredicateLemma+PredicateFamilyship
    push @features, $self->_make_feature('PredicateLemma+PredicateFamilyship',
        ( $predicate_lemma, $familyship ));
    # PredicateSense
    push @features, $self->_make_feature('PredicateSense', $predicate_sense);
    # PredicateSense+DepRelation
    push @features, $self->_make_feature('PredicateSense+DepRelation', ( $predicate_sense, $deprel ));
    # PredicateSense+DepwordLemma
    push @features, $self->_make_feature('PredicateSense+DepwordLemma', ($predicate_sense, $depword_lemma));
    # PredicateSense+DepwordPOS
    push @features, $self->_make_feature('PredicateSense+DepwordPOS', ($predicate_sense, $depword_pos));
    # RelationPath
    push @features, $self->_make_feature('RelationPath', @rel_path);
    # SiblingsRELNoDup
    push @features, $self->_make_feature('PredicateSiblingsRELNoDup', uniq map { $_->afun } $predicate->get_siblings);
    push @features, $self->_make_feature('DepwordSiblingsRELNoDup', uniq map { $_->afun } $depword->get_siblings);
    # UpPath
    push @features, $self->_make_feature('PredicateUpPath', @predicate_up_pos_path);
    push @features, $self->_make_feature('DepwordUpPath', @depword_up_pos_path);
    # UpPathLength
    my $predicate_up_path_length = @predicate_up_path;
    push @features, $self->_make_feature('PredicateUpPathLength', $predicate_up_path_length);
    my $depword_up_path_length = @depword_up_path;
    push @features, $self->_make_feature('DepwordUpPathLength', $depword_up_path_length);
    # UpRelationPath+HeadwordLemma
    push @features, $self->_make_feature('PredicateUpRelationPath+HeadwordLemma',
        ( @predicate_up_rel_path, $headword_lemma));
    push @features, $self->_make_feature('DepwordUpRelationPath+HeadwordLemma',
        ( @depword_up_rel_path, $headword_lemma));
    
    ### My features ###

    # PredicatePOS
    push @features, $self->_make_feature('PredicatePOS', $predicate_pos);
    # DepwordFeat
    push @features, $self->_make_feature('DepwordFeat', $depword->tag);
    # PredicateFeat
    push @features, $self->_make_feature('PredicateFeat', $predicate->tag);
    # Distance
    push @features, $self->_make_feature('Distance', $distance);
    # PositionToPredicate
    push @features, $self->_make_feature('PositionToPredicate', ($ord_diff == 0 ? "IsPredicate" : ($ord_diff > 0 ? "BeforePredicate" : "AfterPredicate")));  
    # PredicatePosition
    push @features, $self->_make_feature('PredicatePosition', $predicate->ord);
    # DepwordPosition
    push @features, $self->_make_feature('DepwordPosition', $depword->ord);
    # PredicateHeadword
    push @features, $self->_make_feature('PredicateHeadword', $predicate_headword_form);
    # PredicateHeadwordPOS
    push @features, $self->_make_feature('PredicateHeadwordPOS', $predicate_headword_pos);
    # PredicateHeadwordLemma
    push @features, $self->_make_feature('PredicateHeadwordLemma', $predicate_headword_lemma);
    # DepwordConstituentFirstWord
    push @features, $self->_make_feature('DepwordConstituentFirstWord', $depword_first_form);
    # DepwordConstituentFirstPOS
    push @features, $self->_make_feature('DepwordConstituentFirstPOS', $depword_first_pos);
    # DepwordConstituentFirstLemma
    push @features, $self->_make_feature('DepwordConstituentFirstLemma', $depword_first_lemma);
    # DepwordConstituentLastWord
    push @features, $self->_make_feature('DepwordConstituentLastWord', $depword_last_form);
    # DepwordConstituentLastPOS
    push @features, $self->_make_feature('DepwordConstituentLastPOS', $depword_last_pos);
    # DepwordConstituentLastLemma
    push @features, $self->_make_feature('DepwordConstituentLastLemma', $depword_last_lemma);
    # IsInFrame
    # TODO
    # Frame
    # TODO
    # DepwordAfun
    push @features, $self->_make_feature('DepwordAfun', $depword->afun);
    # PredicateAfun
    push @features, $self->_make_feature('PredicateAfun', $predicate->afun);
    # PredicateTagPos
    # TODO
    # PredicateTagSubpos
    # TODO
    # PredicateTagGender
    # TODO
    # PredicateTagNumber
    # TODO
    # PredicateTagCase
    # TODO
    # PredicateTagPossgender
    # TODO
    # PredicateTagPossnumber
    # TODO
    # PredicateTagPerson
    # TODO
    # PredicateTagTense
    # TODO
    # PredicateTagGrade
    # TODO
    # PredicateTagNegation
    # TODO
    # PredicateTagVoice
    # TODO
    # DepwordTagPos
    # TODO
    # DepwordTagSubpos
    # TODO
    # DepwordTagGender
    # TODO
    # DepwordTagNumber
    # TODO
    # DepwordTagCase
    # TODO
    # DepwordTagPossgender
    # TODO
    # DepwordTagPossnumber
    # TODO
    # DepwordTagPerson
    # TODO
    # DepwordTagTense
    # TODO
    # DepwordTagGrade
    # TODO
    # DepwordTagNegation
    # TODO
    # DepwordTagVoice
    # TODO
    # PredicateFamilyship
    # TODO
   
    return join($self->feature_delim, @features);
}

sub _make_feature() {
    my ( $self, $name, @values ) = @_;

    return $self->_feature_to_code->{$name} . $self->value_delim . (@values ? join($self->value_delim, @values) : $self->empty_sign);
}

sub _get_familyship() {
    my ( $self, $predicate, $depword ) = @_;

    return 'self' if $predicate->id eq $depword->id;
    return 'child' if grep { $depword->id eq $_->id } $predicate->get_children;
    return 'descendant' if grep { $depword->id eq $_->id } $predicate->get_descendants;
    return 'parent' if grep { $predicate->id eq $_->id } $depword->get_children;
    return 'ancestor' if grep { $predicate->id eq $_->id } $depword->get_descendants;
    return 'sibling' if $predicate->get_parent->id eq $depword->get_parent->id;
    return 'none'
}

sub _get_short_lemma {
    my ( $self, $a_node ) = @_;

    return $self->empty_sign if not $a_node->lemma;

    $a_node->lemma =~ m/^([^_\-`]*)/; 
    return $1;
}

sub _get_constituent_pos_pattern {
    my ( $self, $a_node ) = @_;

    my @descendants = $a_node->get_descendants({ordered => 1});
    
    my $n_descendants = @descendants;
    if ($n_descendants == 0) {  # no descendants
        return ('_');
    }
    if ($n_descendants > 0 and $n_descendants <= 2) {   # only first or only first and last
        return map { substr($_->tag, 0, 1) } @descendants;
    }

    my $first = shift(@descendants);
    my $last = pop(@descendants);

    my $first_pos = substr($first->tag, 0, 1);
    my $last_pos = substr($last->tag, 0, 1);

    my @descendants_pos = sort(uniq( map { substr($_->tag, 0, 1) } @descendants));

    return ($first_pos, @descendants_pos, $last_pos);
}

# Find path from start a-node to end a-node 
# and return an array of a-nodes along the path.
# The algorithm depends on each a-node having at most one parent
# and the a-tree having no loops.
sub _find_path() {
    my ( $self, $a_root, $start, $end, $path_type ) = @_;
   
    return ($start) if ($start->id eq $end->id);

    # go up from a-node "start" to "a_root" and mark visited a-nodes
    my %start_up_path_nodes;
    my @start_up_path = ();
    
    my $act = $start;
    $start_up_path_nodes{$act->id} = 1;
    push @start_up_path, $act;
    
    while ($act->id ne $a_root->id) {
        $act = $act->parent;
        $start_up_path_nodes{$act->id} = 1;
        push @start_up_path, $act;
    }

    # go up from a-node end until marked a-node is reached
    my @end_up_path = ();
    $act = $end;
    while (not exists $start_up_path_nodes{$act->id}) {
        push @end_up_path, $act;
        $act = $act->parent;
    }

    # delete all a-nodes from common parent to a-root
    my $common_parent = $act;
    while ((pop @start_up_path)->id ne $common_parent->id) {
    }

    my @path;
    if ($path_type eq 'start_to_end') {
        # concatenate paths
        @path = (@start_up_path, $common_parent, reverse(@end_up_path)); 
    }
    elsif ($path_type eq 'start_up_path') {
        @path = @start_up_path;
    }
    elsif ($path_type eq 'end_up_path') {
        @path = @end_up_path;
    }
    else {
        log_fatal('Unknown path type.');
    }

    return @path;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::SRLParser::FeatureExtractor

=head1 SYNOPSIS

my $feature_extractor = Treex::Tool::SRLParser::FeatureExtractor->new();
    
my @a_nodes = $a_root->get_descendants;
        
foreach my $predicate_candidate (@a_nodes) {

    foreach my $depword_candidate (@a_nodes) {

        print $feature_extractor->extract_features($predicate_candidate, $depword_candidate);
          
    }

}   

=head1 DESCRIPTION

Feature extractor for SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>. Given a pair of two treex a-nodes, it returns a string of classification features.

=head1 PARAMETERS

=over

=item feature_delim

Delimiter between features. Default is space, because Maximum Entropy Toolkit
expects spaces between features. 

=item value_delim

Delimiter between feature values in combined features, such as
PredicatePOS+DepwordPOS. This only makes sense in debug printing mode to make
combined features readable.

=item debug_printing_mode

If true, classification feature string is printed in human readable format.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage need to be implemented.

=item empty_sign

A string for denoting empty or undefined values, such as no semantic relation
in t-tree, no syntactic relation in a-tree, empty values for features, etc.

=back

=head1 METHODS 

=over

=item $self->extract_features( $self, $predicate, $depword )

Given two treex a-nodes, a predicate candidate and a depword candidate, it
returns a string of classification features.

=back

=head1 TODO

Implement all classification features as suggested by the paper.
Currently, all outputs are in debug printing mode, feature encoding to ensure
smaller memory and disk usage needs to be implemented.

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
