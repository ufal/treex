package Treex::Block::W2A::ResegmentSentences;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has remove => (
    is => 'ro',
    isa => enum( [qw(no all diff)] ),
    default => 'no',
    documentation => 'remove=no   ... Do not delete any bundles (default). ' 
                   . 'remove=all  ... Delete bundles with multiple subsegments. '
                   . 'remove=diff ... Delete bundles with zones with different number of subsegments.',
);

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
    
    # So we have more subsegments. Delete the bundle and exit if requested.
    if ($self->remove eq 'all'){
        $bundle->remove();
        return;
    }

    # TODO: If a zone contains less subsegments (e.g. just 1) than $segments
    # we can try to split it to equally long chunks regardless of the real
    # sentence boundaries. Anyway, all evaluation blocks should join the
    # segments together again before measuring BLEU etc.
    my $doc         = $bundle->get_document;
    my $orig_id     = $bundle->id;
    my $last_bundle = $bundle;
    my @labels      = keys %sentences;

    # If any zone has different number of subsegments than $my_segments
    # and the user requested to delete such bundles, do it and exit.
    if ($self->remove eq 'diff'){
        if (any {$_ != $my_segments} map {scalar @{$sentences{$_}}} @labels) {
            $bundle->remove();
            return;
        }
    }

    # First subsegment will be saved into the original bundle (with renamed id)
    $bundle->set_id("${orig_id}_1of$my_segments");
    foreach my $zone ( $bundle->get_all_zones() ) {
        my $label = $zone->get_label();
        my $sent  = shift @{ $sentences{$label} };
        $zone->set_sentence($sent);
    }

    # Other subsegments will be saved to new bundles
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

=encoding utf-8

=head1 NAME

Treex::Block::W2A::ResegmentSentences - split bundles which contain more sentences

=head1 MOTIVATION

Some resources (most notably WMT newstest) are segmented to chunks of text
which mostly correspond to sentences, but sometimes contain more than one sentence.
Sometimes we want to process such documents in Treex and output (Write::*)
the result in a format where one output segement correspond to one input segement.
(So e.g. for "one-sentence-per-line writers", we have the same number of input and output lines.)

However, most Treex blocks expect exactly one (linguistic) sentence in each bundle.
The solution is to use block C<W2A::ResegmentSentences> after the reader
and C<Misc::JoinBundles> before the writer.

=head1 DESCRIPTION

If the sentence segmenter says that the current sentence is
actually composed of two or more sentences, then new bundles
are inserted after the current bundle, each containing just
one piece of the resegmented original sentence.

This block should be executed before tokenization (and tagging etc).
It deals only with the (string) attribute C<sentence> in each zone,
it does not process any trees.

All zones are processed.
The number of bundles created is determined by the number of subsegments
in the "current" zone (specified by the parameters C<language> and C<selector>).
If a zone contains less subsegments than the current one,
the remaining bundles will contain empty sentence.
If a zone contains more subsegments than the current one,
the remaining subsegments will be joined in the last bundle.

In other words, it is granted that the current zone,
will not contain empty sentences.

As a special case if parameters C<language> and C<selector> define a zone
which is not present in a bundle (this holds also for language=all),
the "current" zone is the one with most subsegments, i.e. no subsegments are joined.

=head1 PARAMETERS

=head2 remove (no|all|diff)
By setting parameter C<remove> you can delete some bundles.
Default is remove=no.
Setting remove=all will delete all bundles with more than one subsegments in the current zone.
Setting remove=diff will delete all bundles that have (at least) two zones with different number of subsegments.

=head1 SEE ALSO

L<Treex::Block::Misc::JoinBundles>

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

