package Treex::Block::Read::WordAlignmentXML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

use XML::Twig;

sub next_document {
    my ($self) = @_;

    my $text = $self->next_document_text();

    my $twig = XML::Twig->new();
    $twig->xparse( $text );

    my $doc = $self->new_document;

    foreach my $sentence ($twig->descendants('s')) {
        my $bundle = $doc->create_bundle;

	my %sentence_string;
	$sentence_string{en} = $sentence->first_child('english')->text;
	$sentence_string{cs} = $sentence->first_child('czech')->text;

	my %nodes = ( 'en'=>[], 'cs'=> [] );

	# step 1: create a node for each token
	foreach my $language ('en','cs') {
  	    my $zone = $bundle->create_zone($language);
	    my $atree = $zone->create_atree;
	    my $ord;
	    foreach my $word ( split / /, $sentence_string{$language} ) {
	        my $ord++;
	        push @{$nodes{$language}}, $atree->create_child( { form => $word, ord => $ord } );
	    }
	}

	# step 2: add the alignment links
	my $sure_links = $sentence->first_child('sure')->text;
#	my $possible_links = $sentence->first_child('possible')->text;

	foreach my $link ( split(/\s/,$sure_links), #split(/\s/,$possible_links)
			 ) {
	    if ( $link =~ /^(\d+)-(\d+)$/ ) {
	        my ( $en_index, $cs_index ) = ( $1-1, $2-1 );
		if ( $en_index > $#{$nodes{en}} or $cs_index > $#{$nodes{cs}}) {
		    log_fatal "Token index out of sentence lenght: EN: $en_index in 0..$#{$nodes{en}} CS: $cs_index in 0..$#{$nodes{cs}}";
		}
		$nodes{en}[$en_index]->add_aligned_node($nodes{cs}[$cs_index]);
	    }

	    else {
  	        log_fatal "Unexpected form a link: $link";
	    }
	}

    }

    return $doc;
}

1;

__END__


=head1 NAME

Treex::Block::Read::WordAlignmentXML

=head1 SYNOPSIS

  # in scenarios
  # Read:::WordAlignmentXML from=abcd.wa,efgh.wa

=head1 DESCRIPTION

Document reader for XML files distributed in the Czech-English manually aligned parallel corpus,
see http://ufal.mff.cuni.cz/tectomt/releases/manual_word_alignment_corpus/index.html

Only sure alignments are converted.

=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
