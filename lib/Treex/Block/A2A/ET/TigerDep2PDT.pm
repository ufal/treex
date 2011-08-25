package Treex::Block::A2A::ET::TigerDep2PDT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

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
    return $a_root;
} # process_zone

sub tiger2pdt {
    my $a_root = shift;
    for my $anode ($a_root->get_descendants) {
        set_afun($anode, $anode->get_parent, $anode->wild->{function});
        convert_coordination($anode) if 'CJT' eq $anode->wild->{function};
    }
} # tiger2pdt

sub convert_coordination {
    my $node = shift;
    return if 'NR' ne $node->afun;
    my $parent = $node->parent;
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
                    log_warn("No $coord\t" . $node->get_address);
                } else {
                    $coord->set_parent($members[-1]->parent);
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
        $_->set_afun($node->parent->afun) for $node, @siblings;
        $_->set_is_member(1) for $node, @siblings;
        $parent->set_afun('Coord');
    }
} # convert_coordination

#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self  = shift;
    my $zone0 = shift;
    return $zone0->copy('orig');
}

sub set_afun {
    my ($achild, $ahead, $func) = @_;
    my $afun;
    return if 'NR' ne $achild->{afun};

    if (not $func) {
        if (',' eq $achild->{form}) {
            $afun = 'AuxX';
        } else {
            $afun = 'ExD';
        }

    } elsif ('D' eq $func and $ahead->tag =~ m{^(?:n|prop|num)/}) {
        $afun = 'Atr';

    } elsif ('A' eq $func) {
        $afun = 'Adv';

    } elsif (grep $_ eq $func, qw/O DO/) {
        $afun = 'Obj';

    } elsif ('S' eq $func) {
        $afun = 'Sb';

    } elsif ('B' eq $func) {
        $afun = 'AuxY';

    } elsif ('C' eq $func) {
        $afun = 'Pnom';
        log_info("Pnom under nonverb\t" . $achild->get_address)
            unless $ahead->tag =~ m{^v[-/]};

    } elsif (grep $_ eq $func,qw/FST EM QM/) {
        $afun = 'AuxK';
        $achild->set_parent($achild->get_root);

    } elsif ('SUB' eq $func) {
        $afun = 'AuxC';

    } elsif ('Aneg' eq $func) {
        $afun = 'AuxZ';

    } elsif ('D' eq $func
             and $ahead->tag =~ m{^(?:adv|adj)}) {
        $afun = 'Adv';

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

    } elsif ('D' eq $func
             and $ahead->tag =~ m{^(?:prp|pst)/}) {
        my @children = $ahead->get_children({ordered => 1});
        warn "@children";
        if (1 < @children) {
            $_->set_afun('AuxZ') for @children;
        }
        $children[-1]->set_afun($ahead->afun);
        $ahead->set_afun('AuxP');

    } elsif ('P' eq $func) {
        if ('AuxS' eq $ahead->afun) {
            $afun = 'Pred';
        } else {
            $afun = 'ExD';
            log_warn("P under non root\t", $achild->get_address);
        }

    } elsif (grep $_ eq $func, qw/CO D/
             and $ahead->tag =~ m{^(?:conj|punc|v[/-])}) {
        $afun = 'AuxY';

    # verbal particle (similar to preposition in English phrasal
    # verbs). AuxR used because there are no phrasal verbs in PDT and
    # no reflexive objects in Estonian.
    } elsif ('Vpart' eq $func) {
        $afun = 'AuxR';
        log_warn("Vpart under non-verb\t" . $achild->get_address)
            unless $ahead->tag =~ /^v/;

    } elsif ('H' eq $func
             and not $achild->get_siblings) {
        $afun = 'ExD';

    } elsif ('--' eq $func
             and 'punc/--' eq $achild->tag) {
        if (',' eq $achild->form) {
            $afun = 'AuxX';
        } else {
            $afun = 'AuxG';
        }
    }

    $achild->set_afun($afun) if $afun;
} # set_afun



#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::A2A::ET::TigerDep2PDT

Converts Estonian Tiger-like Treebank converted to dependency style to
the style of the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
