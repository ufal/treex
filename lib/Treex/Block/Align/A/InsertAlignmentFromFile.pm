package Align_SxxA_SyyA::Insert_word_alignment;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use FileUtils;

my $LANGUAGE1;
my $LANGUAGE2;
my $ALIGNMENT_FILE;

my %skipped;
my @sym;

sub BUILD {
    my ($self) = @_;

    $LANGUAGE1 = $self->get_parameter('LANGUAGE1') or
        Report::fatal('Parameter LANGUAGE1 must be specified!');
    $LANGUAGE2 = $self->get_parameter('LANGUAGE2') or
        Report::fatal('Parameter LANGUAGE2 must be specified!');
    $ALIGNMENT_FILE = $self->get_parameter('ALIGNMENT_FILE') or
        Report::fatal('Parameter ALIGNMENT_FILE must be specified!');

    *ALIGNMENT_FILE = FileUtils::my_open( $ALIGNMENT_FILE );

    my $SKIPPED = $self->get_parameter('SKIPPED');

    if ($SKIPPED) {
        *SKIPPED = FileUtils::my_open( $SKIPPED );
        while (<SKIPPED>) {
            chomp;
            $skipped{$_} = 1;
        }
        close SKIPPED;
    }

    my $SYMMETRIZATIONS = $self->get_parameter('SYMMETRIZATIONS');
    @sym = split( /_/, $SYMMETRIZATIONS);
    @sym = ('int') if not @sym;

    return;
}

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {

        # delete previously made links
        foreach my $anode ( $bundle->get_generic_tree("S${LANGUAGE1}A")->get_descendants ) {
            $anode->set_attr( 'm/align/links', [] );
        }

        my $sentence_id = $bundle->get_attr("id");
        my $num = $sentence_id;
        $num =~ s/^.*s(\d+)$/$1/;
        next if $skipped{$sentence_id};
        my $found = 0;
        my @p;
        while ( !$found ) {
            my $line = <ALIGNMENT_FILE>;
            die "Bad alignment file!" if !$line || $line =~ /^\s*$/;
            @p = split( /\t/, $line );
            if ( @p > 0 && $p[0] =~ /$sentence_id$/ ) {
                $found = 1;
            }
        }
        shift @p;
        my %aligned;
        for (my $i = 0; $i < @p; $i++) {
            last if not $sym[$i];
            foreach my $pair (split( /\s/, $p[$i])) {
                if ( $pair =~ /^([0-9]*)-([0-9]*)$/ ) {
                    if ($aligned{$pair}) {
                        $aligned{$pair} .= ".$sym[$i]";
                    }
                    else {
                        $aligned{$pair} = $sym[$i];
                    }
                }
            }
        }
        
        # index nodes of the two trees
        my @nodes1 = $bundle->get_generic_tree("S${LANGUAGE1}A")->get_descendants( { ordered => 1 } ); 
        my @nodes2 = $bundle->get_generic_tree("S${LANGUAGE2}A")->get_descendants( { ordered => 1 } ); 
        
        foreach my $pair (keys %aligned) {

            if ( $pair =~ /^([0-9]+)-([0-9]+)$/ ) {

                # get the appropriate nodes

                my $anode1 = $nodes1[$1];
                my $anode2 = $nodes2[$2];

                # set alignment attribut
                my $links_rf = $anode1->get_attr('m/align/links');
                my %new_link = ( 'counterpart.rf' => $anode2->get_attr('id'), 'type' => $aligned{$pair} );
                push( @$links_rf, \%new_link );
                $anode1->set_attr( 'm/align/links', $links_rf );
            }
        }
    }
}

END {

    # we need to explicitly preserve current exit code because closing an
    # unfinished stream changes our exit code if the stream was coming
    # from e.g. a gzip process...
    my $save_exitcode = $?;
    close ALIGNMENT_FILE;
    $? = $save_exitcode;
}

1;

=over

=item Align_SxxA_SyyA::Insert_word_alignment;

Loads GIZA word-alignment output and writes it into TMT files.

PARAMETERS:

- ALIGNMENT_FILE - input file, each line in the format
  path:sent_id<TAB>first_alignment<TAB>second_alignment<TAB>third_alignment<TAB>...

- SYMMETRIZATIONS - names of particular alignments separated by '_', for example 'int_gdf_uni'

- LANGUAGE1, LANGUAGE2

OPTIONAL PARAMETERS:

- SKIPPED - list of sentence IDs which will be skipped 

=back

=cut

# Copyright 2010 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
