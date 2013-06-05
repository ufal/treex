package Treex::Block::Write::NERHighlightWriter;

=pod

=head1 NAME
Treex::Block::Write::NERHighlightWriter - Writes the analyzed text with marked types of named entities.

=head1 DESCRIPTION

Writer for Treex files with recognized named entities. Writes the plain text with marked named entities.

=cut

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use Data::Dumper;



=pod

=over 4

=item I<process_zone>

Prints out the sentence with highlighted named entities.

=cut


sub process_zone {
    my ($self, $zone) = @_;

    log_fatal "ERROR: There is a zone without n_root" and die if !$zone->has_ntree;

    my $n_root = $zone->get_ntree();
    my $a_root = $zone->get_atree();
    my @anodes = $a_root->get_descendants({ordered => 1});

    my @nnodes = $n_root->get_descendants();

    my %sentence;

    for my $anode (@anodes) {
        my $aid = $anode->id;
        my $aform = $anode->get_attr("form");
        $sentence{$aid} = $aform;
    }

    for my $nnode (@nnodes) {
        my $a_refs = $nnode->get_deref_attr("a.rf");
        my @a_ents = @$a_refs;


        my $ent_beg = $a_ents[0]->id;
        my $ent_end = $a_ents[$#a_ents]->id;
        
        my $ent_type = $nnode->get_attr("ne_type");

        $sentence{$ent_beg} = "<" . $ent_type . " " . $sentence{$ent_beg};
        $sentence{$ent_end} .= ">";
    }

    for my $anode (@anodes) {
        my $aid = $anode->id;
        print $sentence{$aid};
        print " " unless $anode->get_attr("no_space_after");
    }

    print "\n";

}


=pod

=back

=head1 AUTHORS

Petr Jankovsky <jankovskyp@gmail.com>

Jindra Helcl <jindra.helcl@gmail.com>

Jan Masek <honza.masek@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
