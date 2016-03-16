package Treex::Block::HamleDT::ET::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'et::puudepank',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Estonian tree, transforms tree to adhere to PDT guidelines,
# converts Tiger functions to deprels.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $zone->get_atree();
    tiger2pdt($root);
    # Convert Estonian POS tags and features to Interset and PDT if possible.
    # Jan's tiger2pdt uses the original tags so we must not change $tag before structural and s-tag conversion is done.
    $self->convert_tags( $root );
    $self->attach_final_punctuation_to_root($root);
    return $root;
} # process_zone

#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    return $node->tag();
}

sub tiger2pdt {
    my $a_root = shift;
    for my $anode ($a_root->get_descendants) {
        set_deprel($anode, $anode->get_parent, $anode->wild->{function});
        convert_coordination($anode) if 'CJT' eq $anode->wild->{function};
    }
} # tiger2pdt

sub convert_coordination {
    my $node = shift;
    return if defined($node->{deprel}) && 'NR' ne $node->deprel;
    my $parent = $node->get_parent;
    if (grep $_ eq $parent->wild->{function}, qw/CO --/) {
        $parent->set_deprel('Pred');
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
                    $_->set_deprel($members[-1]->deprel) for @members;
           } else {
                    $coord->set_parent($members[-1]->get_parent);
                    $coord->set_deprel('Coord');
                    $_->set_parent($coord) for @members;
                    $_->set_is_member(1) for @members;
                    $_->set_deprel($members[-1]->deprel)
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
        my $deprel = $node->get_parent->deprel;
        $_->set_deprel($deprel) for $node, @siblings;
        $_->set_is_member(1) for $node, @siblings;
        $parent->set_deprel('Coord');
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

sub set_deprel {
    my ($achild, $ahead, $func) = @_;
    my $deprel;
    if(!defined($achild->{deprel}))
    {
        $achild->{deprel} = 'NR';
    }
    return if 'NR' ne $achild->{deprel};

    if (not $func) {
        if (',' eq $achild->{form}) {
            $deprel = 'AuxX';
        } else {
            $deprel = 'ExD';
        }

    } elsif ('X' eq $func) {
        $deprel = 'ExD';

    } elsif ('D' eq $func) {
        if ($ahead->tag =~ m{^(?:prp|pst)/}) {
            my @children = $ahead->get_children({ordered => 1});
            if (1 < @children) {
                $_->set_deprel('AuxZ') for @children;
            }
            $children[-1]->set_deprel($ahead->deprel);
            $ahead->set_deprel('AuxP');
            $ahead = $ahead->get_parent;
        }
        if ($ahead->tag =~ m{^(?:n|pro[np]|num)[-/]}) {
            $deprel = 'Atr';
            if ($ahead->tag =~ /^pron-dem/
                and $achild->tag =~ /^adv/) {
                $deprel = 'Adv';
            }
        } elsif ($ahead->tag =~ /^(?:v|ad[jv])/) {
            $deprel = 'Adv';
        } elsif (0 == index $ahead->tag, 'conj') {
            if ($achild->tag =~ /^adv/) {
                $deprel = 'AuxY';
            } else {
                my $member = (grep 'CJT' eq $_->wild->{function},
                              $ahead->get_children)[0];
                if ($member) {
                    set_deprel($achild, $member, 'D');
                } else {
                    $deprel = 'ExD';
                }
            }
        }

    } elsif ('A' eq $func) {
        # The subordinating conjunctions "kui" (when), "nagu" (as) and "et" (so that)
        # are sometimes attached as "A" but we do not want to label them "Adv".
        if($achild->tag =~ m/conj-s/)
        {
            $deprel = 'AuxC';
        }
        else
        {
            $deprel = 'Adv';
        }

    # not sure about this one (??)
    } elsif ('DA' eq $func) {
        $deprel = 'Adv';

    } elsif (grep $_ eq $func, qw/O DO/) {
        $deprel = 'Obj';

    } elsif ('S' eq $func) {
        $deprel = 'Sb';

    } elsif ('B' eq $func) {
        $deprel = 'AuxY';

    } elsif ('C' eq $func) {
        $deprel = 'Pnom';
        if (not $ahead->tag =~ m{^v[-/]}) {
            log_info("Pnom under nonverb\t" . $achild->get_address);
            $deprel = 'Atr';
        }

    } elsif (grep $_ eq $func,qw/FST EM QM EXC/) {
        $deprel = 'AuxK';
        $achild->set_parent($achild->get_root);

    } elsif ('SUB' eq $func) {
        $deprel = 'AuxC';
        convert_subordinator($achild);

    } elsif ($func =~ /^[AV]neg$/) {
        $deprel = 'Neg';

    } elsif (grep $_ eq $func, qw/Vmod Vaux Vph/) {
        $deprel = 'AuxV';
        log_warn("AuxV under nonverb\t" . $achild->get_address)
            unless $ahead->tag =~ m{^v[-/]};

    } elsif ($func =~ /^Vm(?:ain)?$/) {
        if ('AuxS' eq $ahead->deprel) {
            $deprel = 'Pred';
        } else {
            log_warn("Main verb not under root\t" . $achild->get_address);
            $deprel = 'AuxV';
        }

    } elsif ('P' eq $func) {
        if ('AuxS' eq $ahead->deprel) {
            $deprel = 'Pred';
        } else {
            $deprel = 'ExD';
            log_warn("P under non root\t", $achild->get_address);
        }

    } elsif (grep $_ eq $func, qw/CO D/
             and $ahead->tag && $ahead->tag =~ m{^(?:conj|punc|v[/-])}) {
        $deprel = 'AuxY';

    # repetition in spoken language
    } elsif (grep $_ eq $func, qw/UTT REP T/) {
        $deprel = 'ExD';

    # verbal particle (similar to preposition in English phrasal verbs).
    } elsif ('Vpart' eq $func) {
        $deprel = 'AuxT';
        log_warn("Vpart under non-verb\t" . $achild->get_address)
            unless $ahead->tag =~ /^v/;

    } elsif ('H' eq $func
             and not $achild->get_siblings) {
        $deprel = 'ExD';

    } elsif (grep $_ eq $func, qw/-- PNC/
             and $achild->tag =~ m{^punc/(?:Com|--)$}) {
        if (',' eq $achild->form) {
            $deprel = 'AuxX';
        } else {
            $deprel = 'AuxG';
        }

    } elsif ('H' eq $func) {
        $deprel = 'Atr';
    }
    elsif ('ORPHAN' eq $func)
    {
        if ($achild->form() eq ',')
        {
            $deprel = 'AuxX';
        }
        elsif ($achild->tag() eq 'adv/--')
        {
            $deprel = 'Adv';
        }
    }

    $achild->set_deprel($deprel) if $deprel;
} # set_deprel



#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::HamleDT::ET::Harmonize

Takes the Estonian Treebank converted from its native Tiger-like format to
dependencies. Converts the dependencies to the style of HamleDT (Prague).

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
