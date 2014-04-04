package Treex::Block::HamleDT::ET::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'et::puudepank',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Estonian tree, transforms tree to adhere to PDT guidelines,
# converts Tiger functions to afuns.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;

    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    my $a_root = $zone->get_atree();
    tiger2pdt($a_root);
    # Convert Estonian POS tags and features to Interset and PDT if possible.
    # Jan's tiger2pdt uses the original tags so we must not change $tag before structural and s-tag conversion is done.
    $self->convert_tags( $a_root, 'puudepank' );
    return $a_root;
} # process_zone

#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    my $tagset = shift;    # optional, see below
    foreach my $node ( $root->get_descendants() )
    {
        $self->convert_tag( $node, $tagset );
    }
}

#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from the original tagset into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self   = shift;
    my $node   = shift;
    my $tagset = shift;
    my $driver = $node->get_zone()->language() . '::' . $tagset;
    # Current tag is probably just a copy of the original tag.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $tag = $node->tag();
    my $f = tagset::common::decode($driver, $tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
}

sub tiger2pdt {
    my $a_root = shift;
    for my $anode ($a_root->get_descendants) {
        # We also need CoNLL-like attributes to run the parsers same way as for other languages.
        my $tag = $anode->tag();
        if($tag)
        {
            my @tagparts = split(/,/, $tag);
            my $pos = shift(@tagparts);
            my ($cpos, $fpos);
            if($pos =~ m-^(.+)/(.+)$-)
            {
                $cpos = $1;
                $fpos = $2;
            }
            else
            {
                $cpos = $pos;
                $fpos = '_';
            }
            $anode->set_conll_cpos($cpos);
            $anode->set_conll_pos($fpos);
            $anode->set_conll_feat(join('|', @tagparts));
        }
        set_afun($anode, $anode->get_parent, $anode->wild->{function});
        convert_coordination($anode) if 'CJT' eq $anode->wild->{function};
    }
} # tiger2pdt

sub convert_coordination {
    my $node = shift;
    return if defined($node->{afun}) && 'NR' ne $node->afun;
    my $parent = $node->get_parent;
    if (grep $_ eq $parent->wild->{function}, qw/CO --/) {
        $parent->set_afun('Pred');
        log_warn("Setting Pred for CO\t" . $parent->get_address);
    }

    if ($parent->tag !~ /^(?:conj|punc)/) {
        if(my $coord_list = $node->get_root->wild->{coord}) {
            for my $coord_nodes (@$coord_list) {
                next unless grep $_ eq $node->id, @$coord_nodes;
                my @members = grep {
                    my $id = $_->id;
                    grep $_ eq $id, @$coord_nodes
                } $node->get_root->get_descendants({ordered => 1});
                my $coord = $members[-2]->get_descendants({last_only => 1});
                if ($coord->tag !~ /^punc/) {
                    log_warn("No coord\t" . $node->get_address);
                    my $higher = $members[-1]->get_parent;
                    $_->set_parent($higher) for @members;
                    $_->set_afun($members[-1]->afun) for @members;
           } else {
                    $coord->set_parent($members[-1]->get_parent);
                    $coord->set_afun('Coord');
                    $_->set_parent($coord) for @members;
                    $_->set_is_member(1) for @members;
                    $_->set_afun($members[-1]->afun)
                        for @members[0 .. $#members-1];
                }
            }
        } else {
            log_warn(join "\t",
                 "Invalid Coord",
                 $parent->tag,
                 $parent->get_address);
                return;
        }
    } else {
        my @siblings = grep 'CJT' eq $_->wild->{function}, $node->get_siblings;
        my $afun = $node->get_parent->afun;
        $_->set_afun($afun) for $node, @siblings;
        $_->set_is_member(1) for $node, @siblings;
        $parent->set_afun('Coord');
    }
} # convert_coordination


## Rehang AuxC to PDT style (head of the clause)
sub convert_subordinator {
    my $auxc   = shift;
    my $child  = $auxc->parent;
    my $parent = $child->parent;
    my ($punc) = grep $_->ord == $auxc->ord - 1,
                $auxc->get_root->get_descendants;
    if ($punc and not $punc->tag =~ /punc/) {
        undef $punc;
    }
    $auxc->set_parent($parent);
    $child->set_parent($auxc);
    $punc->set_parent($auxc) if $punc;
    if ($child->is_member) {
        $child->set_is_member(0);
        $auxc->set_is_member(1);
    }
} # convert_subordinator

#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self  = shift;
    my $zone0 = shift;
    my $zone1 = $zone0->copy('orig');
    $zone0->remove_tree('p');
    return $zone1;
}

sub set_afun {
    my ($achild, $ahead, $func) = @_;
    my $afun;
    if(!defined($achild->{afun}))
    {
        $achild->{afun} = 'NR';
    }
    return if 'NR' ne $achild->{afun};

    if (not $func) {
        if (',' eq $achild->{form}) {
            $afun = 'AuxX';
        } else {
            $afun = 'ExD';
        }

    } elsif ('X' eq $func) {
        $afun = 'ExD';

    } elsif ('D' eq $func) {
        if ($ahead->tag =~ m{^(?:prp|pst)/}) {
            my @children = $ahead->get_children({ordered => 1});
            if (1 < @children) {
                $_->set_afun('AuxZ') for @children;
            }
            $children[-1]->set_afun($ahead->afun);
            $ahead->set_afun('AuxP');
            $ahead = $ahead->get_parent;
        }
        if ($ahead->tag =~ m{^(?:n|pro[np]|num)[-/]}) {
            $afun = 'Atr';
            if ($ahead->tag =~ /^pron-dem/
                and $achild->tag =~ /^adv/) {
                $afun = 'Adv';
            }
        } elsif ($ahead->tag =~ /^(?:v|ad[jv])/) {
            $afun = 'Adv';
        } elsif (0 == index $ahead->tag, 'conj') {
            if ($achild->tag =~ /^adv/) {
                $afun = 'AuxY';
            } else {
                my $member = (grep 'CJT' eq $_->wild->{function},
                              $ahead->get_children)[0];
                if ($member) {
                    set_afun($achild, $member, 'D');
                } else {
                    $afun = 'ExD';
                }
            }
        }

    } elsif ('A' eq $func) {
        $afun = 'Adv';

    # not sure about this one (??)
    } elsif ('DA' eq $func) {
        $afun = 'Adv';

    } elsif (grep $_ eq $func, qw/O DO/) {
        $afun = 'Obj';

    } elsif ('S' eq $func) {
        $afun = 'Sb';

    } elsif ('B' eq $func) {
        $afun = 'AuxY';

    } elsif ('C' eq $func) {
        $afun = 'Pnom';
        if (not $ahead->tag =~ m{^v[-/]}) {
            log_info("Pnom under nonverb\t" . $achild->get_address);
            $afun = 'Atr';
        }

    } elsif (grep $_ eq $func,qw/FST EM QM EXC/) {
        $afun = 'AuxK';
        $achild->set_parent($achild->get_root);

    } elsif ('SUB' eq $func) {
        $afun = 'AuxC';
        convert_subordinator($achild);

    } elsif ($func =~ /^[AV]neg$/) {
        $afun = 'AuxZ';

    } elsif (grep $_ eq $func, qw/Vmod Vaux Vph/) {
        $afun = 'AuxV';
        log_warn("AuxV under nonverb\t" . $achild->get_address)
            unless $ahead->tag =~ m{^v[-/]};

    } elsif ($func =~ /^Vm(?:ain)?$/) {
        if ('AuxS' eq $ahead->afun) {
            $afun = 'Pred';
        } else {
            log_warn("Main verb not under root\t" . $achild->get_address);
            $afun = 'AuxV';
        }

    } elsif ('P' eq $func) {
        if ('AuxS' eq $ahead->afun) {
            $afun = 'Pred';
        } else {
            $afun = 'ExD';
            log_warn("P under non root\t", $achild->get_address);
        }

    } elsif (grep $_ eq $func, qw/CO D/
             and $ahead->tag && $ahead->tag =~ m{^(?:conj|punc|v[/-])}) {
        $afun = 'AuxY';

    # repetition in spoken language
    } elsif (grep $_ eq $func, qw/UTT REP T/) {
        $afun = 'ExD';

    # verbal particle (similar to preposition in English phrasal
    # verbs). AuxV was used.
    } elsif ('Vpart' eq $func) {
        $afun = 'AuxV';
        log_warn("Vpart under non-verb\t" . $achild->get_address)
            unless $ahead->tag =~ /^v/;

    } elsif ('H' eq $func
             and not $achild->get_siblings) {
        $afun = 'ExD';

    } elsif (grep $_ eq $func, qw/-- PNC/
             and $achild->tag =~ m{^punc/(?:Com|--)$}) {
        if (',' eq $achild->form) {
            $afun = 'AuxX';
        } else {
            $afun = 'AuxG';
        }

    } elsif ('H' eq $func) {
        $afun = 'Atr';
    }



    $achild->set_afun($afun) if $afun;
} # set_afun



#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::HamleDT::ET::Harmonize

Converts Estonian Tiger-like Treebank converted to dependency style to
the style of the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
