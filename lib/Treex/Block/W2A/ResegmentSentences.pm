package Treex::Block::W2A::ResegmentSentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

#my %segmenter_for = (
#    universal => Treex::Tool::Segment::RuleBased->new(),
#    en        => Treex::Tool::Segment::EN::RuleBased->new(),
#    cs        => Treex::Tool::Segment::CS::RuleBased->new(),
#);

# TODO: even more elegant implementation, avoid string eval
sub _get_segmenter {
    my $lang     = uc shift;
    my $specific = "Treex::Tool::Segment::${lang}::RuleBased";
    my $fallback = "Treex::Tool::Segment::RuleBased";
    foreach my $class ( $specific, $fallback ) {
        my $segmenter = eval "use $class; $class->new()";
        return $segmenter if $segmenter;
    }
    log_fatal("Cannot create segmenter for $lang");
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my %sentences;
    my $segments = 0;
    foreach my $zone ( $bundle->get_all_zones() ) {
        my $lang      = $zone->language;
        my $label     = $zone->get_label();
        my $segmenter = _get_segmenter($lang);
        $sentences{$label} = [ $segmenter->get_segments( $zone->sentence ) ];
        if ( @{ $sentences{$label} } > $segments ) { $segments = @{ $sentences{$label} }; }
    }

    # We are finished if
    # A) All zones contain just one sentence.
    return if $segments == 1;

    # B) The zone to be processed contains just one sentence.
    if ( defined $self->language && defined $self->selector ) {
        return if @{ $sentences{ $self->zone_label } } == 1;
    }

    # TODO: If a zone contains less subsegments (e.g. just 1) than $segments
    # we can try to split it to equally long chunks regardless of the real
    # sentence boundaries. Anyway, all evaluation blocks should join the
    # segments together again before measuring BLEU etc.
    my $doc     = $bundle->get_document;
    my $orig_id = $bundle->id;
    $bundle->set_id("${orig_id}_1of$segments");
    foreach my $zone ( $bundle->get_all_zones() ) {
        my $label = $zone->get_label();
        my $sent  = shift @{ $sentences{$label} };
        $zone->set_sentence($sent);
    }
    my $last_bundle = $bundle;
    my @labels      = keys %sentences;

    for my $i ( 2 .. $segments ) {
        my $new_bundle = $doc->create_bundle( { after => $last_bundle } );
        $last_bundle = $new_bundle;
        $new_bundle->set_id("${orig_id}_${i}of$segments");
        foreach my $label (@labels) {
            my $sent = shift @{ $sentences{$label} };
            if ( !defined $sent ) { $sent = ' '; }
            my ( $lang, $selector ) = split /_/, $label;
            my $new_zone = $new_bundle->create_zone( $lang, $selector );
            $new_zone->set_sentence($sent);
        }
    }

    return;
}

1;

__END__

=over

=item Treex::Block::W2A::ResegmentSentences

If the sentence segmenter says that the current sentence is
actually composed of two or more sentences, then new bundles
are inserted after the current bundle, each containing just
one piece of the resegmented original sentence.

All zones are processed. If one zone contains less subsegments
than another, the remaining bundles will contain empty sentence.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
