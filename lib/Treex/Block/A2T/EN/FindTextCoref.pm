package Treex::Block::A2T::EN::FindTextCoref;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';



sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @semnouns = grep { ( $_->get_attr('gram/sempos') || "" ) =~ /^n/ } $t_root->get_descendants( { ordered => 1 } );

    foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" and $_->formeme =~ /poss/ } $t_root->get_descendants ) {

        my %attrib = map { ( $_ => $perspron->get_attr("gram/$_") ) } qw(gender number person);

        my @candidates = reverse grep { $_->precedes($perspron) } @semnouns;

        # pruning by required agreement in number
        @candidates = grep { ( $_->get_attr('gram/number') || "" ) eq $attrib{number} } @candidates;

        # pruning by required agreement in person
        if ( $attrib{person} =~ /[12]/ ) {
            @candidates = grep { ( $_->get_attr('gram/person') || "" ) eq $attrib{person} } @candidates;
        }
        else {
            @candidates = grep { ( $_->get_attr('gram/person') || "" ) !~ /[12]/ } @candidates;
        }

        #	print "Sentence:\t".$bundle->get_attr('english_source_sentence')."\t";
        #	print "Anaphor:\t".$perspron->get_lex_anode->form."\t";

        if ( my $antec = $candidates[0] ) {

            #	    print "YES: ".$antec->t_lemma."\n";
            $perspron->set_deref_attr( 'coref_text.rf', [$antec] );

        }
        else {

            #	    print "NO";
        }

    }
    return 1;
   
}

1;

=over

=item Treex::Block::A2T::EN::FindTextCoref

Very simple heuristics for finding textual coreference links.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
