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
    is => 'ro',
    isa => 'Int',
    default => 3,
);

has print_limit => (
    is => 'ro',
    isa => 'Int',
    default => 6,
); 

sub process_bundle {
    my ($self, $bundle) = @_;
    my $tst = $bundle->get_zone($self->language, $self->selector)->sentence;
    my $ref = $bundle->get_zone($self->language, $self->reference_selector)->sentence;
    Eval::Bleu::add_segment( $tst, $ref );
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
}

sub process_document {
    my ($self, $document) = @_;
    Eval::Bleu::reset();
    foreach my $bundle ($document->get_bundles()){
        $self->process_bundle($bundle);
    }

    my $bleu = Eval::Bleu::get_bleu();
    if ( $bleu == 0 ) {
        print "BLEU = 0\n";
    }
    else {
        my $bp = Eval::Bleu::get_brevity_penalty();
        for my $ngram (1 .. $self->print_ngrams){
            $self->_print_ngram_diff( $ngram, $self->print_limit );
        }
        printf "BLEU = %2.4f  (brevity penalty = %1.5f)\n", $bleu, $bp;
    }
    return;
}

1;

=over

=item Treex::Block::Print::Bleu

Prints BLEU metric (translation quality) score.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
