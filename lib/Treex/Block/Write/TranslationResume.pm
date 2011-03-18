package Treex::Block::Write::TranslationResume;
use Moose;
use Treex::Moose;
use Eval::Bleu;

extends 'Treex::Core::Block';

sub build_language { log_fatal "Parameter 'language' must be given"; }
has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );

sub process_document {
    my ( $self, $document ) = @_;
    my $doc_name = $document->full_filename();
    $doc_name =~ s{^.*/}{};
    my ( @src, @ref, @tst, $id );
    my $position;

    foreach my $bundle ( $document->get_bundles ) {
        $position++;
        my $ref_zone = $bundle->get_zone( $self->language, 'ref' );
        push @src, $bundle->get_zone( $self->source_language, 'src' )->sentence;
        push @ref, $ref_zone ? $ref_zone->sentence : '';
        push @tst, $bundle->get_zone( $self->language, 'tst' )->sentence;

        if ( $bundle->id !~ /(\d+)of(\d+)$/ or $1 == $2 ) {
            my $src_joined = join ' ', @src;
            my $ref_joined = join ' ', @ref;
            my $tst_joined = join ' ', @tst;
            $src_joined =~ s/\s+$//;    #TODO why is this needed?
            $ref_joined =~ s/\s+$//;
            my @matchings = Eval::Bleu::add_segment( $tst_joined, $ref_joined );
            print join(
                "\n",
                (
                    "ID\t" . $bundle->id . " ($doc_name.treex##$position)",
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
}

1;

=over

=item Treex::Block::Write::TranslationResume

Prints source, reference and test sentences, and ngram statistics
in the format expected by compare_stats.pl

PARAMETERS:
  language
  source_language

=back

=cut

# Copyright 2011 Martin Popel, Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
