package SEnglishA_to_SEnglishT::TBLa2t_phase2;

use 5.008;
use warnings;
use strict;

use base qw(TectoMT::Block);

use TBLa2t::Common;
use TBLa2t::Common_en;
require TBLa2t::Common_phase2;

#======================================================================

sub clone_tnode
{
    my ( $orig, $parent ) = @_;    # the node to be cloned and the parent of the new node
    my $new_n = $parent->create_child;
    init_copied_tnode( $new_n, $orig, $parent );
    return $new_n;
}

#======================================================================

sub new_tnode
{
    my ($parent) = @_;                   # the parent of the new node
    my $new_n = $parent->create_child;
    init_new_tnode( $new_n, $parent, 1 );
    return $new_n;
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;
    my $ftbl;                            # the fnTBL file

    # getting the filenames
    my ( $fname_in, $fname_lex, $fname_out ) = fntbl_fnames( $document->get_tied_fsfile->filename, 2 );

    # filling the fnTBL file
    open $ftbl, ">:utf8", $fname_in or Report::fatal "Cannot open the file $fname_in\n";
    for my $bundle ( $document->get_bundles ) {
        totbl( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # running fnTBL
    system("$FNTBL/bin/fnTBL ${fname_in} $MODEL/2/R -F $MODEL/2/params -printRuleTrace 2>&1 > $fname_out | sed 's/^.*\ch//g'") == 0 or Report::fatal "Command failed";

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

=item SEnglishA_to_SEnglishT::TBLa2t_phase2

Assumes English t-trees created with phase 1 (or 1_a). Performs complex tree-to-tree transformations of t-trees including adding and deleting inner nodes. It sets C<functor>s of added nodes.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
