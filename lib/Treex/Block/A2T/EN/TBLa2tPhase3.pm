package Treex::Block::A2T::EN::TBLa2tPhase3;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




use TBLa2t::Common;
use TBLa2t::Common_en;
require TBLa2t::Common_phase3;

use Exporter 'import';
our @EXPORT = qw(feature_string);

#======================================================================

sub feature_string
{
    my ($t_node) = @_;
    my $outstr = "";

    # features of the node in question
    my $a_node = get_anode($t_node);
    my $mr     = morph_real($t_node);
    $outstr .= sprintf "%s/%s %s %s ", $t_node->t_lemma, substr( $mr, -1 ), substr( $mr, -1 ), $mr;    # lemma/POS, tag, mr

    # features of its parent
    my $t_par = ( $t_node->get_eff_parents )[0];
    $t_par or $t_par = $t_node->get_parent;
    my $a_par = get_anode($t_par);
    $mr = morph_real($t_par);
    $outstr .= sprintf "%s/%s ",                                                                       # lemma/POS
        attr( $t_par, 't_lemma' ), substr( $mr, -1 );

    # features of its children
    my @ch = grep { $_->get_attr('a/lex.rf') } $t_node->get_children( { ordered => 1 } );
    for ( 0 .. 5 ) {
        $outstr .= defined $ch[$_] ? $ch[$_]->t_lemma . " " . morph_real( $ch[$_] ) . " " : "--- -- ";
    }

    # features to be changed
    $outstr .= "--- " . $t_node->functor . " ";                                            # valency frame and current functor
    return $outstr;
}

#======================================================================

sub create_tnode
{
    my ( $parent, $func ) = @_;
    my $new_n = $parent->create_child;
    init_new_tnode( $new_n, $parent, 0 );
    $new_n->set_functor($func);
    $new_n->set_t_lemma('#Gen');
    return $new_n;
}

#======================================================================

sub parse_and_check_line
{
    my ( $line, $lemma ) = @_;
    $line =~ /^(\S+) (\S+ ){15}(\S+) (\S+) ((\S+ ){18})\S+ \S+ (\S+ ){18}\s+$/ or Report::fatal "Bad line in the input file: \"$line\"";
    substr( $1, 0, -2 ) eq $lemma or Report::fatal "The input files do not match (" . substr( $1, 0, -2 ) . " vs. $lemma)";
    return ( $3, $4, $5 );
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;
    my $ftbl;    # the fnTBL file

    # getting the filenames
    my ( $fname_in, $fname_lex, $fname_out ) = fntbl_fnames( $document->get_tied_fsfile->filename, 3 );

    # filling the fnTBL file
    open $ftbl, ">:utf8", $fname_in or Report::fatal "Cannot open the file $fname_in\n";
    for my $bundle ( $document->get_bundles ) {
        totbl( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # running fnTBL
    system("$FNTBL/bin/fnTBL ${fname_in} $MODEL/3/R -F $MODEL/3/params -printRuleTrace -nonsequential 2>&1 > $fname_out | sed 's/^.*\ch//g'") == 0 or Report::fatal "Command failed";

    # merging
    open $ftbl, "<:utf8", $fname_out or Report::fatal "Cannot open the file $fname_out\n";
    for my $bundle ( $document->get_bundles ) {
        merg( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    unlink $fname_in, $fname_out;
}

1;

=over

=item Treex::Block::A2T::EN::TBLa2tPhase3

Assumes English t-trees created with phase 2. Fills C<val_frame.rf>s, corrects C<functor>s and adds leaf nodes, i.e. those corresponding to valency members not expressed at the a-layer.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
