package Treex::Block::HamleDT::IT::Harmonize;
use feature state;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'it::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Phrase-based implementation of tree transformations (5.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->relabel_conjunctless_commas($root);
    $self->mark_deficient_clausal_coordination($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $form   = $node->form;
        my $pos    = $node->conll_pos;
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');

        # Coordinating conjunctions.
        if ($deprel =~ m/^(con|dis)$/)
        {
            if($form eq ',')
            {
                $deprel = 'AuxX';
            }
            elsif($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            else
            {
                # Some conjunctions will be relabeled Coord later during coordination processing.
                # But some will not, often due to annotation errors. To make sure that there are no Coords without conjuncts, we label them AuxY at the moment.
                $deprel = 'AuxY';
            }
            $node->wild()->{coordinator} = 1;
        }
        # Conjunct (not the first one in a coordination).
        elsif ($deprel =~ m/^(con|dis)g$/)
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # Punctuation that is not labeled as coordinating.
        elsif ( $deprel eq 'punc' )
        {
            if ( $form eq ',' )
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }

        # trivial conversion to PDT style deprel
        $deprel = 'Atv'   if ( $deprel eq 'arg' );        # arg       -> Atv
        $deprel = 'AuxV'  if ( $deprel eq 'aux' );        # aux       -> AuxV
        $deprel = 'AuxT'  if ( $deprel eq 'clit' );       # clit      -> AuxT
        $deprel = 'Obj'   if ( $deprel eq 'comp' );       # comp      -> Obj
        $deprel = 'Atr'   if ( $deprel eq 'concat' );     # concat    -> Atr
        $deprel = 'SubArg' if ( $deprel eq 'cong_sub');    # cong_sub  -> AuxC
        $deprel = 'Atr'  if ( $deprel eq 'det' );          # det       -> Atr (in future maybe AuxA)
        $deprel = 'AuxV'  if ( $deprel eq 'modal' );      # modal     -> AuxV
        $deprel = 'Adv'   if ( $deprel eq 'obl' );        # obl       -> Adv
        $deprel = 'Obj'   if ( $deprel eq 'ogg_d' );      # ogg_d     -> Obj
        $deprel = 'Obj'   if ( $deprel eq 'ogg_i' );      # ogg_i     -> Obj
        $deprel = 'Pnom'  if ( $deprel eq 'pred' );       # pred      -> Pnom
        $deprel = 'PrepArg' if ( $deprel eq 'prep' );       # prep      -> AuxP
        $deprel = 'Sb'    if ( $deprel eq 'sogg' );       # sogg      -> Sb

        # $deprel = 'Atr'   if ( $deprel eq 'mod' );        # mod       -> Atr
        # $deprel = 'Atr'   if ( $deprel eq 'mod_rel' );    # mod_rel   -> Atr
        if ($deprel =~ /^mod(?:_rel)?$/) {
            if ($ppos =~ /^n(?:oun|um)$/) {
                $deprel = 'Atr';
            } else {
                $deprel = 'Adv';
            }
        }

        # deprelation ROOT can be 'Pred'            # pred      -> Pred
        if ( ($deprel eq 'ROOT') && ($node->get_iset('pos') eq 'verb')) {
            $deprel = 'Pred';
        }
        elsif ( ($deprel eq 'ROOT') && !($node->get_iset('pos') eq 'verb')){
            $deprel = 'ExD';
        }
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors and irregularities.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    if(scalar(@nodes)>3 && lc(join(' ', map {$_->form()} (@nodes[0..2]))) eq 'già , ma')
    {
        my $gia = $nodes[0];
        my $comma = $nodes[1];
        my $ma = $nodes[2];
        my @predicates = grep {$_->parent()->is_root()} (@nodes[3..$#nodes]);
        if(@predicates)
        {
            $ma->set_parent($root);
            $ma->set_is_member(undef);
            $ma->set_deprel('Coord');
            foreach my $p (@predicates)
            {
                $p->set_parent($ma);
                $p->set_is_member(1);
            }
            $gia->set_parent($ma);
            $gia->set_is_member(1);
            $gia->set_deprel('ExD');
            $comma->set_parent($ma);
            $comma->set_is_member(undef);
            $comma->set_deprel('AuxX');
        }
    }
    foreach my $node (@nodes)
    {
        # Unannotated coordination of the form "prima contro X e poi contro Y".
        if($node->form() eq 'prima')
        {
            my @rsiblings = $node->get_siblings({following_only => 1});
            if(scalar(@rsiblings)>=4 && $rsiblings[1]->form() eq 'e' && $rsiblings[2]->form() eq 'poi' && $rsiblings[0]->deprel() eq $rsiblings[3]->deprel())
            {
                # Attach prima ("first") to the first conjunct.
                $node->set_parent($rsiblings[0]);
                # Attach poi ("then") to the second conjunct.
                $rsiblings[2]->set_parent($rsiblings[3]);
                # Attach the two conjuncts to the conjunction.
                $rsiblings[0]->set_parent($rsiblings[1]);
                $rsiblings[3]->set_parent($rsiblings[1]);
                $rsiblings[0]->set_is_member(1);
                $rsiblings[3]->set_is_member(1);
                # The conjunction probably already has the Coord deprel but make sure it does.
                $rsiblings[1]->set_deprel('Coord');
            }
        }
        # The verb è ("is") confused with the conjunction e ("and").
        elsif($node->form() eq 'è' && $node->is_verb() && $node->deprel() eq 'Coord')
        {
            ###!!! The problem is that we do not know the real deprel of the verb.
            ###!!! But we cannot leave Coord here because there are no conjuncts and the annotation would not be consistent.
            ###!!! The Pred deprel might work if this is the main predicate of the sentence; otherwise, we would have to recognize a relative clause.
            $node->set_deprel('Pred');
        }
        # Coordinating conjunction deeply attached to the subtree of the first conjunct instead of being left sibling of the second conjunct.
        # We can detect it if the following node is the head of the second conjunct. If there are left dependents, we cannot.
        elsif($node->wild()->{coordinator} && $node->is_leaf() && !$node->get_right_neighbor() && $node->get_next_node() && $node->get_next_node()->wild()->{conjunct})
        {
            my $conjunction = $node;
            my $rconjunct = $node->get_next_node();
            # Coordination has not been normalized yet, so the right conjunct should be attached to the first conjunct.
            my $fconjunct = $rconjunct->parent();
            $conjunction->set_parent($fconjunct);
        }
        # Coordinating conjunction deeply attached as in the previous case but here the conjuncts are siblings and the second conjunct is not labeled as conjunct.
        elsif($node->wild()->{coordinator} && $node->is_leaf() && !$node->get_right_neighbor() && $node->get_next_node())
        {
            my $conjunction = $node;
            my $rconjunct = $node->get_next_node();
            my $lconjunct = $rconjunct->get_left_neighbor();
            if($lconjunct && $rconjunct && !$lconjunct->is_punctuation() && !$rconjunct->is_punctuation() && $lconjunct->deprel() eq $rconjunct->deprel())
            {
                $conjunction->set_parent($lconjunct);
                $rconjunct->set_parent($lconjunct);
                $rconjunct->wild()->{conjunct} = 1;
            }
        }
        # Coordinating conjunction attached as sibling of both conjuncts.
        # Morphological annotation does not allow for the distinction between coordinating and subordinating conjunctions, so we have to look at the words.
        elsif($node->is_conjunction() && $node->form() =~ m/^(e|o|ma)$/ && $node->is_leaf() && $node->get_left_neighbor() && $node->get_right_neighbor())
        {
            my $conjunction = $node;
            my $lconjunct = $node->get_left_neighbor();
            my $rconjunct = $node->get_right_neighbor();
            if(!$lconjunct->wild()->{conjunct} && !$rconjunct->wild()->{conjunct} &&
               !$lconjunct->is_punctuation() && !$rconjunct->is_punctuation() &&
               $lconjunct->deprel() eq $rconjunct->deprel())
            {
                my $deprel = $lconjunct->deprel();
                my @conjuncts = ($lconjunct, $rconjunct);
                my @delimiters = ($conjunction);
                my @lsiblings = $lconjunct->get_siblings({preceding_only => 1});
                while(scalar(@lsiblings)>=2 && $lsiblings[$#lsiblings]->form() eq ',' && $lsiblings[$#lsiblings-1]->deprel() eq $deprel)
                {
                    my $comma = pop(@lsiblings);
                    my $conjunct = pop(@lsiblings);
                    push(@conjuncts, $conjunct);
                    push(@delimiters, $comma);
                }
                # Reshape coordination to the form it should have had according to the original annotation schema.
                my $firstconjunct = shift(@conjuncts);
                foreach my $c (@conjuncts)
                {
                    $c->set_parent($firstconjunct);
                    $c->set_deprel('CoordArg');
                    $c->wild()->{conjunct} = 1;
                    $c->wild()->{coordinator} = undef;
                }
                foreach my $d (@delimiters)
                {
                    $d->set_parent($firstconjunct);
                    if($d->form() eq ',')
                    {
                        $d->set_deprel('AuxX');
                    }
                    else
                    {
                        $d->set_deprel('Coord');
                    }
                    $d->wild()->{conjunct} = undef;
                    $d->wild()->{coordinator} = 1;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Commas had the same label as coordinating conjunctions, regardless whether
# their function was coordinating or not. As a result, we now have a number of
# commas with the deprel Coord, which are leaves and do not have any conjuncts.
#------------------------------------------------------------------------------
sub relabel_conjunctless_commas
{
    my $self = shift;
    my $root = shift;
    foreach my $node ($root->get_descendants())
    {
        if($node->form() eq ',' && $node->deprel() eq 'Coord' && $node->is_leaf())
        {
            $node->set_deprel('AuxX');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::IT::Harmonize

Converts the ISST Italian treebank (as prepared for the CoNLL 2007 shared task)
to the HamleDT (Prague) annotation style.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
