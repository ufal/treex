package Treex::Block::A2T::EN::FindTextCorefML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $language = 'en';
my $selector = 'ref';
my $range = 10;

sub get_ante_cands {
    my ( $anaph ) = @_;
    
    # current sentence
    my @precendants = grep { $_->precedes($anaph) }
        $anaph->get_root->get_descendants( { ordered => 1 } );

    # previous sentences
    my $sent_num = $anaph->get_bundle->get_position;

    if ( $sent_num > 0 ) {
        my $bottom_idx = $sent_num - $range;
        $bottom_idx = 0 if ($bottom_idx < 0);
        my $top_idx = $sent_num - 1;
        my @all_bundles = $anaph->get_document->get_bundles;
        my @prev_bundles = @all_bundles[ $bottom_idx .. $top_idx ];
        my @prev_ttrees   = map {
            $_->get_zone($language, $selector)->get_ttree
        } @prev_bundles;
        unshift @precendants, map { $_->get_descendants( { ordered => 1 } ) } @prev_ttrees;
    }
    
    return reverse 
        grep {
            ( $_->gram_sempos || "" ) =~ /^n/ 
            and ( !$_->gram_person || ($_->gram_person !~ /(1|2)/) ) 
        } @precendants;
}

sub process_document {
    my ( $self, $document ) = @_;
    
    my @all_ttrees = map {
        $_->get_zone($language, $selector)->get_ttree
    } $document->get_bundles;
    
#     all (third person) semantic nouns 
    my @semnouns = 
        grep { 
            ( $_->gram_sempos || "" ) =~ /^n/ 
            and ( !$_->gram_person || ($_->gram_person !~ /(1|2)/) ) 
        } map { $_->get_descendants( { ordered => 1 } ) } @all_ttrees;

#     foreach my $ttree ( @all_ttrees ) {
#         push @semnouns, grep { ( $_->gram_sempos || "" ) =~ /^n/ and ( !$_->gram_person || ($_->gram_person !~ /(1|2)/) ) } $ttree->get_descendants( { ordered => 1 } );
#     }

    print join "\t", map { $_->t_lemma } ($semnouns[0], $semnouns[1], $semnouns[2], $semnouns[3], $semnouns[4], $semnouns[5], $semnouns[6], $semnouns[7], $semnouns[8], $semnouns[9]);
    print "\n\n";

    foreach my $anaph ( grep { $_->t_lemma eq "#PersPron" and $_->gram_person !~ /(1|2)/} map { $_->get_descendants } @all_ttrees ) {
#         my $antec = $anaph->get_coref_text_nodes->[0];
        my @antecs = $anaph->get_coref_text_nodes;
        my @ante_cands = get_ante_cands($anaph);
        if ( grep { $_ eq $antecs[0] } @ante_cands ) {
#             print possitive instance
            foreach my $cand ( @ante_cands ) {
                next if ( $cand eq $antecs[0] );
#                 print negative instances
            }
        }
        if ( grep { $_ eq $anaph } ($semnouns[0], $semnouns[1], $semnouns[2], $semnouns[3], $semnouns[4], $semnouns[5], $semnouns[6], $semnouns[7], $semnouns[8], $semnouns[9]) ) {
            print $anaph->get_address . "\n";
            print "antecedent:\t" . $antecs[0]->id . "\n";
            print join "\t", map { $_->id } @ante_cands;
            print "\n\n";
        }
    }
    
#     foreach my $ttree ( @all_ttrees ) {
#         foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" } $ttree->get_descendants )
#     }
    
#     print $semnouns[9]->get_address . "\n";
}

sub process_ttree_heuristic {
# sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @semnouns = grep { ( $_->gram_sempos || "" ) =~ /^n/ } $t_root->get_descendants( { ordered => 1 } );

    foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" and $_->formeme =~ /poss/ and $_->nodetype eq 'complex' } $t_root->get_descendants ) {

        my %attrib = map { ( $_ => $perspron->get_attr("gram/$_") ) } qw(gender number person);

        my @candidates = reverse grep { $_->precedes($perspron) } @semnouns;

        # pruning by required agreement in number
        @candidates = grep { ( $_->gram_number || "" ) eq $attrib{number} } @candidates;

        # pruning by required agreement in person
        if ( $attrib{person} =~ /[12]/ ) {
            @candidates = grep { ( $_->gram_person || "" ) eq $attrib{person} } @candidates;
        }
        else {
            @candidates = grep { ( $_->gram_person || "" ) !~ /[12]/ } @candidates;
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

=item Treex::Block::A2T::EN::FindTextCorefML

Machine learning approach for finding textual coreference links.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Nguy Giang Linh, Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
