package Treex::Block::A2A::AddTranslationsFromFile;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'translation_file' => ( is => 'ro', isa => 'Str', required => 1 );
has 'source_selector'  => ( is => 'ro', isa => 'Str', default => '' );
has 'target_language'  => ( is => 'ro', isa => 'Str', default => 'en' );
has 'target_selector'  => ( is => 'ro', isa => 'Str', default => 'GT' );
has 'alignment_type'   => ( is => 'ro', isa => 'Str', default => 'gloss' );

sub process_document {
	my ( $self, $doc ) = @_;
	my @bundles = $doc->get_bundles();
	my $translation_doc =
	  Treex::Core::Document->new( { filename => $self->translation_file } )
	  ;
	my @translation_bundles = $translation_doc->get_bundles();
	if ( scalar(@bundles) != scalar(@translation_bundles) ) {
		log_fatal( "The number of bundles from "
			  . $doc->full_filename
			  . " and the number of bundles from "
			  . $translation_doc->full_filename
			  . " should match" );
	}
	foreach my $i (0..$#bundles) {
        my $translation_zone = $translation_bundles[$i]->get_zone(
            $self->target_language, $self->target_selector);
        my $translation_sentence = $translation_zone->get_sentence();
        my $translation_atree = $translation_zone->get_atree();
		my $new_translation_zone = $bundles[$i]->create_zone(
            $self->target_language, $self->target_selector);
		my $new_source_zone = $bundles[$i]->get_zone(
            $self->language, $self->selector);
        # copy a-tree
        my $new_translation_atree = $new_translation_zone->create_atree());
        $translation_atree->copy_atree($new_translation_atree);
        # copy sentence
        $new_translation_zone->set_sentence($translation_sentence);
        # copy alignment & set glosses
        # TODO tohle právě pro he NEJDE! musí se to projít podle no_space_after!
        my @target_nodes = $translation_atree->get_descendants(
            {ordered=>1, add_self=>1});
        my @new_target_nodes = $new_translation_atree->get_descendants(
            {ordered=>1, add_self=>1});
        my @new_source_nodes = $new_source_zone->get_atree()->get_descendants(
            {ordered=>1, add_self=>1});
        for (my $target_ord = 1; $target_ord <= scalar(@target_nodes); $target_ord++) {
            my $target_node = $target_nodes[$target_ord];
            my $new_target_node = $new_target_nodes[$target_ord];
            my @source_nodes =
                $target_node->get_aligned_nodes_of_type($self->alignment_type);
            foreach my $source_node (@source_nodes) {
                $source_ord = $source_ord->get_ord();
                $new_source_node = $new_source_nodes[$source_ord];
                $new_target_node->add_aligned_node(
                    $new_source_node, $self->alignment_type);
                # TODO
                $new_source_node->set_gloss();
            }
        }
	}
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::AddTranslationsFromFile - adds a translation from a different file.
Tuned for Hebrew, might need adjustments for other languages.

=head1 DESCRIPTION

Assumes that each bundle in C<translation_file> contains a pair of zones --
the source in C<language, source_selector> and its translation in
C<target_language, target_selector> -- each of them containing a sentence and its
a-tree (which may be a flat a-tree, aka w-tree),
and alignment links of type C<alignment_type>, leading from C<target_language,
target_selector> to C<translation_file>.
(Such files are produced by L<A2A::Translate>.)

For each bundle in the document being processed (i.e. the one read by a
reader, NOT the C<translation_file>), adds the following:

=over

=item translation zone C<target_language, target_selector> with the translated
sentence and its a-tree

=item alignment from C<target_language, target_selector> to C<language, selector>

=item C<gloss> attributes to C<language, selector> nodes, projected through
the alignment

=back

=head1 PARAMETERS

TODO write documentation for that

=over 4

=item C<translation_file>

The name of the treex file. This parameter is required.

=item C<source_selector>

The name of the selector within the zone to be copied. The default value is ''.

=item C<target_language>

The default value is 'en'.

=item C<target_selector>

The default value is 'GT'.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
 
