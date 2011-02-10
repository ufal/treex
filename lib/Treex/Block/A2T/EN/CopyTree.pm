package SEnglishA_to_SEnglishT::Build_ttree;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub aux_to_parent($) {
    my ($a_node) = shift;
    return (
        $a_node->get_attr('is_aux_to_parent')
            or ( $a_node->get_attr('parent_is_aux') )    #hack kvuli nahore visicim mod.slov, zkomplikovano viceslov. spojkami
            or ( aux_to_child( $a_node->get_parent ) and parent_is_aux( $a_node->get_parent ) )    # kvuli 'have to' (vyznamove prijde sice do aux, ale to se pozdeji opravi)
    );
}

sub aux_to_child($) {
    my ($a_node) = shift;
    return $a_node->get_attr('is_aux_to_child');
}

sub parent_is_aux($) {
    my ($a_node) = shift;
    return $a_node->get_attr('parent_is_aux');
}

sub asubtree_2_tsubtree {
    my ( $a_root, $t_parent ) = @_;
    my @a_children = $a_root->get_children();

    #  my $absorbing_child = grep {absorb_parent($_)} @a_children;
    #    print "************new t-node: $a_root @a_children\n";

    if ( not aux_to_parent($a_root) and not aux_to_child($a_root) ) {

        my $t_new_node = $t_parent->create_child;

        foreach my $a_child (@a_children) {
            asubtree_2_tsubtree( $a_child, $t_new_node );
        }

        # setting references to a-layer nodes
        $t_new_node->set_attr( 'a/lex.rf', $a_root->get_attr('id') );
        my $grandpa = $a_root->get_parent->get_parent;
        my @aux_nodes_rf = map { $_->get_attr('id') }
            (

            #(grep {aux_to_parent($_)} @a_children),  # nahradit efektivnima detma!!!
            ( grep { aux_to_child($_) } ( $a_root->get_parent ) ),    # nahradit efektivnim rodicem!!!
            ( ( $grandpa and aux_to_child( $a_root->get_parent ) and aux_to_child($grandpa) ) ? ($grandpa) : () )    # plus prarodic, pokud je mezilehly uzel taky schovavaci
            );

        if ( aux_to_child( $a_root->get_parent ) ) {                                                                 # specialita kvuli because_of
            push @aux_nodes_rf, map { $_->get_attr('id') }
                grep { $_ ne $a_root and aux_to_parent($_) } $a_root->get_parent->get_children;
        }
        my $orig_aux_rf = $t_new_node->get_attr('a/aux.rf');
        $t_new_node->set_attr( 'a/aux.rf', defined $orig_aux_rf ? [ @aux_nodes_rf, @{$orig_aux_rf} ] : \@aux_nodes_rf );

    }

    else {
        if ( aux_to_parent($a_root) and not( aux_to_child( $a_root->get_parent ) and not parent_is_aux( $a_root->get_parent ) ) ) {    #jinak by se zaradil dvakrat
            my $parent_aux_rf = $t_parent->get_attr('a/aux.rf');
            $t_parent->set_attr( 'a/aux.rf', defined $parent_aux_rf ? [ $a_root->get_attr('id'), @{$parent_aux_rf} ] : [ $a_root->get_attr('id') ] );

            #print STDERR $a_root->get_attr('id') . "->" . $t_parent->get_attr('id') . "\n";
        }

        foreach my $a_child (@a_children) {
            asubtree_2_tsubtree( $a_child, $t_parent );
        }
    }
}

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $a_aux_root = $bundle->get_tree('SEnglishA');
        my @a_children = $a_aux_root->get_children();
        my ($a_root) = grep { not aux_to_parent($_) } @a_children;    # there should be always only one child
        if ( not defined $a_root ) {
            $a_root = $a_children[0];
        }

        next if !defined $a_root; # gracefully handle bad sentences

        #    print "\n\nYY: a_root form".$a_root->get_attr('m/form')."\n";

        my $t_root = $bundle->create_tree( 'SEnglishT' );

        my $root_id = $a_aux_root->get_attr('id');

        #    print "aroot id: ".($a_root->get_attr('id'))."\n";
        $root_id =~ s/EnglishA/EnglishT/ or Report::fatal("root id $root_id does not match the expected regexp!");
        $t_root->set_attr( 'id',       $root_id );
        $t_root->set_attr( 'deepord',  0 );
        $t_root->set_attr( 'atree.rf', $a_aux_root->get_attr('id') );

        asubtree_2_tsubtree( $a_root, $t_root, [] );

        # postprocessing
        foreach my $t_node ( $t_root->get_descendants ) {

            # oprava u modalnich sloves: do lex patri vyznamove sloveso (a ne modalni), i kdyz bylo v a-stromu dole
            my ($aux_should_be_lex) = grep { $_->get_attr('parent_is_aux') } $t_node->get_aux_anodes();
            if ($aux_should_be_lex) {
                $t_node->set_attr(
                    'a/aux.rf',
                    [   $t_node->get_attr('a/lex.rf'),
                        map { $_->get_attr('id') } grep { $_ != $aux_should_be_lex } $t_node->get_aux_anodes
                    ]
                );
                $t_node->set_attr( 'a/lex.rf', $aux_should_be_lex->get_attr('id') );

                #	$t_node->set_attr('t_lemma','modal!!!');
            }

            # specialni fix kvuli 'have to'
            if ( $t_node->get_lex_anode->get_attr('m/lemma') eq "to" ) {
                my ($last_verb_anode) = sort { $b->get_attr('ord') <=> $a->get_attr('ord') }
                    grep { $_->get_attr('m/tag') =~ /^V/ } $t_node->get_aux_anodes;
                if ($last_verb_anode) {
                    $t_node->set_attr(
                        'a/aux.rf',
                        [   $t_node->get_attr('a/lex.rf'),
                            map { $_->get_attr('id') } grep { $_ != $last_verb_anode } $t_node->get_aux_anodes
                        ]
                    );
                    $t_node->set_attr( 'a/lex.rf', $last_verb_anode->get_attr('id') );
                }
            }

            my $a_lex_node = $t_node->get_lex_anode();

            my $mlemma = $a_lex_node->get_attr('m/lemma');

            #      $mlemma =~ s /[\-\_\`](.+)$//;
            $t_node->set_attr( 't_lemma', $mlemma );

            my $id = $a_lex_node->get_attr('id');
            $id =~ s/EnglishA/EnglishT/;
            $t_node->set_attr( 'id', $id );

            $t_node->set_attr( 'deepord', $a_lex_node->get_attr('ord') );

        }

    }

}

1;

=over

=item SEnglishA_to_SEnglishT::Build_ttree

For each bundle, a skeleton of the tectogrammatical tree is created (and stored as EnglishT tree)
by recursive collapse of the English tree (merging functional words with the autosemantic ones etc.).
In each new SEnglishT node, references to the source SEnglishA nodes are stored in the C<a/lex.rf> and C<a/aux.rf>
attributes. Also attributes C<id>, C<t_lemma>, and C<deepord> are (preliminarly) filled.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
