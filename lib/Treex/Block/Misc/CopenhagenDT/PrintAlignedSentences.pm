package Treex::Block::Misc::CopenhagenDT::PrintAlignedSentences;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my %sentences;

    my @languages = qw(en da it);

    foreach my $language (@languages) {
        my $aroot = $bundle->get_zone($language)->get_atree();
         $sentences{$language} = [ map {join " ", map {$_->form} $_->get_descendants({ordered=>1})} $aroot->get_children ];
    }


    my $sent_number;
    while (1) {
        $sent_number++;
        my $success;
        foreach my $language (@languages) {
            my $sent = shift @{$sentences{$language}};
            if ($sent) {
                print "$sent_number $language: $sent\n";
                $success = 1;
            }
        }
        last unless $success;
        print "\n";
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::Print

Print supposedly aligned sentence segments (all still merged
in one bundle)

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
