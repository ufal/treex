package Treex::Block::Read::AlignedSentences;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseAlignedTextReader';

sub next_document {
    my ($self) = @_;
    my $texts_ref = $self->next_document_texts();
    return if !defined $texts_ref;

    my %sentences =
        map { $_ => [ split /\n/, $texts_ref->{$_} ] } keys %{$texts_ref};

    my $n = 0;
    for my $zone_label ( keys %sentences ) {
        $n = @{ $sentences{$zone_label} } if !$n;
        log_fatal "Different number of lines in aligned documents"
            if $n != @{ $sentences{$zone_label} };
    }

    my $doc = $self->new_document();
    for my $i ( 0 .. $n - 1 ) {
        my $bundle = $doc->create_bundle();
        for my $zone_label ( keys %sentences ) {
            my ($lang, $selector) = ($zone_label, $self->selector);
            if ($zone_label =~ /_/) {
                ($lang, $selector) = split /_/, $zone_label;
            }
            my $zone = $bundle->create_zone( $lang, $selector );
            $zone->set_sentence( $sentences{$zone_label}[$i] );
        }
    }

    return $doc;
}

1;

__END__

treex Read::AlignedSentences en=en1.txt,en2.txt cs_ref=cs1.txt,cs2.txt
