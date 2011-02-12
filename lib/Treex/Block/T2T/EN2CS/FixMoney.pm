package SEnglishT_to_TCzechT::Fix_money;

use utf8;
use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %CURRENCY = (
    '$'   => 'dolar',
    'HUF' => 'forint',
    '£'   => 'libra',
);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $t_node ( $t_root->get_descendants() ) {

        if ( $CURRENCY{ $t_node->get_attr('t_lemma') } ) {

            # rehang the currency node 
            my $value_tnode = $t_node->get_children( { following_only => 1, first_only => 1 } );
            if ( $value_tnode ) {
                foreach my $child ($t_node->get_children) {
                    $child->set_parent($value_tnode) if $child ne $value_tnode;
                }
                $value_tnode->set_parent($t_node->get_parent);
                $t_node->set_parent($value_tnode);
                $value_tnode->set_attr('formeme', $t_node->get_attr('formeme'));
            }
            
            # change t_lemma and formeme of the currency node
            $t_node->set_attr('t_lemma', $CURRENCY{ $t_node->get_attr('t_lemma') } );
            $t_node->set_attr('t_lemma_origin', 'rule-Fix_money');
            $t_node->set_attr('formeme', 'n:2');
            $t_node->set_attr('formeme_origin', 'rule-Fix_money');
            $t_node->set_attr('gram/number', 'pl');

            # shift the currency after nodes expressing value (numbers, million, billion, m)
            my $next_node = $t_node->get_next_node;
            my $last_value_node;
            while ($next_node && $next_node->get_attr('t_lemma') =~ /^([\d,\.\ ]+|mili[oó]n|miliarda|m)$/) {
                $last_value_node = $next_node;
                $next_node = $next_node->get_next_node;
            }
            $t_node->shift_after_node($last_value_node) if defined $last_value_node;
        }
    }
    return;
}

1;

=over

=encoding utf8

=item SEnglishT_to_TCzechT::Money

=back

=cut

# Copyright 2010 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
