package Treex::Block::A2T::CS::TBLa2tPhaseFd;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use TBLa2t::Common;
use TBLa2t::Common_cs;

my %lex;           # {lexf1}{lexf2} -> functor (from the lexicon file)
my @rule_left;     # [rule_no] -> ([feature_no, feature_value])
my @rule_right;    # [rule_no] -> functor (from the rule file)
my ( $lexf1, $lexf2, $outf );    # numbers of 2 features from the lexicon file and of the output one -- the functor

#======================================================================

BEGIN
{

    Treex::Core::Resource::require_file_from_share( "data/models/TBLa2t/cs_pdt/F/T-func.lex", 'user' );    # list of possible functors for a given afun
    Treex::Core::Resource::require_file_from_share( "data/models/TBLa2t/cs_pdt/F/feat",       'user' );    # list of used features
    Treex::Core::Resource::require_file_from_share( "data/models/TBLa2t/cs_pdt/F/R",          'user' );    # transformation-based learning rules

    my $f;                                                                                          # the handle for all the files

    # lexicon file
    open $f, "<:utf8", "$MODEL/F/T-func.lex" or log_fatal "Cannot open the file $MODEL/F/T-func.lex\n";
    $_ = <$f>;
    chomp;                                                                                          # read and parse '#pattern: .*'
    /^#pattern: ([0-9]+),([0-9]+)=>([0-9]+)/ or log_fatal "Bad line format: \"$_\"\n";              # assumption: the functor depends on 2 other features
    ( $lexf1, $lexf2, $outf ) = ( $1, $2, $3 );
    for ( 1 .. 2 ) {<$f>}                                                                           # skip '[0-9]+-grams: -----'
    while (<$f>) {                                                                                  # fill %lex
        chomp;
        my ( $afun1, $afun2, $func ) = split / +/;
        $lex{$afun1}{$afun2} = $func;
    }
    close $f;

    # feature file
    my %feat2nr;                                                                                    # {feature_name} -> feature_no
    open $f, "<:utf8", "$MODEL/F/feat" or log_fatal "Cannot open the file $MODEL/F/feat\n";         # assumption: this filename
    $_ = <$f>;
    chomp;                                                                                          # read and parse the only line
    my @feat = split / +/;
    pop @feat;
    pop @feat;                                                                                      # remove '=> out_feature_name'
    for my $i ( 0 .. $#feat ) {                                                                     # fill %feat2nr
        $feat2nr{ $feat[$i] } = $i;
    }
    close $f;

    # rule file
    open $f, "<:utf8", "$MODEL/F/R" or log_fatal "Cannot open the file $MODEL/F/R\n";
    <$f>;                                                                                           # skip '#train_voc_file: .*'
    for ( my $cnt = 0; defined( $_ = <$f> ); $cnt++ ) {                                             # fill %rule_left and % rule_right
        chomp;
        my @line = split / +/;
        for ( 1 .. 4 ) { shift @line }                                                              # remove 'GOOD:[0-9]+ BAD:[0-9]+ SCORE:[0-9]+ RULE:'
        $_ = pop @line;                                                                             # get the output feature
        /^[^=]+?=(.+)$/ or log_fatal "Bad line format: \"$_\"\n";
        $rule_right[$cnt] = $1;

        pop @line;                                                                                  # remove '=>'
        for (@line) {                                                                               # get input features
            /^([^=]+?)=(.+)$/ or log_fatal "Bad line format: \"$_\"\n";
            push @{ $rule_left[$cnt] }, [ $feat2nr{$1}, $2 ];
        }
    }
    close $f;
}

#======================================================================

sub feature_string
{
    my ($t_node) = @_;
    my $outstr = "";

    # features of the node in question
    my $a_node = get_anode($t_node);
    my $ch     = $t_node->get_children;
    $outstr .= sprintf "%s %s %s%d %s ",    # lemma, afun, tag, children, mr
        adjust_lemma($a_node),
        attr( $a_node, 'afun' ),
        tag_generic( $a_node, 0, 1, 4 ),
        $ch > 2 ? 2 : $ch,
        morph_real($t_node);

    # features of its parent
    my $t_par = ( $t_node->get_eparents({or_topological => 1}) )[0];
    my $a_par = get_anode($t_par);
    $ch = $t_par->get_children - 1;
    $outstr .= sprintf "%s %s %s%d ",       # lemma, afun, tag, children
        adjust_lemma($a_par),
        attr( $a_par, 'afun' ),
        tag_generic( $a_par, 0, 1, 11 ),
        $ch > 2 ? 2 : $ch;

    # features to be changed
    $outstr .= "--- ";                      # the functor
    return $outstr;
}

#======================================================================

sub classify
{
    my ($t_root) = @_;

    for my $t_node ( $t_root->get_descendants ) {
        $t_node->get_lex_anode   or next;
        defined $t_node->t_lemma or log_fatal "Assertion failed";

        #		info $t_node->t_lemma, "  ";

        # prepare the record
        my @record = split( ' ', feature_string($t_node) );

        # classify it according the lexicon file
        $record[$outf] = $lex{ $record[$lexf1] }{ $record[$lexf2] } || 'RSTR';

        #		info "l:$record[$outf]";

        # classify it according the rule file
        RULE: for my $rule_no ( 0 .. $#rule_left ) {
            for my $feat_val ( @{ $rule_left[$rule_no] } ) {
                $record[ $feat_val->[0] ] eq $feat_val->[1] or next RULE;
            }
            $record[$outf] = $rule_right[$rule_no];    # a matching rule found -- change the functor

            #			info " $rule_no:$record[$outf]";
        }

        # set the functor
        $t_node->set_functor( $record[$outf] );

        #		info "\n";
        if ( !$t_node->is_coap_root && grep { $_->is_member } $t_node->get_children ) {
            $t_node->set_functor('CONJ');
        }    # otherwise the error propagates to the children
    }
}

#======================================================================

sub debug_print
{
    info "LEX\n";
    for my $k1 ( sort keys %lex ) {
        for my $k2 ( sort keys %{ $lex{$k1} } ) {
            info "$k1, $k2, $lex{$k1}{$k2}\n";
        }
    }
    info "^^^^^\n";

    info "RULES\n";
    for my $i ( 0 .. $#rule_left ) {
        info "$i: ";
        for my $feat_val ( @{ $rule_left[$i] } ) {
            info $feat_val->[0], "=", $feat_val->[1], " ";
        }
        info $rule_right[$i], "\n";
    }
    info "^^^^^\n";

}

#======================================================================

sub process_ttree {
    my ( $self, $t_root ) = @_;

    classify($t_root);
}

1;

=over

=item Treex::Block::A2T::CS::TBLa2tPhaseFd

Assumes Czech t-trees with correct structure, C<lemma>, C<tag>, C<is_member> and C<afun>. Fills C<functors>.

Does not use external tools. Uses the same transformation based learning model as phase F (which requires
fnTBL toolkit) does.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
