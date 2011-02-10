package SEnglishA_to_SEnglishT::Find_text_coref;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $t_root = $bundle->get_tree('SEnglishT');

    my @semnouns = grep {($_->get_attr('gram/sempos')||"") =~ /^n/} $t_root->get_descendants( { ordered => 1} );

    foreach my $perspron ( grep {$_->get_attr('t_lemma') eq "#PersPron" and $_->get_attr('formeme') =~ /poss/} $t_root->get_descendants ) {

	my %attrib = map {($_ => $perspron->get_attr("gram/$_"))} qw(gender number person);

	my @candidates = reverse grep {$_->precedes($perspron) } @semnouns;

	# pruning by required agreement in number
	@candidates = grep {($_->get_attr('gram/number')||"") eq $attrib{number}} @candidates; 

	# pruning by required agreement in person
	if ($attrib{person} =~ /[12]/) {
	    @candidates = grep { ($_->get_attr('gram/person')||"") eq $attrib{person} } @candidates;
	}
	else {
	    @candidates = grep { ($_->get_attr('gram/person')||"") !~ /[12]/ } @candidates;
	}

#	print "Sentence:\t".$bundle->get_attr('english_source_sentence')."\t";
#	print "Anaphor:\t".$perspron->get_lex_anode->get_attr('m/form')."\t";
	
	if (my $antec = $candidates[0]) {
#	    print "YES: ".$antec->get_attr('t_lemma')."\n";
	    $perspron->set_deref_attr( 'coref_text.rf', [ $antec ] );

	}
	else {
#	    print "NO";
	}
#	print "\n";


    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Find_text_coref

Very simple heuristics for finding textual coreference links.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
