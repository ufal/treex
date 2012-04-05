package Treex::Block::Write::CdtTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

override 'process_document' => sub {

    my ( $self, $document ) = @_;

    my %present_languages;

    foreach my $bundle ($document->get_bundles) {
        foreach my $zone ($bundle->get_all_zones) {
            $present_languages{$zone->language}++;
        }
    }

    foreach my $language (keys %present_languages) {
        $self->_store_as_tag($document,$language);
    }

    return;
};

sub _store_as_tag {
    my ($self,$document,$language) = @_;

    my $output_file = $document->full_filename;
    $output_file =~ s/\.treex\.gz$//;
    $output_file .= "-$language.tag";

    log_info( "Converting ".$document->full_filename." into ".$output_file);

    open my $OUTPUT,">:utf8",$output_file or log_fatal $!;

    print $OUTPUT "<p>\n";

  BUNDLE:
    foreach my $bundle ($document->get_bundles) {

        my $zone = $bundle->get_zone($language);
        next BUNDLE if not defined $zone;
        my $atree = $zone->get_atree;
        next BUNDLE if not defined $atree;

        print $OUTPUT "<s>\n";
        foreach my $node ($atree->get_descendants({ordered=>1})) {
            print $OUTPUT "<W id=\"" . $node->id . "\">" . $node->form . "</W>\n";
        }
        print $OUTPUT "</s>\n";
    }


    print $OUTPUT "</p>\n";

    close $OUTPUT;

}



1;

__END__

=head1 NAME

Treex::Block::Write::CdtTag

=head1 DESCRIPTION

Trees from all zones are stored in separate .tag files (the original format
of the Copenhagen Dependency Treebank).

=back

=head1 AUTHOR

Zdenek Zabokrtsky <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
