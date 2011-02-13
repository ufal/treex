package TCzechT_to_TCzechA::Impose_pron_z_agr;

use utf8;
use strict;
use warnings;

use base qw(TectoMT::Block);
use List::Util qw(first);

# Ideálně by tyto případy (každý z mužů, každá z žen) měly být anotovány
# jako bridging anaphora už ve zdrojovém jazyce.
# Zatím je budu rozpoznávat zde.

my $pron_regex = qr/^(jeden|každý|žádný|oba|všechen|(ně|lec)který|(jak|kter)ýkoliv?|libovolný)$/;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');
    foreach my $t_pron ( grep { $_->get_attr('t_lemma') =~ $pron_regex } $t_root->get_descendants() ) {
        my $t_zkoho = first { $_->get_attr('formeme') eq 'n:z+2' } $t_pron->get_children();
        if ($t_zkoho) {
            my $a_pron  = $t_pron->get_lex_anode();
            my $a_zkoho = $t_zkoho->get_lex_anode();
            $a_pron->set_attr( 'morphcat/gender', $a_zkoho->get_attr('morphcat/gender') );
        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Impose_pron_z_agr

For pronouns I<každý, žádný, oba, všichni, etc.>, copy the value of gender 
from their children with formeme C<n:z+2> (e.g. I<každý z mužů, každá z žen>).

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
