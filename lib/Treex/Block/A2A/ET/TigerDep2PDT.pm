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
    }
} # tiger2pdt




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
    if ('D' eq $func and $ahead->tag =~ m{^(?:n|prop)/}) {
        $afun = 'Atr';
    } elsif ('A' eq $func) {
        $afun = 'Adv';
    } elsif ('O' eq $func) {
        $afun = 'Obj';
    } elsif ('S' eq $func) {
        $afun = 'Sb';
    } elsif ('FST' eq $func) {
        $afun = 'AuxK';
    } elsif ('SUB' eq $func) {
        $afun = 'AuxC';
    } elsif ('Aneg' eq $func) {
        $afun = 'AuxZ';
    } elsif ('H' eq $func
             and not $achild->get_siblings) {
        $afun = 'ExD';
    } elsif ('--' eq $func
             and 'punc/--' eq $achild->tag 
             and ',' eq $achild->form) {
        $afun = 'AuxX';
    }


    $achild->set_afun($afun) if $afun;
} # set_afun



#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::A2A::FI::CoNLL2PDTStyle

Converts Turku Dependency Treebank trees from CoNLL to the style of
the Prague Dependency Treebank.
Morphological tags will be decoded into Interset and to the
15-character positional tags of PDT.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
