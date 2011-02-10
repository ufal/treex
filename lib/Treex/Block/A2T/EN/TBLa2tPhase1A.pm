package Treex::Block::A2T::EN::TBLa2tPhase1A;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




use TBLa2t::Common;
use TBLa2t::Common_en;
require TBLa2t::Common_phase1_a;

use Exporter 'import';
our @EXPORT = qw(feature_string);

#======================================================================

sub feature_node_string
{
    my ($t_node) = @_;
    my $a_node = $t_node ? get_anode($t_node) : undef;
    return sprintf "%s %s %s",
        adjust_lemma($a_node),
        attr( $a_node, 'afun' ),
        tag($a_node);
}

#======================================================================

sub feature_string
{

    #! zde by se melo pouzivat $a_node->get_eff_parents jako v ceskem protejsku!
    my ($t_node) = @_;
    my $t_par    = ( $t_node->get_eff_parents )[0];
    my $t_gpar   = ( $t_par->get_eff_parents )[0];
    return feature_node_string($t_node) . " "
        . feature_node_string($t_par) . " "
        . feature_node_string($t_gpar) . " "
        . $t_node->functor;

    #! spravny ftor by mel byt prepsan slovnikem -- nemelo by to posledni tedy zmizet?
}

#======================================================================

sub totbl
{
    my ( $ftbl, $t_root ) = @_;
    for my $t_node ( $t_root->get_descendants ) {
        printf $ftbl "%s - --- -\n", feature_string($t_node);
    }
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;
    my $ftbl;    # the fnTBL file

    # getting the filenames
    my ( $fname_in, $fname_lex, $fname_out ) = fntbl_fnames( $document->get_tied_fsfile->filename, 1 );

    # filling the fnTBL file
    open $ftbl, ">:utf8", $fname_in or Report::fatal "Cannot open the file $fname_in\n";
    for my $bundle ( $document->get_bundles ) {
        totbl( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # running fnTBL
    system("$FNTBL/exec/most_likely_tag.prl -l $MODEL/1_a/T-func.lex -t 'RSTR','RSTR' $fname_in | $FNTBL/exec/most_likely_tag.prl -l $MODEL/1_a/T-pdel.lex -t '-','-' - > $fname_lex") == 0 or Report::fatal "Command failed";
    system("$FNTBL/bin/fnTBL $fname_lex $MODEL/1_a/R -F $MODEL/1_a/params -printRuleTrace 2>&1 > $fname_out | sed 's/^.*\ch//g'") == 0                                                      or Report::fatal "Command failed";

    # merging
    open $ftbl, "<:utf8", $fname_out or Report::fatal "Cannot open the file $fname_out\n";
    for my $bundle ( $document->get_bundles ) {
        merg( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    unlink $fname_in, $fname_lex, $fname_out;
}

1;

=over

=item Treex::Block::A2T::EN::TBLa2tPhase1A

Assumes English t-trees with no t-preprocessing. Deletes nodes that correspond to synsemantic tokens and fills C<functor>s.

B<Never tested, do not use it!>

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
