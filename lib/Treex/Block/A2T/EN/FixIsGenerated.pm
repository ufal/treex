package SEnglishA_to_SEnglishT::Fix_is_generated;

use 5.008;
use warnings;
use strict;

use base qw(TectoMT::Block);

use TBLa2t::Common;

#======================================================================

sub repair_is_generated
{
    my ($t_root) = @_;
    my %a2t = ();

    for my $t_node ( $t_root->get_descendants ) {
        push @{ $a2t{ $t_node->get_attr('a/lex.rf') } }, $t_node if $t_node->get_attr('a/lex.rf') && !$t_node->get_attr('is_generated');
    }
    for my $a_id ( keys %a2t ) {
        my $list = \@{ $a2t{$a_id} };
        @$list > 1 or next;
        info "Non-generated nodes with a-id $a_id: ", join( ', ', map { $_->get_attr('id') } @$list ), " -- ";
        map { $_->set_attr( 'is_generated', 1 ) } @$list;
        my $non_generated = $list->[0];
        for my $t_node ( grep { $_->get_attr('id') =~ /s[0-9]+-t[0-9]+$/ } @$list ) {
            $non_generated = $t_node;
            last;
        }
        $non_generated->set_attr( 'is_generated', undef );
        info $non_generated->get_attr('id'), " left non-generated, the others set generated\n";
    }
}

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;

    for my $bundle ( $document->get_bundles ) {
        repair_is_generated( $bundle->get_tree('SEnglishT') );
    }
}

1;

=over

=item SEnglishA_to_SEnglish::Fix_is_generated

The block tries to fix values of the is_generated attribute. It sets the attribute for all but one nodes with a/lex.rf references to the same node. The node the attribute is unset for is chosen according to its id.

=back

=cut

# Copyright 2009 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
