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
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Turkish CoNLL trees, converts morphosyntactic tags to the universal
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;

    my $a_root = $self->SUPER::process_zone($zone);
    $self->hang_everything_under_pred($a_root);
    $self->attach_final_punctuation_to_root($a_root);
    $self->make_pdt_coordination($a_root);
    $self->check_apos_coord_membership($a_root);
    $self->get_or_load_other_block('HamleDT::Pdt2HamledtApos')->process_zone($a_root->get_zone());
    $self->check_afuns($a_root);
}

sub check_apos_coord_membership {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ($afun =~ /^(Apos|Coord)$/) {
            $self->identify_coap_members($node);
        }
    }
}

# In the original treebank, some of the nodes might be attached to technical root
# rather than with the predicate node. those nodes will
# be attached to predicate node.
sub hang_everything_under_pred {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_children();
    my @dnodes;
    my $prednode;
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $afun = $node->afun();
            my $ordn = $node->ord();
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $ordpar = $parnode->ord();
                if ($ordpar == 0) {
                    if ($afun ne 'Pred') {
                        push @dnodes, $node
                    }
                    else {
                        $prednode = $node;
                    }
                }
            }
        }
    }
    #
    if (scalar(@dnodes) > 0) {
        if (defined $prednode) {
            foreach my $dn (@dnodes) {
                if (defined $dn) {
                    $dn->set_parent($prednode);
                }
            }
        }
    }
}


sub make_pdt_coordination {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $parnode = $node->get_parent();
            my $parparnode = $parnode->get_parent();
            my $afun = $node->afun();
            if ($afun eq 'Coord' && (defined $parnode) && (defined $parparnode)) {
                my @children = $node->get_children();
                foreach my $c (@children) {
                    if (defined $c) {
                        my $afunc = $c->afun();
                        $c->set_is_member(1) if ($afunc !~ /^(AuxX|AuxZ)$/);
                    }
                }
                $node->set_parent($parparnode);
                $parnode->set_parent($node);
                $parnode->set_is_member(1);
            }
        }
    }
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

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;

        $afun = 'Adv' if ($deprel eq 'ABLATIVE.ADJUNCT');
        $afun = 'Apos' if ($deprel eq 'APPOSITION');
        $afun = 'Atr' if ($deprel eq 'CLASSIFIER');
        $afun = 'Atr' if ($deprel eq 'COLLOCATION');
        $afun = 'Coord' if ($deprel eq 'COORDINATION');
        $afun = 'Adv' if ($deprel eq 'DATIVE.ADJUNCT');
        $afun = 'AuxA' if ($deprel eq 'DETERMINER');
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
                if ($parpos eq 'prep') {
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

        if (($node->get_iset('pos') eq 'prep')) {
            $afun = 'AuxP';
        }

        # subordinating conjunctions
        if (($node->get_iset('subpos') eq 'sub')) {
            $afun = 'AuxC';
        }

        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::HamleDT::TR::Harmonize


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
