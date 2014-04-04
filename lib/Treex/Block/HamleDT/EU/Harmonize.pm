package Treex::Block::HamleDT::EU::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'eu::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
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
    $self->correct_punctuations($a_root);
    $self->correct_coordination($a_root);
    $self->check_coord_membership($a_root);
#    $self->get_or_load_other_block('HamleDT::Pdt2HamledtApos')->process_zone($a_root->get_zone());
#    $self->check_afuns($a_root);
}

# this function will call the function to make sure that
# all coordination members have 'is_member' set to 1
sub check_coord_membership {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ($afun eq 'Coord') {
            $self->identify_coap_members($node);
        }
    }
}

# will make PDT style coordination from the CoNLL data
sub make_pdt_coordination {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $afun = $node->afun();
            if ($afun eq 'Coord') {
                my @children = $node->get_children();
                foreach my $c (@children) {
                    if (defined $c) {
                        my $afunc = $c->afun();
                        $c->set_is_member(1) if ($afunc !~ /^(AuxX|AuxZ|AuxG|AuxK)$/);
                    }
                }
            }
        }
    }
}

# punctuations such as "," and ";" hanging under a node will be
# attached to the parents parent node
sub correct_punctuations {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $afun = $node->afun();
            my $ordn = $node->ord();
            if ($afun =~ /^(AuxX|AuxG|AuxK|AuxK)$/) {
                my $parnode = $node->get_parent();
                if (defined $parnode) {
                    my $parparnode = $parnode->get_parent();
                    if (defined $parparnode) {
                        my $ordpp = $parparnode->ord();
                        if ($ordpp > 0) {
                            $node->set_parent($parparnode);
                        }
                    }
                }
            }
        }
    }
}

# In the original treebank, some of the nodes might be attached to technical root
# rather than with the predicate node. those nodes will
# be attached to predicate node.
sub hang_everything_under_pred {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
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

# this function will find if there are 'Coordinations' that are not
# detected using the previous make_pdt_coordination function.
sub correct_coordination {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $form = $node->form();
            my $afun = $node->afun();
            if (($form =~ /^(eta|edo)$/) && ($afun ne 'Coord')) {
                $node->set_afun('Coord');
                my @children = $node->get_children();
                foreach my $c (@children) {
                    if (defined $c) {
                        my $afunc = $c->afun();
                        $c->set_is_member(1) if ($afunc !~ /^(AuxX|AuxZ|AuxG|AuxK)$/);
                    }
                }
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
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');

        my $connl_subpos = $node->conll_pos();
        my $connl_pos    = $node->conll_cpos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = "NR";

        # main predicate
        if ($deprel eq 'ROOT') {
            $afun = 'Pred';
        }

        # subject
        elsif (
            $deprel eq 'ncsubj' or
            $deprel eq 'ccomp_subj' or
            $deprel eq 'xcomp_subj'
        ) {
            $afun = 'Sb';
        }

        # object
        elsif (
            $deprel eq 'ncobj' or
            $deprel eq 'nczobj' or
            $deprel eq 'ccomp_obj' or
            $deprel eq 'ccomp_zobj' or
            $deprel eq 'xcomp_obj' or
            $deprel eq 'xcomp_zobj'
        ) {
            $afun = 'Obj';
        }

        # apposition
        elsif (
            $deprel eq 'apocmod' or
            $deprel eq 'apoxmod' or
            $deprel eq 'aponcmod' or
            $deprel eq 'aponcpred'
        ) {
            $afun = 'Apposition';
        }

        # determiner
        elsif ($deprel eq 'detmod') {
            $afun = 'AuxA';
        }

        # auxiliary verb
        elsif ($deprel eq 'auxmod') {
            $afun = 'AuxV';
        }

        # negation or attribute
        elsif ($deprel eq 'ncmod') {
            if ($ppos eq 'noun') {
                $afun = 'Atr';
            }
            else {
                $afun = 'Adv';
            }
        }

        # punctuation
        elsif (($node->get_iset('pos') eq 'punc')) {
            if ( $form eq ',' ) {
                $afun = 'AuxX';
            }
            elsif ( $form =~ /^[?:.!]$/ ) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # modifiers
        # 1. clausal & predicative modifiers are labeled as 'Adv'
        # 2. non clausal modifiers are labeled as 'Atr'

        # 1. clausal & predicative modifiers
        elsif (
            $deprel eq 'cmod' or
            $deprel eq 'xmod' or
            $deprel eq 'xpred' or
            $deprel eq 'ncpred'
        ) {
            if ($ppos eq 'noun') {
                $afun = 'Atr';
            }
            else {
                $afun = 'Adv';
            }
        }

        # connectors # !!! TODO
        elsif (($deprel eq 'lot') || ($deprel eq 'lotat')) {
            if (($node->get_iset('pos') eq 'noun')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'adv')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'adj')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $afun = 'Adv';
            }
            elsif (($node->get_iset('pos') eq 'num')) {
                $afun = 'Atr';
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'coor')) {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';
                }
                else {
                    $afun = 'Adv';
                }
            }
            elsif (($node->get_iset('pos') eq 'conj') && ($node->get_iset('subpos') eq 'sub')) {
                $afun = 'AuxC';
            }

            if ($pos eq 'ADL') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'ADI') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'IZE') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'BST') {
                $afun = 'Atr';
            }
        }

        # particles 
        # prtmod # !!JM TODO - "label used to mark various particles - 'badin', 'omen', etc."
        elsif ($deprel eq 'prtmod') {
            $afun = 'Atr';
        }
        # galdemod - focalizer (?)
        elsif ($deprel eq 'galdemod') {
            $afun = 'AuxZ';
        }

        # interjection # !!JM TODO - "Uf.itj_out, vydechl Petr.", "Nezmokni, Pavle.itj_out."
        if ($deprel eq 'itj_out') {
            $afun = 'Atr';
        }

        # attributes # JM not sure whether "attribute" is the right term, seems more like a part of a name
        if ($deprel eq 'entios') {
            $afun = 'Atr';
        }

        # postos # !!JM TODO - part of a complex postposition? so AuxP somewhere around?
        elsif ($deprel eq 'postos') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';
                }
                else {
                    $afun = 'Adv';
                }
            }
            elsif ($pos eq 'conj' and  $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # gradmod # !!JM TODO "el graduador" - used in comparison; "very", "too much", "more", ... - probably Atr/Adv based on ppos
        elsif ($deprel eq 'gradmod') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';
                }
                else {
                    $afun = 'Adv';
                }
            }
            elsif ($pos eq 'conj' and $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # menos
        elsif ($deprel eq 'menos') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                if ($form =~ /^(eta|edo)$/) {
                    $afun = 'Coord';
                }
                else {
                    $afun = 'Adv';
                }
            }
            elsif ($pos eq 'conj' and $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # haos
        elsif ($deprel eq 'haos') {
            $afun = 'Adv';
        }

        # determiner
        elsif ($pos eq 'adj' and $subpos eq 'det') {
            $afun = 'AuxA';
        }

        # default afun assignment
        # if ($afun eq "NR") {
            # print "Assigning Atr to " . $deprel . "\t POS: $pos ## $subpos" .  "\n";
            # $afun = 'Atr';
        # }

        $node->set_afun($afun);
    }
}

1;

=over

=item Treex::Block::HamleDT::EU::Harmonize


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
