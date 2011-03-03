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
    for my $lang ( keys %sentences ) {
        $n = @{ $sentences{$lang} } if !$n;
        log_fatal "Different number of lines in aligned documents"
            if $n != @{ $sentences{$lang} };
    }

    my $doc = $self->new_document();
    for my $i ( 0 .. $n - 1 ) {
        my $bundle = $doc->create_bundle();
        for my $lang ( keys %sentences ) {
            my $zone = $bundle->create_zone( $lang, $self->selector );
            $zone->set_sentence( $sentences{$lang}[$i] );
        }
    }

    return $doc;
}

1;

__END__

treex Read::AlignedSentences en=en1.txt,en2.txt cs=cs1.txt,cs2.txt
