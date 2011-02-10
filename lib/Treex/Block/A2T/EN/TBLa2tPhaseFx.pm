package SEnglishA_to_SEnglishT::TBLa2t_phaseFx;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use TBLa2t::Common;
use TBLa2t::Common_en;
require TBLa2t::Common_phaseF;

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
    my $ch     = $t_node->get_eff_children;
    $outstr .= sprintf "%s %d %s ",    # lemma, children, mr
        adjust_lemma($a_node),
        $ch > 2 ? 2 : $ch,
        $mr;

    # features of its parent
    my $t_par = ( $t_node->get_eff_parents )[0];
    my $a_par = get_anode($t_par);
    $mr = morph_real($t_par);
    $ch = $t_par->get_eff_children - 1;
    $outstr .= sprintf "%s %s %d ",    # lemma, tag, children
        adjust_lemma($a_par),
        substr( $mr, -1 ),
        $ch > 2 ? 2 : $ch;

    # features of its siblings
    my $sib_mr = join ",", map {
        ( grep { $_ eq $t_node } @$_ ) ? '*' : morph_real( $_->[0] )
    } sort { $a->[0]->get_ordering_value <=> $b->[0]->get_ordering_value } $t_par->get_grouped_eff_children;
    $outstr .= $sib_mr . " ";          # mrs

    # features to be changed
    $outstr .= "--- ";                 # the functor
    return $outstr;
}

#======================================================================

sub parse_and_check_line
{
    my ( $line, $lemma ) = @_;
    $line =~ /^(\S+) (\S+ ){6}(\S+) \S+\s+$/ or Report::fatal "Bad line in the input file: \"$line\"";
    $1 eq $lemma or Report::fatal "The input files do not match ($1 vs. $lemma)";
    return $3;
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;
    my $ftbl;    # the fnTBL file

    # getting the filenames
    my ( $fname_in, $fname_lex, $fname_out ) = fntbl_fnames( $document->get_tied_fsfile->filename, 'Fx' );

    # filling the fnTBL file
    open $ftbl, ">:utf8", $fname_in or Report::fatal "Cannot open the file $fname_in\n";
    for my $bundle ( $document->get_bundles ) {
        repair_is_member( $bundle->get_tree('SEnglishT') );
        totbl( $ftbl, $bundle->get_tree('SEnglishT') );
    }
    close $ftbl;

    # running fnTBL
    system("$FNTBL/exec/most_likely_tag.prl -l $MODEL/Fx/T-func.lex -t 'RSTR','RSTR' $fname_in > $fname_lex") == 0 or Report::fatal "Command failed";

    #TODO this should be done better
    my $redirect = Report::get_error_level() == 1 ? '' : '2>/dev/null';

    system("$FNTBL/bin/fnTBL $fname_lex $MODEL/Fx/R -F $MODEL/Fx/params -printRuleTrace -nonsequential $redirect > $fname_out | sed 's/^.*\ch//g'") == 0 or Report::fatal "Command failed";

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

=item SCzechA_to_SCzechT::TBLa2t_phaseFx

Assumes Czech t-trees with correct structure, C<lemma>, C<tag>, and C<is_member> (i.e. does not use information from p-layer). Fills C<functors>.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
