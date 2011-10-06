package Treex::Block::W2A::EN::FixNominalGroups;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $MODEL = 'generated_data/extracted_from_BNC/left_neighbours_of_nouns.tsv';

sub get_required_share_files { return $MODEL; }

my %pair_count;

sub BUILD {
    my $filename = $ENV{TMT_ROOT} . '/share/' . $MODEL;
    open my $F, '<:utf8', $filename or log_fatal "Can't open $filename: $!";
    my $skip_header = <$F>;    #skip header
    while (<$F>) {

        #next if /##/;
        chomp;
        my ( $lemma1, $lemma2, $count ) = split /\t/, ( lc $_ );
        $pair_count{$lemma1}{$lemma2} += $count;    # summing up all lower/upper case combinations
    }
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    foreach my $i ( 0 .. $#anodes - 2 ) {
        my $A = $anodes[$i];
        my $B = $anodes[ $i + 1 ];
        my $C = $anodes[ $i + 2 ];
        if ($A->tag
            =~ /^[JN]/
            and $B->tag =~ /^N/
            and $C->tag =~ /^N/
            and $B->get_parent eq $C
            and (
                $A->get_parent eq $B
                or $A->get_parent eq $C
            )
            )
        {

            my ( $A_lemma, $B_lemma, $C_lemma ) =
                map { lc( $_->lemma ) } ( $A, $B, $C );

            my $predicted_parent;

            my $seen_first_pair  = $pair_count{$A_lemma}{$B_lemma} || 0;
            my $seen_second_pair = $pair_count{$A_lemma}{$C_lemma} || 0;

            # (((A) B) C)
            if ( $seen_first_pair > 1.5 * $seen_second_pair and $A->get_parent ne $B ) {

                #                print "$A_lemma $B_lemma $C_lemma\trehanging A below B\t($seen_first_pair > $seen_second_pair)\n";
                $A->set_parent($B);
            }

            # ((A B) C)  # surprisingly this never happened on the testing data
            elsif ( $seen_first_pair < $seen_second_pair and $A->get_parent ne $C ) {

                #                print "$A_lemma $B_lemma $C_lemma\trehanging A below C\t($seen_first_pair < $seen_second_pair)\n";
                $A->set_parent($C);
            }

        }
    }

    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::FixNominalGroups

In nominal group A B C, choose either structure ((A B) C)
or structure (((A) B) (C), using BNC frequencies of neighboring
lemmas (A B) and (B C).


=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
