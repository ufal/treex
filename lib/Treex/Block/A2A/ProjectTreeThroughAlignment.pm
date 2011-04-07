package SxxM_to_SxxA::Project_tree_through_alignment;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $LANGUAGE = $self->get_parameter('LANGUAGE') or die "Parameter LANGUAGE required";
    my $PROJECT_TAGS = $self->get_parameter('PROJECT_TAGS') or undef;
    my $en_tree = $bundle->get_tree('SEnglishA');
    my $xx_tree = $bundle->get_tree("S${LANGUAGE}A");
    foreach my $xx_node ($xx_tree->get_descendants) {
        $xx_node->set_parent($xx_tree);
    }
    foreach my $xx_node ($xx_tree->get_descendants) {
        my $prev_node = $xx_node->get_prev_node();
        $xx_node->set_parent($prev_node) if $prev_node;
        $xx_node->set_attr('m/tag', 'NW') if $PROJECT_TAGS;
    }
    my %parent_is_set = ();

    my %linked_to;
    my @counterparts;

    # add counterparts from intersection alignment
    foreach my $en_node ($en_tree->get_descendants({ordered => 1})) {
        my $ord = $en_node->get_attr('ord');
        my $links = $en_node->get_attr('m/align/links');
        my ($int_node) = map { $bundle->get_document->get_node_by_id($_->{'counterpart.rf'}) } grep { $_->{'type'} =~ /int/ } @$links;
        next if !$int_node;
        push @{$counterparts[$ord]}, $int_node;
        $linked_to{$int_node} = $en_node;
    }

    # add other counterparts from gdfa and then from right alignment
    foreach my $en_node ($en_tree->get_descendants({ordered => 1})) {
        my $ord = $en_node->get_attr('ord');
        my $links = $en_node->get_attr('m/align/links');
        my @right_nodes = map { $bundle->get_document->get_node_by_id($_->{'counterpart.rf'}) } grep { $_->{'type'} =~ /gdfa/ && $_->{'type'} !~ /int/ && $_->{'type'} =~ /right/ } @$links;
        my @gdfa_nodes = map { $bundle->get_document->get_node_by_id($_->{'counterpart.rf'}) } grep { $_->{'type'} !~ /gdfa/ && $_->{'type'} =~ /right/ } @$links;
    
        my $count = 0;
        $count++ if $counterparts[$ord];
        $count += scalar @gdfa_nodes;
        $count += scalar @right_nodes;

        foreach my $en_node2 ($en_tree->get_descendants({ordered => 1})) {
            my $ord2 = $en_node2->get_attr('ord');
            my $links2 = $en_node2->get_attr('m/align/links');
            if (@$links2 == 1 && $links2->[0]->{'type'} =~ /gdf/ && $links2->[0]->{'type'} !~ /right/) { #zmeneno z gdfa na gdf
                foreach my $xx_node (@right_nodes, @gdfa_nodes) {
                    if ($xx_node eq $bundle->get_document->get_node_by_id($links2->[0]->{'counterpart.rf'}) && $count > 1) {
                        $count--;
                        push @{$counterparts[$ord2]}, $xx_node if !$linked_to{$xx_node};
                        $linked_to{$xx_node} = $en_node2;
                    }
                }
            }
        }
        foreach my $xx_node (@gdfa_nodes, @right_nodes) {
            push @{$counterparts[$ord]}, $xx_node if !$linked_to{$xx_node};
            $linked_to{$xx_node} = $en_node;
        }
    }

    project_subtree($bundle, $en_tree, $xx_tree, \%parent_is_set, \@counterparts, $PROJECT_TAGS);

}

sub project_subtree {
    my ($bundle, $en_root, $xx_parent, $parent_is_set, $counterparts, $PROJECT_TAGS) = @_;
    foreach my $en_node ($en_root->get_children({ordered => 1})) {
        my $ord = $en_node->get_attr('ord');
        my @other_xx_nodes = @{$$counterparts[$ord]} if $$counterparts[$ord];
        my $main_xx_node = shift @other_xx_nodes if @other_xx_nodes;

        if ($main_xx_node) {
            if (!$$parent_is_set{$main_xx_node}) {
                $main_xx_node->set_parent($xx_parent);
                if ($PROJECT_TAGS) {
                    my $en_tag = $en_node->get_attr('m/tag');
                    $en_tag =~ s/^(..).*$/$1/;
                    $main_xx_node->set_attr('m/tag', $en_tag);
                }
                $$parent_is_set{$main_xx_node} = 1;
            }

            foreach my $xx_node (@other_xx_nodes) {
                next if $xx_node eq $main_xx_node;
                if (!$$parent_is_set{$xx_node}) {
                    $xx_node->set_parent($main_xx_node);
                    $xx_node->set_attr('conll_deprel', 'new_node');
                    $$parent_is_set{$xx_node} = 1;
                }

            }
            project_subtree($bundle, $en_node, $main_xx_node, $parent_is_set, $counterparts, $PROJECT_TAGS);
        }
        else {
            project_subtree($bundle, $en_node, $xx_parent, $parent_is_set, $counterparts, $PROJECT_TAGS);
        }
    }
}

1;

=over

=item SxxM_to_SxxA::Project_tree_through_alignment

=back

English dependency tree is projected through word alignment to the language defined by parameter LANGUAGE.
This block requires already built target analytical-tree (use SxxM_to_SxxA::Clone_atree) and
the word alignment on a-layer (use Align_SxxA_SyyA::Insert_word_alignment) including left, right, gdf,
gdfa and int symmetrizations.

Required parameter: LANGUAGE
Other parameters: PROJECT_TAGS=1 if you want to project also the English tags into the target language

=cut

# Copyright 2010 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
