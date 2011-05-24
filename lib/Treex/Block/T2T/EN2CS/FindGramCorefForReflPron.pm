package Treex::Block::T2T::EN2CS::FindGramCorefForReflPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->t_lemma eq "#PersPron" and $tnode->formeme !~ /1/ ) {

        my $perspron = $tnode;

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
                my $antec_number = $subject->gram_number;
                my $pron_number  = $perspron->gram_number;
                my $antec_gender = $subject->gram_gender;
                my $pron_gender  = $perspron->gram_gender;

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
                    #	    print STDERR $perspron->id."\n";
                    $perspron->set_attr( 'coref_gram.rf', [ $subject->id ] );
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
