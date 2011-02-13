package TCzechT_to_TCzechA::Add_apposition_punct;

use 5.008;
use utf8;
use strict;
use warnings;

use Lexicon::Czech;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $troot = $bundle->get_tree('TCzechT');

    foreach my $tnode ($troot->get_descendants) {
        if ($tnode->get_attr('formeme') eq 'n:attr'
	    and $tnode->get_parent->precedes($tnode)
	    and $tnode->get_parent->get_attr('formeme')=~/^n/
	    and $tnode->get_attr('gram/sempos') eq "n.denot" # not numerals etc.
	    and Lexicon::Czech::is_personal_role($tnode->get_attr('t_lemma'))
	    ) {

            my $anode = $tnode->get_lex_anode;

            # first comma separating the two apposited members
            my $left_comma = add_comma_node($anode->get_parent);
            $left_comma->shift_before_subtree($anode);

            # another comma added after the second apposited member only
            # if there is no other punctuation around
            if (defined $anode) {

                my $rightmost_descendant = $anode->get_descendants({last_only=>1, add_self=>1});
                my $after_rightmost = $rightmost_descendant->get_next_node;

                if (defined $after_rightmost) { # not the end of the sentence
                    if (!grep {$_->get_attr('morphcat/pos') eq 'Z'} ($rightmost_descendant, $after_rightmost)) {
                        my $right_comma = add_comma_node($anode->get_parent);
                        $right_comma->shift_after_subtree($anode);
                    }
                }
            }

        }
    }

    return;
}

sub add_comma_node {
    my ($parent) = @_;
    return $parent->create_child(
        {   attributes => {
                'm/form'       => ',',
                'm/lemma'      => ',',
                'afun'         => 'AuxX',
                'morphcat/pos' => 'Z',
                'clause_number'=> 0,
            }
        }
    );
}

1;

=over

=item TCzechT_to_TCzechA::Add_apposition_punct

Add commas in apposition constructions such as
'John, my best friend, ...'


=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
