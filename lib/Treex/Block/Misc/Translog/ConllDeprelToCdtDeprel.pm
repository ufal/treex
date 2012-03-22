package Treex::Block::Misc::Translog::ConllDeprelToCdtDeprel;


use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# conll deprel frequency list extracted from a sample
# of English texts parsed by the MST parser
my %en_conll_deprel_to_cdt_deprel = (
    q(NMOD) => q(attr), # 3453
    q(PMOD) => q(mod), # 1580
    q(OBJ)  => q(qobj), # 1252
    q(SBJ)  => q(subj), # 832
    q(P)    => q(pnct), # 828
    q(ADV)  => q(mod), # 687
    q(ROOT) => q(), # 536
    q(VMOD) => q(mod), # 502
    q(VC)   => q(mod), # 455
    q(COORD)=> q(coord), # 436
    q(AMOD) => q(mod), # 212
    q(PRT)  => q(), # 47
    q(LGS)  => q(qobj), # 23
    q(CC)   => q(coord), # 22
#    q(Pred) => q(), # 5
);



sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $node ($bundle->get_zone('en')->get_atree->get_descendants) {
        my $new_deprel = $en_conll_deprel_to_cdt_deprel{$node->conll_deprel} || '???';
        print "new: $new_deprel\n";

    }
    return;
}

#    3281 subj
#    1881 mod
#    1284 coord
#     958 attr
#     571 pnct
#     457 namef
#     238 quant
#     194 time
#     176 qobj
#     132 nobj
#     116 expl
#      60 title
#      51 cond
#      47 add
#      44 neg
#      40 namel
#      40 man
#      34 dobj
#      33 contr
#      32 cause
#      31 tobj
#      26 focal
#      26 eval
#      23 preds
#      23 loc
#      18 xtop
#      18 prg
#      17 other
#      16 numm
#      16 epi
#      12 discmark
#      12 cons
#      10 name
#      10 conc
#      10 aobj
#       9 pobj
#       8 scene
#       7 modp
#       7 exem
#       6 lobj
#       5 err
#       4 inst
#       3 voc
#       2 vobj
#       2 rep
#       2 iter
#       2 goal
#       2 correl
#       1 possd
#       1 mods
#       1 conj
#       1 att



1;


=over

=item Treex::Block::Misc::Translog::ConllDeprelToCdtDeprel

Substitutes deprel values (dependency lables) delivered by MST parser
by their CDT counterparts.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
