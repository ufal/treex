package SEnglishT_to_TCzechT::Move_adjectives_before_nouns;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {

    my ( $self, $bundle ) = @_;

    foreach my $tnode ($bundle->get_tree('TCzechT')->get_descendants) {

	if (($tnode->get_attr('formeme')||"") =~ /(adj:attr|poss)/
	    and $tnode->get_parent->precedes($tnode) and not $tnode->get_children
	    and not $tnode->get_attr('is_member')
	    and not $tnode->get_attr('is_parenthesis')
	    and (($tnode->get_attr('mlayer_pos')||"") eq 'A' or ($tnode->get_attr('t_lemma') eq '#PersPron'))
	    and ($tnode->get_parent->get_attr('mlayer_pos')||"") eq 'N'
	    ) {

	    my $leftmost = $tnode->get_parent->get_descendants({add_self=>1, first_only=>1});

	    if (not grep {$_->precedes($tnode)
			      and $leftmost->precedes($_)
			      and (
                                  # forbidding punctuation marks (e.g. quotes) in between
				  $_->get_attr('t_lemma') =~ /^\p{IsP}$/
                                      # and also any verb clauses
                                      or ($_->get_attr('formeme')||"") =~ /^v/
			      )
		} $bundle->get_tree('TCzechT')->get_descendants) {

#		print $tnode->get_attr('t_lemma')."\t(".$leftmost->get_attr('t_lemma').")\t".$tnode->get_parent->get_attr('t_lemma')."\t"
#		    .$bundle->get_attr('czech_target_sentence')."\n";
		$tnode->shift_before_node($leftmost);
	    }
	}
    }

}

1;

=over

=item SEnglishT_to_TCzechT::Move_adjectives_before_nouns

Adjectives (and other adjectivals) that follow their governing nouns
are moved in front of them (five bottles more -> dalsich pet lahvi,
supermarket tested -> testovany supermarket, lists of them -> jejich seznamy).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
