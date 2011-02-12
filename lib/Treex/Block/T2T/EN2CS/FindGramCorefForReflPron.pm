package Treex::Block::T2T::EN2CS::FindGramCorefForReflPron;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('TCzechT');

        foreach my $perspron (
            grep {
                $_->t_lemma eq "#PersPron" and $_->formeme !~ /1/
            } $t_root->get_descendants
            )
        {

            #      print STDERR "Success1\n";

            my $clause_head;
            my $parent = $perspron->get_parent;
            climb: while ( not( $parent->is_root ) ) {    # climbing up to the nearest clause head
                if ( $parent->is_clause_head ) {
                    $clause_head = $parent;
                    last climb;
                }
                $parent = $parent->get_parent
            }

            if ($clause_head) {

                #	print STDERR "  Success2\n";
                my ($subject) = grep { ( $_->formeme || "" ) =~ /1/ } $clause_head->get_children;    # !!! s efektivnimi to bude tezsi
                if ($subject) {

                    #	  print STDERR "    Success3\n";
                    my $antec_number = $subject->get_attr('gram/number');
                    my $pron_number  = $perspron->get_attr('gram/number');
                    my $antec_gender = $subject->get_attr('gram/gender');
                    my $pron_gender  = $perspron->get_attr('gram/gender');

                    #	  print "Pron: $pron_number $pron_gender    Antec: $antec_number $antec_gender\n";

                    if ((   not defined $antec_gender
                            or not defined $pron_gender
                            or $pron_gender eq $antec_gender
                            or ( $pron_gender =~ /inan|anim/ and $antec_gender =~ /inan|anim/ )
                        )    # voln
                        and
                        (   not defined $antec_number
                            or not defined $pron_number
                            or $pron_number eq $antec_number
                        )    # volnejsi podminka na shodu, na zivotnosti zatim nezalezi
                        )
                    {

                        #	    print STDERR "Antecedent nalezen: \n";
                        #	    print STDERR $perspron->get_attr('id')."\n";
                        $perspron->set_attr( 'coref_gram.rf', [ $subject->get_attr('id') ] );
                    }
                }
            }

        }
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::FindGramCorefForReflPron

Make co-reference links from personal pronouns to their antecedents,
if the latter ones are in subject position. This is neccessary because
of Czech pronoun 'reflexivization' (subclass of grammatical coreference).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
