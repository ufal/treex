package SEnglishA_to_SEnglishT::Mark_clause_heads;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

# zatim nejake rozbite, znackuje to i infinitivy

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $t_node ( $t_root->get_descendants() ) {
        $t_node->set_attr( 'is_clause_head', is_clause_head($t_node) );
    }

    return;
}

sub is_clause_head {
    my ($t_node) = @_;
    my $lex_a_node = $t_node->get_lex_anode() or return 0;
    return 0 if $lex_a_node->tag !~ /^V/;

    my @anodes = $t_node->get_anodes( { ordered => 1 } );
    my @tags  = map { $_->tag } @anodes;
    my @forms = map { lc $_->form } @anodes;

    # Rule 1: verb forms containing 3rd person singular are certainly finite
    return 1 if grep {/^(VBZ|MD)$/} @tags;

    # Rule 2: verb forms containing the following modal and auxiliary tokens are certainly finite
    return 1 if grep {/^(is|was|were|had|did|do|am|are|will|wo|n't|'ll|'re|'[mds])$/i} @forms;

    # Rule 3: verb forms containing 'to' before the first verb token are certainly non-finite
    A_NODE:
    foreach my $index ( 0 .. $#anodes ) {
        last A_NODE if $tags[$index] =~ /^V/;
        return 0 if $forms[$index] eq 'to';
    }

    # Rule 4: verb forms for which a subject candidate can be found, are likely to be finite
    if ( grep {/^(VB|VBD|VBN|VBP)$/} @tags ) {
        my @leftchildren = map {$_->get_eff_children( { preceding_only => 1 } )} grep {$_->tag=~/^V/} @anodes;        
        for my $child (@leftchildren) {
            return 1 if is_possible_subject($child);
        }
    }
    
    # Otherwise: non-finite 
    return 0;
}

sub is_possible_subject {
    my ($a_node) = @_;
    return 0 if $a_node->tag =~ /^(RB[SR]?|IN|\(|\)|:|\$|MD|POS|PRP\$|RP|SYM|TO|WH\$|WRB)$/;
    return 0 if $a_node->form =~ /^(be|have|[,;()'`:-])$/;
    return 1;
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_clause_heads

SEnglishT nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
