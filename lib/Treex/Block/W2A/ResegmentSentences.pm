package Treex::Block::W2A::ResegmentSentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'segmenters' => (
    is      => 'rw',
    isa     => 'HashRef[Treex::Tool::Segment::RuleBased]',
    default => sub { return {} },
);

sub _get_segmenter {
    my $self = shift;
    my $lang = uc shift;
    if ( exists $self->segmenters->{$lang} ) {
        return $self->segmenters->{$lang};
    }
    my $specific = "Treex::Tool::Segment::${lang}::RuleBased";
    my $fallback = "Treex::Tool::Segment::RuleBased";
    foreach my $class ( $specific, $fallback ) {
        my $segmenter = eval "use $class; $class->new()"; ##no critic (BuiltinFunctions::ProhibitStringyEval) We want to use it, it is simpler and we check result
        if ($segmenter) {
            $self->segmenters->{$lang} = $segmenter;
            return $segmenter;
        }
        else {
            log_info("Failed during creating segmenter $class: $@");
        }
    }
    log_fatal("Cannot create segmenter for $lang");
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $my_label = $self->zone_label || '';
    my %sentences;
    my ( $my_segments, $max_segments ) = ( 0, 0 );
    foreach my $zone ( $bundle->get_all_zones() ) {
        my $lang      = $zone->language;
        my $label     = $zone->get_label();
        my $segmenter = $self->_get_segmenter($lang);
        $sentences{$label} = [ $segmenter->get_segments( $zone->sentence ) ];
        my $segments = @{ $sentences{$label} };
        if ( $segments > $max_segments ) { $max_segments = $segments; }
        if ( $label eq $my_label ) { $my_segments = $segments; }
    }

    # If no language (and selector) were specified for this block
    # resegment all zones
    if ( $my_segments == 0 ) {
        $my_segments = $max_segments;
    }

    # We are finished if
    # the zone to be processed contains just one sentence.
    return if $my_segments == 1;

    # TODO: If a zone contains less subsegments (e.g. just 1) than $segments
    # we can try to split it to equally long chunks regardless of the real
    # sentence boundaries. Anyway, all evaluation blocks should join the
    # segments together again before measuring BLEU etc.
    my $doc     = $bundle->get_document;
    my $orig_id = $bundle->id;
    $bundle->set_id("${orig_id}_1of$my_segments");
    foreach my $zone ( $bundle->get_all_zones() ) {
        my $label = $zone->get_label();
        my $sent  = shift @{ $sentences{$label} };
        $zone->set_sentence($sent);
    }
    my $last_bundle = $bundle;
    my @labels      = keys %sentences;

    # TODO parameter to set how many bundles should be created: $my_segments or $max_segments?
    for my $i ( 2 .. $my_segments ) {
        my $new_bundle = $doc->create_bundle( { after => $last_bundle } );
        $last_bundle = $new_bundle;
        $new_bundle->set_id("${orig_id}_${i}of$my_segments");
        foreach my $label (@labels) {
            my $sent = shift @{ $sentences{$label} };
            if ( !defined $sent ) { $sent = ' '; }

            # If some zone contains more segments than the "current" zone,
            # the remaining segments will be joined to the last bundle.
            if ( $i == $my_segments && $max_segments > $my_segments ) {
                $sent .= ' ' . join( ' ', @{ $sentences{$label} } );
            }
            my ( $lang, $selector ) = split /_/, $label;
            my $new_zone = $new_bundle->create_zone( $lang, $selector );
            $new_zone->set_sentence($sent);
        }
    }

    return;
}

1;

__END__

TODO POD

=encoding utf-8

=head1 NAME

Treex::Block::W2A::ResegmentSentences

=head1 VERSION

=head1 DESCRIPTION

If the sentence segmenter says that the current sentence is
actually composed of two or more sentences, then new bundles
are inserted after the current bundle, each containing just
one piece of the resegmented original sentence.

All zones are processed.
The number of bundles created is determined by the number of subsegments
in the "current" zone (specified by the parameters C<language> and C<selector>).
If a zone contains less subsegments than the current one,
the remaining bundles will contain empty sentence.
If a zone contains more subsegments than the current one,
the remaining subsegments will be joined in the last bundle.

In other words, it is granted that the current zone,
will not contain empty sentences.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

