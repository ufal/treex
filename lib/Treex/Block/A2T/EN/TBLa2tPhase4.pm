package SEnglishA_to_SEnglishT::TBLa2t_phase4;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use TBLa2t::Common;
use TBLa2t::Common_en;

#require TBLa2t::Common_phase4; -- not existent (would be empty)

use Exporter 'import';
our @EXPORT = qw(feature_string);

#======================================================================

sub feature_string
{
    my ($t_node) = @_;
    my $outstr = "";

    my $t_par = ( $t_node->get_eff_parents )[0];    # t-parent of the node
    $t_par or $t_par = $t_node->get_parent;
    my $a_node = $t_node->get_lex_anode;

    $outstr .= sprintf "%s %s %s %s %s ",
        $t_node->get_attr('functor'),
        aid($t_node) ? 1 : 0,
        tag($a_node),                               # tag of the node
        tag( get_anode($t_par) ),                   # tag of the parent
        attr( $t_par, 't_lemma' );

    # synsemantic words
    my @syn_lemmas = map { adjust_lemma($_) } grep { tag($_) !~ /^[-,.D]/ } $t_node->get_aux_anodes;
    for ( 0 .. 2 ) {
        $outstr .= ( defined $syn_lemmas[$_] ? $syn_lemmas[$_] : '--' ) . " ";
    }

    # initial values of classes
    my $lemma = defined $t_node->t_lemma ? $t_node->t_lemma : adjust_lemma($a_node);
    $outstr .= sprintf "%s %s ",
        aid($t_node) ? "---"  : $lemma,
        aid($t_node) ? $lemma : "---";

    return $outstr;
}

#======================================================================

sub totbl
{
    my ( $ftbl, $t_root ) = @_;
    for my $t_node ( $t_root->get_descendants ) {

        # print features
        print $ftbl feature_string($t_node);

        # void values of classes
        printf $ftbl "--- ---\n",
    }
}

#======================================================================

sub merg
{
    my ( $ftbl, $t_root ) = @_;
    for my $t_node ( $t_root->get_descendants ) {
        my $line;
        defined( $line = <$ftbl> ) or Report::fatal "Unexpected end of file";
        $line =~ s/(.*)\| ([0-9]+ )*$/$1/;                                                                       # strip rule' numbers
        $line =~ /^(\S+) (\S+) (\S+ ){6}(\S+) (\S+)/ or Report::fatal "Bad line in the input file: \"$line\"";
        $1 eq $t_node->get_attr('functor') or Report::fatal "The input files do not match ($1 vs. " . $t_node->get_attr('functor') . ")";

        $t_node->set_attr( 't_lemma', $2 ? $5 : $4 );
    }
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;
    my $ftbl;    # the fnTBL file

    # getting the filenames
    my ( $fname_in, $fname_lex, $fname_out ) = fntbl_fnames( $document->get_tied_fsfile->filename, 4 );

    # filling the fnTBL file
    open $ftbl, ">:utf8", $fname_in or Report::fatal "Cannot open the file $fname_in\n";
    for my $bundle ( $document->get_bundles ) {
        totbl( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # running fnTBL
    system("$FNTBL/exec/most_likely_tag.prl -l $MODEL/4/T-lem0.lex -t '---','---' $fname_in > $fname_lex") == 0                    or Report::fatal "Command failed";
    system("$FNTBL/bin/fnTBL $fname_lex $MODEL/4/R -F $MODEL/4/params -printRuleTrace 2>&1 > $fname_out | sed 's/^.*\ch//g'") == 0 or Report::fatal "Command failed";

    # merging
    open $ftbl, "<:utf8", $fname_out or Report::fatal "Cannot open the file $fname_out\n";
    for my $bundle ( $document->get_bundles ) {
        merg( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # delete afuns
    for my $bundle ( $document->get_bundles ) {
        for ( $bundle->get_tree('SEnglishA')->get_descendants ) {
            $_->set_attr( 'afun', undef );
        }
    }

		unlink $fname_in, $fname_lex, $fname_out;
}

1;

=over

=item SEnglishA_to_SEnglishT::TBLa2t_phase4

Assumes English t-trees created with phase 3. Corrects or fills C<t_lemma>.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
