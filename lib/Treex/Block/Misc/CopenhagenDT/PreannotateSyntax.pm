package Treex::Block::Misc::CopenhagenDT::PreannotateSyntax;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language' => (is => 'rw', required=>1);
has 'rules' => ('is' => 'rw');

my %all_rules = (
    'es' => 'NEG VMfin parentright|CC VLadj parentright|CARD SCENE parentleft|SE VMfin parentright|VMfin VCLI parentleft|ADJ NC parentright|ART VLfin parentleft|VLadj ART parentleft|VSfin VLadj parentleft|PDEL NP parentleft|CSUBX VLfin parentleft|VHfin NC parentleft|CC VLfin parentright|VLfin CARD parentleft|SCENE PPX parentleft|NEG VSfin parentright|SCENE VLfin parentleft|PPX VLfin parentright|VLinf NC parentleft|ADV VLfin parentright|VSfin ADJ parentleft|ART NP parentleft|VLinf SCENE parentleft|VLfin CQUE parentleft|VLfin NC parentleft|VLfin VLinf parentleft|CC NC parentright|ART CARD parentleft|SCENE CQUE parentleft|NC SCENE parentleft|PAL NC parentleft|NEG VLfin parentright|CSUBI VLinf parentleft|SCENE DM parentleft|VSfin ART parentleft|SCENE QU parentleft|VLfin VLadj parentleft|NC PDEL parentleft|SCENE CARD parentleft|SCENE PPO parentleft|DM NC parentleft|VLinf ART parentleft|SCENE VLinf parentleft|VHfin VLadj parentleft|VMfin VLinf parentleft|SCENE NP parentleft|PDEL NC parentleft|PPO NC parentleft|CARD NC parentleft|VLfin ART parentleft|NC ADJ parentleft|VLfin SCENE parentleft|SE VLfin parentright|SCENE NC parentleft|SCENE ART parentleft|ART NC parentleft',

    'de' => 'ART PIDAT parentleft|PAV VAFIN parentright|VAFIN PTKNEG parentleft|VVFIN APPR parentleft|PAV VVINF parentright|VVFIN $, parentleft|PTKZU VAINF parentleft|APPR PPER parentleft|VVFIN PIS parentleft|KON VAFIN parentright|APPR PIAT parentleft|VVINF VMINF parentright|ADJD VVFIN parentright|VAINF VMFIN parentright|APPR PRELS parentleft|PDS VVFIN parentright|ADJD VAFIN parentright|ADV VAFIN parentright|VVFIN PRF parentleft|VAFIN $, parentleft|KOKOM NN parentleft|ART NE parentleft|PDS VAFIN parentright|VVPP VAINF parentright|PPER VMFIN parentright|VAFIN PPER parentleft|VMFIN PPER parentleft|KON VVFIN parentright|PDAT NN parentleft|APPR CARD parentleft|VAFIN ART parentleft|PIAT NN parentleft|APPR PPOSAT parentleft|KON NN parentright|VVINF VMFIN parentright|APPR NE parentleft|VVFIN ART parentleft|PPER VAFIN parentright|PPER VVFIN parentright|PPOSAT NN parentleft|VVFIN PPER parentleft|CARD NN parentleft|PTKZU VVINF parentleft|VVPP VAFIN parentright|ART ADJA parentleft|APPRART NN parentleft|APPR NN parentleft|APPR ART parentleft|ART NN parentleft'
);

sub BUILD {
    my ( $self ) = @_;

    if (not $all_rules{$self->language}) {
        log_fatal("No rules for language ".$self->language);
    }

    my %rule_hash;
    foreach my $signature (split /\|/,$all_rules{$self->language}) {
        my ($left_tag,$right_tag,$orientation) = split ' ', $signature;
        $rule_hash{$left_tag}{$right_tag} = $orientation;
    }

    $self->set_rules(\%rule_hash);
}


sub process_bundle {
    my ( $self, $bundle ) = @_;

    return if not $bundle->get_zone($self->language);

    my $atree = $bundle->get_zone($self->language)->get_atree;

    my @anodes = $atree->get_descendants({'ordered' => 1});

    foreach my $index (0..$#anodes-1) {

        my $orientation = $self->rules->{$anodes[$index]->tag}{$anodes[$index+1]->tag} || '';

        if ($orientation eq 'parentleft') {
            $anodes[$index+1]->set_parent($anodes[$index]);
        }
        elsif ($orientation eq 'parentright') {
            $anodes[$index]->set_parent($anodes[$index+1]);
        }

    }

    return;
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::PreannotateSyntax

Apply relatively reliable rules for attaching neighboring nodes.



=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
