#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Node') }
use Treex::Core::Document;
my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone( 'cs', 'S' );

foreach my $layer (qw( A T N P )) {
    note("############ $layer-layer ############");
    $zone->create_tree($layer);

    #is( $bundle->get_zone( 'cs', 'S' )->get_tree($layer), $bundle->get_tree("Scs$layer"), 'Tree can be obtained via zone or directly and result is same' ); # not supported

    my $root    = $zone->get_tree($layer);
    my $ordered = $root->does('Treex::Core::Node::Ordered');
    isa_ok( $root, 'Treex::Core::Node' );
    isa_ok( $root, "Treex::Core::Node::$layer" );
    my $attributes = {
        'lemma' => 'house',
        'tag'   => 'NN',
    };
    my $node = $root->create_child($attributes);
    isa_ok( $node, 'Treex::Core::Node' );

    isa_ok( $node->get_bundle(),   'Treex::Core::Bundle' );
    isa_ok( $node->get_document(), 'Treex::Core::Document' );
    isa_ok( $node->get_zone(),     'Treex::Core::BundleZone' );
    is( uc( $node->get_layer ), $layer, 'get_layer returns node type' );

    $node->shift_after_node($root) if $ordered;

    #Attributes
    my $name  = 'Name';
    my $value = 'VALUE';
    $node->set_attr( $name, $value );
    cmp_ok( $node->get_attr($name), 'eq', $value, 'Just setted attribute' );
    is_deeply( $node->get_attr('attributes'), $attributes->{'attributes'}, 'Attributes setted in constructor' );    # || note(explain($attributes->{$_}));
    ok( !defined( $node->get_attr('ooo') ), 'Undefined attr is not defined' );

    note('TODO deref attrs');

    #Topology
    ok( !defined( $root->get_parent() ), '$root has no parent' );
    is( $node->get_parent(), $root, 'Parent of $node is $root' );
    is( $node->get_root(),   $root, q($node's root is $root) );
    ok( !$node->is_root(),              q($node isn't root) );
    ok( $root->is_root(),               '$root is root' );
    ok( $node->is_descendant_of($root), '$node is descendant of $root' );

    cmp_ok( scalar $root->get_children(),    '==', 1, '$root has 1 child' );
    cmp_ok( scalar $root->get_descendants(), '==', 1, '$root has 1 descendant' );
    cmp_ok( scalar $node->get_children(),    '==', 0, '$node has no children' );
    cmp_ok( scalar $node->get_descendants(), '==', 0, '$node has no descendant' );
    my @children = $root->get_children();
    is( $children[0], $node, q($node is first $root's child) );
    my @descendants = $root->get_descendants();
    is( $descendants[0], $node, q($node is first $root's descendant) );
    ok( !$root->get_siblings(), '$root has no siblings' );
    ok( !$node->get_siblings(), '$node has no siblings' );

    my $c1 = $root->create_child();
    my $c2 = $root->create_child();
    my $c3 = $root->create_child();
    my $c4 = $root->create_child();
    if ($ordered) {
        $c1->shift_before_node($root);
        $c2->shift_after_node($node);
        $c3->shift_before_node($node);
        $c4->shift_after_node($root);
    }
    foreach ( $root->get_children() ) {
        if ( $_ != $node ) {
            my $tmp = $_->create_child();
            $tmp->shift_after_node($_) if $ordered;
        }
    }
    my $cc1 = $node->create_child();
    my $cc2 = $node->create_child();
    if ($ordered) {
        $cc1->shift_before_node($node);
        $cc2->shift_after_node($node);
    }

    cmp_ok( scalar $root->get_children(),    '==', 5,  '$root now has 5 children' );
    cmp_ok( scalar $root->get_descendants(), '==', 11, '$root now has 11 descendants' );
    cmp_ok( eval { scalar $root->get_descendants( { add_self => 1 } ) }, '==', 12, '12 including itself' );
    cmp_ok( scalar $node->get_siblings(), '==', 4, '$node has 4 siblings' );
    cmp_ok( scalar $node->get_children(), '==', 2, '$node has 2 children' );

    $c3->remove();
    $cc2->remove();

    cmp_ok( scalar $root->get_children(),    '==', 4, '$root now has 4 children' );
    cmp_ok( scalar $root->get_descendants(), '==', 8, '$root now has 8 descendants' );
    cmp_ok( scalar $node->get_siblings(),    '==', 3, '$node has 3 siblings' );
    cmp_ok( scalar $node->get_children(),    '==', 1, '$node has 1 child' );

    # TODO: Calling methods on removed nodes should result in fatal errors. Let's test it.
    ok( !eval { $cs->create_child(); 1 }, "Calling methods on removed node should result in fatal errors." );

    #Node ordering
    if ($ordered) {
        my %ords;
        my $max = 0;
        foreach my $node ( $root->get_descendants( { ordered => 1, add_self => 1, } ) ) {
            my $value = $node->ord;
            ok( defined $value, 'Node ' . ( defined $node->id ? $node->id : 'WITHOUT ID' ) . ' has ordering value' );
            $max = $value if $value > $max;
            cmp_ok( ++$ords{$value}, '==', 1, q(and it's unique) );

        }

        foreach ( 0 .. $max ) {
            cmp_ok( $ords{$_} || 0, '==', 1, qq(There's exactly 1 node with ordering $_) );
        }

        ok( $root->precedes($node), 'Preceding predicate works' );

        #$root->set_attr( $root->ordering_attribute(), $node->get_ordering_value() + 1 ); #set_attr won't be supported
        #ok( $root->precedes($node), 'Preceding predicate still works, so it is immune to direct changes' );
    }

    #Reordering nodes
    #processing clauses
    #PML-related
    #other
    cmp_ok( $cc1->get_depth(),  '==', 2, '$cc1 is in depth 2' );
    cmp_ok( $c2->get_depth(),   '==', 1, '$c2 is in depth 1' );
    cmp_ok( $root->get_depth(), '==', 0, '$root is in depth 0' );

    #deprecated
}

done_testing();
