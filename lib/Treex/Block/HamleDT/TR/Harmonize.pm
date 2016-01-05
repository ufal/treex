package Treex::Block::HamleDT::TR::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'tr::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Turkish CoNLL trees, converts morphosyntactic tags to the universal
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->check_coord_membership($root);
    $self->check_afuns($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();
        my $afun   = 'NR';

        $afun = 'Adv' if ($deprel eq 'ABLATIVE.ADJUNCT');
        $afun = 'Apposition' if ($deprel eq 'APPOSITION');
        $afun = 'Atr' if ($deprel eq 'CLASSIFIER');
        $afun = 'Atr' if ($deprel eq 'COLLOCATION');
        # Coordinating conjunction or punctuation.
        if ($deprel eq 'COORDINATION')
        {
            $afun = 'Coord';
            $node->wild()->{coordinator} = 1;
        }
        $afun = 'Adv' if ($deprel eq 'DATIVE.ADJUNCT');
        $afun = 'Atr' if ($deprel eq 'DETERMINER');
        $afun = 'Atr' if ($deprel eq 'EQU.ADJUNCT');
        $afun = 'Atr' if ($deprel eq 'ETOL');
        $afun = 'Atr' if ($deprel eq 'DERIV');
        $afun = 'AuxZ' if ($deprel eq 'FOCUS.PARTICLE');
        $afun = 'Adv' if ($deprel eq 'INSTRUMENTAL.ADJUNCT');
        $afun = 'AuxZ' if ($deprel eq 'INTENSIFIER');
        $afun = 'Adv' if ($deprel eq 'LOCATIVE.ADJUNCT');

        # MODIFIER : Adv or Atr
        if ($deprel eq 'MODIFIER') {
            if (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            else {
                $afun = 'Atr';
            }
        }

        $afun = 'Adv' if ($deprel eq 'NEGATIVE.PARTICLE');

        # MODIFIER : OBJECT
        if ($deprel eq 'OBJECT') {
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $parpos = $parnode->get_iset('pos');
                if ($parpos eq 'adp') {
                    $afun = 'Atr';
                }
                else {
                    $afun = 'Obj';
                }
            }
            else {
                $afun = 'Obj';
            }
        }

        $afun = 'Atr' if ($deprel eq 'POSSESSOR');
        $afun = 'Atr' if ($deprel eq 'QUESTION.PARTICLE');
        $afun = 'Atr' if ($deprel eq 'RELATIVIZER');


        # punctuations
        if ( $deprel eq 'ROOT' ) {
            if (($node->get_iset('pos') eq 'punc')) {
                if ( $form eq ',' ) {
                    $afun = 'AuxX';
                }
                elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                    $afun = 'AuxK';
                }
                else {
                    $afun = 'AuxG';
                }
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Pred';
            }
            else {
                $afun = 'Atr';
            }
        }

        # SENTENCE
        if ( $deprel eq 'SENTENCE' ) {
            if (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Pred';
            }
            elsif (($node->get_iset('pos') eq 'punc')) {
                if ( $form eq ',' ) {
                    $afun = 'AuxX';
                }
                elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                    $afun = 'AuxK';
                }
                else {
                    $afun = 'AuxG';
                }

            }
            else {
                $afun = 'Atr';
            }
        }

        $afun = 'Atr' if ($deprel eq 'S.MODIFIER');
        $afun = 'Sb' if ($deprel eq 'SUBJECT');
        $afun = 'Atr' if ($deprel eq 'VOCATIVE');

        if ($node->is_adposition()) {
            $afun = 'AuxP';
        }

        # subordinating conjunctions
        if (($node->get_iset('conjtype') eq 'sub')) {
            $afun = 'AuxC';
        }

        $node->set_afun($afun);
    }
    # Fix known annotation errors that would negatively affect subsequent processing.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from deprel_to_afun() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    my $sentence = join(' ', map {$_->form()} (@nodes));
    # Google translate: Do not eat me ba old man, I said, what this town was founded fairs, but never came lion.
    if($sentence =~ m/^Beni yeme be moruk , dedim , ne panay.rlar _ kuruldu bu kasabaya , ama hi.bir zaman aslan gelmedi .$/)
    {
        log_info("FIXING: $sentence");
        my $dedim = $nodes[5];
        my $comma1 = $nodes[6];
        my $kuruldu = $nodes[10];
        my $comma2 = $nodes[13];
        my $ama = $nodes[14];
        my $gelmedi = $nodes[18];
        $dedim->set_parent($comma1);
        $comma1->set_parent($kuruldu);
        $kuruldu->set_parent($comma2);
        $comma2->set_parent($ama);
        $ama->set_parent($gelmedi);
        $gelmedi->set_parent($root);
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Turkish
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_ankara($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_orphans();
    push(@recurse, $coordination->get_children());
    return @recurse;
}



1;

=over

=item Treex::Block::HamleDT::TR::Harmonize


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
