package Treex::Block::T2A::CS::AddClausalExpletivePronouns;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




my %verb2expletive;

sub process_atree {
    my ( $self, $a_root ) = @_;

    foreach my $subconj_ze ( grep {($_->form||'') eq 'že'} $a_root->get_descendants() ) {
        my $parent = $subconj_ze->get_parent;
        my $expletive = $verb2expletive{$parent->lemma};
        if ($expletive and $parent->precedes($subconj_ze)) {

            foreach my $form (split /_/,$expletive) {
                my $new_node = $parent->create_child({attributes=>{
                    'lemma' => $form,
                    'form'  => $form,
                    'morphcat/pos' => '!',
                    'clause_number' => 0,
                }});
                $new_node->shift_before_subtree($subconj_ze);
                $subconj_ze->set_parent($new_node);
                $parent = $new_node;
            }
#            print "Added expletive '$expletive' into\t".$bundle->get_attr('czech_target_sentence')."\n";
        }
    }
    return;
}

# clausal expletives trained from PDT 2.0:
%verb2expletive = (
#    qw(vysvětlit) => qw(tím),
    qw(upozorňovat) => qw(na_to),
    qw(zdůvodňovat) => qw(tím),
    qw(uvažovat) => qw(o_tom),
    qw(pochybovat) => qw(o_tom),
    qw(poukazovat) => qw(na_to),
    qw(spočívat) => qw(v_tom),
    qw(nasvědčovat) => qw(tomu),
    qw(vést) => qw(k_tomu),
    qw(argumentovat) => qw(tím),
    qw(souhlasit) => qw(s_tím),
    qw(rozhodnout) => qw(o_tom),
    qw(mluvit) => qw(o_tom),
    qw(shodnout) => qw(na_tom),
    qw(zdůvodnit) => qw(tím),
    qw(dojít) => qw(k_tomu),
#    qw(věřit) => qw(tomu),
#    qw(tajit) => qw(tím),
    qw(přesvědčit) => qw(o_tom),
    qw(vycházet) => qw(z_toho),
    qw(trvat) => qw(na_tom),
    qw(počítat) => qw(s_tím),
    qw(shodovat) => qw(v_tom),
    qw(dopustit) => qw(tím),
#    qw(jít) => qw(o_to),
    qw(hovořit) => qw(o_tom),
#    qw(moci) => qw(to),
    qw(svědčit) => qw(o_tom),
);



1;

=over

=item Treex::Block::T2A::CS::AddClausalExpletivePronouns

Adding expletive pronouns in front of ze-clauses,
if required by valency of the verb on which the clause
is dependent ( 'trval, ze...' --> 'trval na tom, ze...' ).
The list of verbs below which ze-clauses are more probable with
expletive pronoun than without them was trained from PDT 2.0.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
