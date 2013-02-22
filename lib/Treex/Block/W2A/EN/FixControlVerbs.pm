package Treex::Block::W2A::EN::FixControlVerbs;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN;

sub process_atree {
    my ( $self, $a_root ) = @_;

  ANODE:
    foreach my $false_subject (grep {$_->afun eq 'Sb' and $_->tag !~ /^W/} $a_root->get_descendants) {

        my $parent = $false_subject->get_parent or next ANODE;
        my $grandpa = $parent->get_parent or next ANODE;
        my $right_brother = $false_subject->get_siblings({following_only=>1, first_only=>1}) or next ANODE;

        if ($parent->tag eq 'VB'
                and not $grandpa->is_root
                    and $grandpa->precedes($false_subject)
                        and $grandpa->tag =~ /^V/
                            and $right_brother->form eq 'to'
                    ) {

            $false_subject->set_parent($grandpa);
            $false_subject->set_afun('Obj');
#            print $grandpa->lemma."\t".$false_subject->get_address."\n";
        }

    }

    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::FixControlVerbs

Changes structures with verbs of control, such as in 'She allowed him to come'. If 'him' was placed below 'come' and marked as 'Sb',
then it is moved below 'allow' and marked as 'Obj'. Needed roughly once per 100 sentences. Most frequent verbs that needed this change: allow, expect, help.

See also control vs. raising at
http://en.wikipedia.org/wiki/Control_%28linguistics%29#Control_vs._raising

=back

=cut

# Copyright 2013 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
