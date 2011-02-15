package Treex::Block::T2T::EN2CS::MoveAdjsBeforeNouns;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';


sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ($troot->get_descendants) {

	if (($tnode->formeme||"") =~ /(adj:attr|poss)/
	    and $tnode->get_parent->precedes($tnode) and not $tnode->get_children
	    and not $tnode->is_member
	    and not $tnode->get_attr('is_parenthesis')
	    and (($tnode->get_attr('mlayer_pos')||"") eq 'A' or ($tnode->t_lemma eq '#PersPron'))
	    and ($tnode->get_parent->get_attr('mlayer_pos')||"") eq 'N'
	    ) {

	    my $leftmost = $tnode->get_parent->get_descendants({add_self=>1, first_only=>1});

	    if (not grep {$_->precedes($tnode)
			      and $leftmost->precedes($_)
			      and (
                                  # forbidding punctuation marks (e.g. quotes) in between
				  $_->t_lemma =~ /^\p{IsP}$/
                                      # and also any verb clauses
                                      or ($_->formeme||"") =~ /^v/
			      )
		} $troot->get_descendants) {

#		print $tnode->t_lemma."\t(".$leftmost->t_lemma.")\t".$tnode->get_parent->t_lemma."\t"
#		    .$bundle->get_attr('czech_target_sentence')."\n";
		$tnode->shift_before_node($leftmost);
	    }
	}
    }

}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveAdjsBeforeNouns

Adjectives (and other adjectivals) that follow their governing nouns
are moved in front of them (five bottles more -> dalsich pet lahvi,
supermarket tested -> testovany supermarket, lists of them -> jejich seznamy).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
