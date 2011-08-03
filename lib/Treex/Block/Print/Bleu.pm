package Treex::Block::Print::Bleu;
use Moose;
use Treex::Core::Common;
use Eval::Bleu;

extends 'Treex::Core::Block';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has reference_selector => (
    is      => 'ro',
    isa     => 'Str',
    default => 'ref',
);

has print_ngrams => (
    is      => 'ro',
    isa     => 'Int',
    default => 3,
);

has print_limit => (
    is      => 'ro',
    isa     => 'Int',
    default => 6,
);

has overall => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $tst = $bundle->get_zone( $self->language, $self->selector )->sentence;
    my $ref = $bundle->get_zone( $self->language, $self->reference_selector )->sentence;
    Eval::Bleu::add_segment( defined($tst) ? $tst : '', $ref );
    return;
}

sub _print_ngram_diff {
    my ( $self, $n, $limit ) = @_;
    my ( $miss_ref, $extra_ref ) = Eval::Bleu::get_diff( $n, $limit, $limit );
    print "________ Top missing $n-grams: ________   ________ Top extra $n-grams: ________\n";
    for my $i ( 0 .. $limit - 1 ) {
        printf "%30s %5d %30s %6d\n",
            $miss_ref->[$i][0], $miss_ref->[$i][1], $extra_ref->[$i][0], $extra_ref->[$i][1];
    }
    return;
}

sub _print_results {

    my ($self) = @_;

    my $bleu = Eval::Bleu::get_bleu();
    if ( $bleu == 0 ) {
        print "BLEU = 0\n";
    }
    else {
        my $bp = Eval::Bleu::get_brevity_penalty();
        for my $ngram ( 1 .. $self->print_ngrams ) {
            $self->_print_ngram_diff( $ngram, $self->print_limit );
        }
        printf "BLEU = %2.4f  (brevity penalty = %1.5f)\n", $bleu, $bp;
    }
    return;
}

sub process_document {
    my ( $self, $document ) = @_;

    if ( !$self->overall ) {
        Eval::Bleu::reset();
    }

    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }

    if ( !$self->overall ) {
        $self->_print_results();
    }
    return;
}

# Prints the whole statistics at the end of the process
sub DEMOLISH {

    my ($self) = @_;

    if ( $self->overall ) {
        $self->_print_results();
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Bleu

=head1 DESCRIPTION

Prints BLEU metric (translation quality) score.

Depending on the settings, the BLEU score for each processed document or an overall score for all documents is printed.
The score may also be accompanied by a list of top missing and extra n-grams.

A single reference translation is assumed.

=head1 ATTRIBUTES

=over

=item C<reference_selector>

The selector for the reference translation. Defaults to C<ref>.

=item C<print_ngrams>

The longest n-grams for which the missing/extra statistics are computed. Defaults to 3 (trigrams).

=item C<print_limit>

How many of the top missing / extra n-grams should be printed (default: 6).

=item C<overall>

If this is set to 1, an overall score for all the processed documents is printed instead of a score for each single
document.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
