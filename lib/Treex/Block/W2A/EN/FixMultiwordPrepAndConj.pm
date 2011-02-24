package Treex::Block::W2A::EN::FixMultiwordPrepAndConj;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

# viceslovne spojky nejcetnejsi v BNC (rucne profiltrovano, neco pridano):
my $MULTI_CONJ = qr/^(as well as|so that|as if|even if|even though|as though|rather than|as soon as|as long as|even when|in case of|in case|except that|given that|provided that|such that|as far as|in order to)$/;

# viceslovne predlozky nejcetnejsi v BNC (rucne profiltrovano):
my $MULTI_PREP = qr/^(more than|less than|out of|such as|because of|rather than|according to|away from|up to|on to|due to|as to|instead of|apart from|in front of|subject to|along with|prior to|next to|in spite of|ahead of|in accordance with|in response to|except for|with regard to|by means of|as regards|as for)$/;

sub process_atree {
    my ( $self, $a_root ) = @_;
    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    my $starts_at;
    for ( $starts_at = 0; $starts_at <= $#anodes - 3; $starts_at++ ) {

        LENGTH_LOOP:
        foreach my $length ( 3, 2 ) {    # two- and three-word only so far
            my $string = join ' ', map { lc( $anodes[$_]->form ) } ( $starts_at .. $starts_at + $length - 1 );

            # Sometimes the matching string isn't a multiword preposition,
            # but RP (phrase verb particle) + common onword preposition:
            # "heat up to toxic levels" "He moved on to do his own work."
            last LENGTH_LOOP if $anodes[$starts_at]->tag eq 'RP';
            my ($conj) = $string =~ $MULTI_CONJ;
            my ($prep) = $string =~ $MULTI_PREP;
            next LENGTH_LOOP if !$conj && !$prep;
            $conj ||= '';
            my $first = $anodes[$starts_at];
            my @others = map { $anodes[$_] } ( $starts_at + 1 .. $starts_at + $length - 1 );

            #  nejdriv se prvni clen prevesi tam, kde byl z nich nejvyssi
            my ($highest) = sort { $a->get_depth <=> $b->get_depth } ( $first, @others );
            if ( $highest ne $first ) {
                $first->set_parent( $highest->get_parent );
            }

            # a pak se ostatni casti viceslovne spojky prevesi pod prvni
            foreach my $other (@others) {
                $other->set_afun( $conj ? 'AuxC' : 'AuxP' );
                $other->set_parent($first);
            }

            # a jejich deti se prevesi taky rovnou pod prvni
            foreach my $other (@others) {
                foreach my $child ( $other->get_children() ) {
                    $child->set_parent($first);
                }
            }

            # prevesit predlozky zavisle na predlozce, ktere ale nejsou soucasti viceslovne; mozna by to chtelo povysit
            my @to_rehang = grep {
                $_->tag eq 'IN' && ( $_->afun || '' ) !~ 'Aux[CP]'
            } $highest->get_children();
            foreach my $rehang (@to_rehang) {
                $rehang->set_parent( ( $highest->get_eparents() )[0] );
            }

            # Fill afun
            my $afun = $conj ? 'AuxC' : 'AuxP';
            if ( $conj eq 'as well as' ) {

                # TODO: better recognition of memebers of this coord
                my @members = grep { $_->tag !~ /^(,|RB|IN)/ } $first->get_children();
                if (@members) {
                    $afun = 'Coord';
                    foreach my $member (@members) {
                        $member->set_is_member(1);
                    }
                }
            }
            $first->set_afun($afun);

            # aby se ty viceslovne predlozky nahodou neprekryly
            $starts_at += $length;
            last LENGTH_LOOP;
        }
    }
    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::FixMultiwordPrepAndConj

Normalizes the way how multiword prepositions (such as
'because of') and subordinating conjunctions (such as
'provided that', 'as soon as') are treated: first token
becomes the head and the other ones become its immediate
children, all marked with AuxC afun. Illusory overlapping
of multiword conjunctions (such as in 'as well as if') is
prevented.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
