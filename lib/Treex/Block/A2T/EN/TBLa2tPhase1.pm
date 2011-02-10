package Treex::Block::A2T::EN::TBLa2tPhase1;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




use TBLa2t::Common;
use TBLa2t::Common_en;
require TBLa2t::Common_phase1;

use Exporter 'import';
our @EXPORT = qw(feature_string);

#======================================================================

sub feature_node_string
{
    my ($t_node) = @_;
    my $a_node = $t_node ? get_anode($t_node) : undef;
    return sprintf "%s %s %s %s",
        adjust_lemma($a_node),
        attr( $a_node, 'afun' ),
        tag($a_node),
        attr( $t_node, 'functor' );
}

#======================================================================

sub feature_string
{
    my ($t_node) = @_;
    my $t_par = ( $t_node->get_eff_parents )[0];
    my $syn_lemmas = join '+', sort map { adjust_lemma($_) } grep { tag($_) !~ /^[-,.D]/ } $t_node->get_aux_anodes;
    $syn_lemmas or $syn_lemmas = '----';
    return feature_node_string($t_node) . " " . ( $t_node->get_eff_children > 1 ? 2 : $t_node->get_eff_children ) . " "
        . feature_node_string($t_par) . " "
        . $syn_lemmas . " "
        . $t_node->functor;
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
    system("$FNTBL/exec/most_likely_tag.prl -l $MODEL/1/T-pdel.lex -t '-','-' $fname_in > $fname_lex") == 0                        or Report::fatal "Command failed";
    system("$FNTBL/bin/fnTBL $fname_lex $MODEL/1/R -F $MODEL/1/params -printRuleTrace 2>&1 > $fname_out | sed 's/^.*\ch//g'") == 0 or Report::fatal "Command failed";

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

=item Treex::Block::A2T::EN::TBLa2tPhase1

Assumes English t-trees created with phase 0. Deletes nodes that correspond to synsemantic tokens and fills C<functor>s.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
