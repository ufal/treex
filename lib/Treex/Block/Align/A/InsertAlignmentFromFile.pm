package Treex::Block::Align::A::InsertAlignmentFromFile;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use FileUtils;

has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_selector => ( isa => 'Str', is => 'ro', default  => '' );
has from        => ( isa => 'Str', is => 'ro', required => 1 );
has inputcols   => ( isa => 'Str', is => 'ro', default  => 'int' );

#has skipped => ( isa => 'Str', is => 'ro');

#my %skipped;
my @sym;

sub BUILD {
    my ($self) = @_;

    *ALIGNMENT_FILE = FileUtils::my_open( $self->from );

    #    if ($self->skipped) {
    #        *SKIPPED = FileUtils::my_open( $SKIPPED );
    #        while (<SKIPPED>) {
    #            chomp;
    #            $skipped{$_} = 1;
    #        }
    #        close SKIPPED;
    #    }
    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    # delete previously made links
    foreach my $a_node ( $a_root->get_descendants ) {
        $a_node->set_attr( 'alignment', [] );
    }

    my $sentence_id = $a_root->get_document->loaded_from . "-" . $a_root->get_bundle->id;

    #    my $num = $sentence_id;
    #    $num =~ s/^.*s(\d+)$/$1/;
    #    next if $skipped{$sentence_id};
    my $found = 0;
    my @p;
    while ( !$found ) {
        my $line = <ALIGNMENT_FILE>;
        chomp $line;
        die "Bad alignment file ".($self->from)
          .", alignment for sent '$sentence_id' not found."
            if !$line || $line =~ /^\s*$/;
        @p = split( /\t/, $line );
        if ( @p > 0 
            && ($p[0] eq $sentence_id || $p[0] =~ /\Q$sentence_id$/ ) ) {
            $found = 1;
        }
    }
    shift @p;
    my %aligned;
    my @type = split( /_/, $self->inputcols );
    for ( my $i = 0; $i < @p; $i++ ) {
        last if not $type[$i];
        if ($type[$i] =~ /^(there|back)score$/o) {
            # this column means alignment score
            my $there_or_back = $1;
            my $score = $p[$i];
            my $tgttree = $a_root->get_bundle->get_tree( $self->to_language, 'a', $self->to_selector );
            $a_root->set_attr("giza_scores/".$there_or_back."value", $score);
            $a_root->set_attr("giza_scores/counterpart.rf", $tgttree->id);
        } else {
            # real alignment type
            foreach my $pair ( split( /\s/, $p[$i] ) ) {
                if ( $pair =~ /^([0-9]*)-([0-9]*)$/ ) {
                    if ( $aligned{$pair} ) {
                        $aligned{$pair} .= ".$type[$i]";
                    }
                    else {
                        $aligned{$pair} = $type[$i];
                    }
                }
            }
        }
    }

    # index nodes of the two trees
    my @nodes = $a_root->get_descendants( { ordered => 1 } );
    my @to_nodes = $a_root->get_bundle->get_tree( $self->to_language, 'a', $self->to_selector )->get_descendants( { ordered => 1 } );

    foreach my $pair ( keys %aligned ) {
        if ( $pair =~ /^([0-9]+)-([0-9]+)$/ ) {
            my $srcidx = $1;
            my $tgtidx = $2;
            log_fatal "Bad alignment point $pair: $srcidx outside of"
                ." source sentence '$sentence_id' ("
                .scalar(@nodes)." tokens long)"
              if $srcidx < 0 || $srcidx > $#nodes;
            log_fatal "Bad alignment point $pair: $tgtidx outside of"
                ." target sentence '$sentence_id' ("
                .scalar(@to_nodes)." tokens long)"
              if $tgtidx < 0 || $tgtidx > $#to_nodes;
            $nodes[$srcidx]->add_aligned_node( $to_nodes[$tgtidx], $aligned{$pair} );
        } else {
            log_fatal "Bad alignment point '$pair' for '$sentence_id'";
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

=item Treex::Block::Align::A::InsertAlignmentFromFile;

Reads alignment from file and fills C<align/links> attributes in a-trees.

PARAMETERS:

- from - input file, each line in the format
  path:sent_id<TAB>first_alignment<TAB>second_alignment<TAB>third_alignment<TAB>...

    a-tree_cs_s25<TAB>1-2 5-7 4-3

- inputcols - names of particular alignments separated by '_'. Two special
  names are used to indicate columns with GIZA++ alignment score: 'therescore'
  and 'backscore' for a-b and b-a, resp. For example
  'int_gdf_uni_therescore_backscore'

- to_language, to_separator

OPTIONAL PARAMETERS:

- skipped - list of sentence IDs which will be skipped 

=back

=cut

# Copyright 2010-2011 David Marecek, Ondrej Bojar

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
