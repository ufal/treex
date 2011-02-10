package SEnglishA_to_SEnglishT::Assign_nodetype;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SEnglishT');
        $t_root->set_attr( 'nodetype', 'root' );

        foreach my $t_node ( $t_root->get_descendants ) {

            my $functor = $t_node->get_attr('functor');
            my $t_lemma = $t_node->get_attr('t_lemma');
            my $nodetype;

            if ( $functor =~ /^(?:APPS|CONJ|DISJ|ADVS|CSQ|GRAD|REAS|CONFR|CONTRA|OPER)$/ ) {
                $nodetype = 'coap';
            }
            elsif ( $functor =~ /^(?:RHEM|PREC|PARTL|MOD|ATT|INTF|CM)$/ ) {
                $nodetype = 'atom';
            }
            elsif ( $t_lemma =~ m/^#(?:Idph|Forn)$/ ) {
                $nodetype = "list";
            }
            elsif ( $functor =~ m/^[FD]PHR$/ ) {
                $nodetype = lc $functor;
            }
            elsif ( $t_lemma =~ m/^#(?:AsMuch|Cor|EmpVerb|Equal|Gen|Oblfm|QCor|Rcp|Some|Total|Unsp|Amp|Ast|Percnt|Bracket|Comma|Colon|Dash|Period|Period3|Slash)$/ ) {
                $nodetype = 'qcomplex';
            }
            else {
                $nodetype = 'complex';
            }

            $t_node->set_attr( 'nodetype', $nodetype );

        }

    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Assign_nodetype

Value of the C<nodetype> attribute is filled (accordingly to the value of C<functor> and C<t_lemma>)
    in each SEnglishT node.

    =back
    =cut

    # Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
