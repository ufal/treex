package Treex::Block::Print::TranslationResume;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Eval::Bleu;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }
has 'source_language' => ( is => 'ro', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'ro', isa => 'Str', default => 'src' );
has 'reference_language' => ( is => 'ro', isa => 'Str', lazy_build=>1 );
has 'reference_selector' => ( is => 'ro', isa => 'Str', default => 'ref' );
has 'extension' => ( is => 'ro', isa => 'Str', default => 'streex' );

sub _build_reference_language {
    my ($self) = @_;
    return $self->language;
}

override '_do_process_document' => sub {
    my ( $self, $document ) = @_;

    my $doc_name = $document->full_filename();
    $doc_name =~ s{^.*/}{};
    my ( @src, @ref, @tst );
    my $position;

    foreach my $bundle ( $document->get_bundles ) {
        $position++;
        my $ref_zone = $bundle->get_zone( $self->reference_language, $self->reference_selector );
        push @src, $bundle->get_zone( $self->source_language, $self->source_selector )->sentence;
        push @ref, $ref_zone ? $ref_zone->sentence : '';
        push @tst, $bundle->get_zone( $self->language, $self->selector )->sentence;

        if ( $bundle->id !~ /(\d+)of(\d+)$/ or $1 == $2 ) {
            my $src_joined = join ' ', @src;
            my $ref_joined = join ' ', @ref;
            my $tst_joined = join ' ', @tst;
            $src_joined =~ s/\s+$//;    #TODO why is this needed?
            $ref_joined =~ s/\s+$//;
            my @matchings = Treex::Tool::Eval::Bleu::add_segment( $tst_joined, $ref_joined );
            print { $self->_file_handle } join(
                "\n",
                (
                    "ID\t" . $bundle->id . " ($doc_name." . $self->extension . "##$position)",
                    "SRC\t$src_joined",
                    "REF\t$ref_joined",
                    "TST\t$tst_joined",
                    join( ' ', @matchings[ 1 .. 4 ] ),
                    '', '',
                    )
            );
            @src = ();
            @ref = ();
            @tst = ();
        }
    }

    return;
};

1;

=over

=item Treex::Block::Print::TranslationResume

Prints source, reference and test sentences, and ngram statistics
in the format expected by compare_stats.pl

PARAMETERS:
  language
  source_language

=back

=cut

# Copyright 2011 Martin Popel, Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
