package Treex::Block::A2T::EN::SetPersonGender;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my %person_gender;
    my @ttree_descendants = $zone->get_ttree->get_descendants();
    foreach my $t_node ( @ttree_descendants ) {
        my $gender = get_person_gender( $t_node );
        if ( $gender ) {
            $t_node->set_gram_gender($gender);
            $person_gender{$t_node->t_lemma} = $gender;
#             print $t_node->t_lemma . ":\t";
            foreach my $echild ( $t_node->get_echildren ) {
                if ( ($echild->formeme || "") eq "n:attr" and not $echild->gram_gender ) {
                    $echild->set_gram_gender($gender);
#                     $person_gender{$echild->t_lemma} = $gender;
#                     print $echild->t_lemma . "\t";
                }
            }
            my $parent = $t_node->get_parent;
# #             my $eparent = $t_node->get_eparents[0];
            if ( ($t_node->formeme || "") eq "n:attr" ) {
                if ( not $parent->gram_gender ) {
                    $parent->set_gram_gender($gender);
#                     $person_gender{$parent->t_lemma} = $gender;
#                     print $parent->t_lemma . "\t";
                    foreach my $echild ( $parent->get_echildren ) {
                        if ( ($echild->formeme || "") eq "n:attr" and not $echild->gram_gender ) {
                            $echild->set_gram_gender($gender);
#                             $person_gender{$echild->t_lemma} = $gender;
#                             print $echild->t_lemma . "\t";
                        }
                    }
                }
            }
#             print "\n";
        }
    }
    my @persons = keys %person_gender;
    foreach my $t_node ( @ttree_descendants ) {
        if ( grep { $_ eq $t_node->t_lemma } @persons
            and not $t_node->gram_gender ) {
            $t_node->set_gram_gender($person_gender{$t_node->t_lemma});
            print $t_node->get_zone->sentence . "\n";
            print $t_node->t_lemma . "\t" . $t_node->gram_gender . "\n";
        }
    }
    return;
}

sub get_person_gender {
    my ($t_node) = @_;
    my $n_node = $t_node->get_n_node() or return;
    while (1) {
        my $type = $n_node->get_attr('ne_type');
        return 'fem'  if $type eq 'PF';
        return 'anim' if $type eq 'PM';
        return        if $type !~ /^p/;
        $n_node = $n_node->get_parent();
        return if $n_node->is_root();
    }
}

1;

=over

=item Treex::Block::A2T::EN::SetPersonGender

Treex::Block::A2T::EN::SetGenderOfPerson
The C<gram/gender> attribute is filled according to the named entity tree.
NE nodes with female names have C<ne_type> = C<PF>, male ones have C<PM>.

Treex::Block::A2T::EN::SetPersonGender
Tries to fill gender (C<gram/gender> attribute) of all nodes in the document referring to persons whois gender was recognized by their names according to the NE tree.

=back

=cut

# Copyright 2010-2012 Martin Popel, Nguy Giang Linh
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
