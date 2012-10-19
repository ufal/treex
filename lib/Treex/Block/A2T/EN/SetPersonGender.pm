package Treex::Block::A2T::EN::SetPersonGender;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    foreach my $t_node ( $zone->get_ttree->get_descendants() ) {
        my $gender = get_person_gender( $t_node );
        if ( $gender ) {
            $t_node->set_gram_gender($gender);
            print $t_node->t_lemma . ":\t";
            foreach my $echild ( $t_node->get_echildren ) {
                if ( ($echild->formeme || "") eq "n:attr" and not $echild->gram_gender ) {
                    $echild->set_gram_gender($gender);
                    print $echild->t_lemma . "\t";
                }
            }
            my $parent = $t_node->get_parent;
#             my $eparent = $t_node->get_eparents[0];
            if ( ($t_node->formeme || "") eq "n:attr" ) {
                if ( not $parent->gram_gender ) {
                    $parent->set_gram_gender($gender);
                    print $parent->t_lemma . "\t";
                    foreach my $echild ( $parent->get_echildren ) {
                        if ( ($echild->formeme || "") eq "n:attr" and not $echild->gram_gender ) {
                            $echild->set_gram_gender($gender);
                            print $echild->t_lemma . "\t";
                        }
                    }
                }
            }
            print "\n";
        }
    }
    return;
}

# sub process_tnode {
#     my ( $self, $t_node ) = @_;
#     return 1 if $t_node->gram_gender;
#     if ( my $gender = gender_of_tnode_person($t_node) ) {
#         $t_node->set_gram_gender($gender);
#     }
#     return 1;
# }

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

# Copyright 2010 Martin Popel, Nguy Giang Linh
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
