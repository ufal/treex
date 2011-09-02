package Treex::Core::BundleZone;

use Moose;
use Treex::Core::Common;
use MooseX::NonMoose;

use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;

extends 'Treex::Core::Zone';

sub _set_bundle {
    my $self = shift;
    my ($bundle) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Bundle' },
    );
    $self->set_attr( '_bundle', $bundle );
    weaken $self->{'_bundle'};
    return;
}

sub get_bundle {
    my $self = shift;
    return $self->get_attr('_bundle');
}

sub get_document {
    my $self = shift;
    return $self->get_bundle->get_document;
}

sub create_atree {
    my $self = shift;
    return $self->create_tree('a');
}

sub create_ttree {
    my $self = shift;
    return $self->create_tree('t');
}

sub create_ntree {
    my $self = shift;
    return $self->create_tree('n');
}

sub create_ptree {
    my $self = shift;
    return $self->create_tree('p');
}

sub create_tree {
    my $self = shift;
    my ($layer) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Layer' },
    );
    log_fatal("Zone already contains tree at $layer layer") if $self->has_tree($layer);
    my $class = "Treex::Core::Node::" . uc($layer);
    my $tree_root = eval { $class->new( { _called_from_core_ => 1 } ) } or log_fatal $!;    #layer subclasses not available yet

    my $bundle = $self->get_bundle;
    $tree_root->_set_zone($self);

    my $new_tree_name = lc($layer) . "_tree";
    $self->{trees}->{$new_tree_name} = $tree_root;

    my $new_id = "$new_tree_name-" . $self->get_label . "-" . $bundle->get_id . "-root";
    $tree_root->set_id($new_id);

    # pml-typing
    #$tree_root->set_type_by_name( $self->get_document->metaData('schema'), lc($layer) . '-root.type' );
    $tree_root->set_type_by_name( $self->get_document->metaData('schema'), $tree_root->get_pml_type_name() );

    # vyresit usporadavaci atribut!
    # TODO: if $tree_root->does('Treex::Core::Role::OrderedTree')
    my $ordering_attribute = $tree_root->get_ordering_member_name;
    if ( defined $ordering_attribute ) {
        $tree_root->set_attr( $ordering_attribute, 0 );
    }

    return $tree_root;
}

sub remove_tree {
    my $self = shift;
    my ($layer) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Layer' },
    );

    # remove all nodes ($tree_root->remove does not work, in order to not be used by users)
    my $tree_root = $self->get_tree($layer);
    foreach my $child ( $tree_root->get_children() ) {
        $child->remove();
    }
    if ( $tree_root->id ) {
        $self->get_document->index_node_by_id( $tree_root->id, undef );
    }
    delete $self->{trees}{ lc($layer) . '_tree' };
    return;
}

sub get_tree {
    my $self = shift;
    my ($layer) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Layer' },
    );

    my $tree_name = lc($layer) . "_tree";
    my $tree      = $self->{trees}->{$tree_name};

    if ( not defined $tree ) {
        log_fatal( "No $tree_name available in the bundle, bundle id=" . $self->get_attr('id') );
    }
    return $tree;
}

sub get_atree {
    my $self = shift;
    return $self->get_tree('a');
}

sub get_ttree {
    my $self = shift;
    return $self->get_tree('t');
}

sub get_ntree {
    my $self = shift;
    return $self->get_tree('n');
}

sub get_ptree {
    my $self = shift;
    return $self->get_tree('p');
}

sub has_tree {
    my $self = shift;
    my ($layer) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Layer' },
    );
    my $tree_name = lc($layer) . "_tree";
    return defined $self->{trees}->{$tree_name};
}

sub has_atree {
    my $self = shift;
    return $self->has_tree('a');
}

sub has_ttree {
    my $self = shift;
    return $self->has_tree('t');
}

sub has_ntree {
    my $self = shift;
    return $self->has_tree('n');
}

sub has_ptree {
    my $self = shift;
    return $self->has_tree('p');
}

sub get_all_trees {
    my $self = shift;

    return grep {defined}
        map     { $self->{trees}->{ $_ . "_tree" }; } qw(a t n p);
}

sub sentence {
    my $self = shift;
    return $self->get_attr('sentence');
}

sub set_sentence {
    my $self = shift;
    my ($text) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );
    return $self->set_attr( 'sentence', $text );
}

sub copy {
    my $self      = shift;
    my $selector1 = shift;

    # Get the bundle the zone is in.
    my $bundle = $self->get_bundle();
    my $zone1 = $bundle->get_or_create_zone( $self->language(), $selector1 );
    ### TO DO: copy other trees, too (currently only copies the a-tree)
    my $aroot0 = $self->get_atree();
    my $aroot1 = $zone1->create_atree();
    $aroot0->copy_atree($aroot1);
    return $zone1;
}

1;

__END__

=for Pod::Coverage set_sentence

=encoding utf-8

=head1 NAME

Treex::Core::BundleZone - contains a sentence and its linguistic representations

=head1 SYNOPSIS

 use Treex::Core;
 my $doc = Treex::Core->new;
 my $bundle = $doc->create_bundle();
 my $zone = $bundle->create_zone('en','reference');
 $zone->set_sentence('John loves Mary.');


=head1 DESCRIPTION

Document zones allow Treex documents to contain more texts,
typically parallel texts (translations), or corresponding
texts from different sources (text to be translated, reference
translation, test translation).

=head1 ATTRIBUTES

C<Treex::Core::BundleZone> instances have the following attributes:

=over 4

=item language

=item selector

=item sentence

=back

The attributes can be accessed using semi-affordance accessors: getters have
the same names as attributes, while setters start with C<set_>. For example,
the attribute C<sentence> has a getter C<sentence()> and a setter
C<set_sentence($sentence)>


=head1 METHODS

=head2 Construction

C<Treex::Core::BundleZone> instances should not be created by the constructor,
but should be created exclusively by calling one of the following methods
of the embedding  L<Treex::Core::Bundle> instance:

=over 4

=item create_zone

=item get_or_create_zone

=back


=head2 Access to trees

There are four types of linguistic trees distinguished in Treex, each of them represented
by one letter: I<a> - analytical treex, I<t> - tectogrammatical trees, I<p> - phrase-structure trees,
I<n> - named entity trees. You can create trees by following methods:

=over 4

=item $zone->create_tree($layer);

=item $zone->create_atree();

=item $zone->create_ttree();

=item $zone->create_ptree();

=item $zone->create_ntree();

=back


You can access trees by

=over 4

=item $zone->get_tree($layer);

=item $zone->get_atree();

=item $zone->get_ttree();

=item $zone->get_ptree();

=item $zone->get_ntree();

=item $zone->get_all_trees();

=back


Presence of a tree of a certain type can be detected by

=over 4

=item $zone->has_tree($layer);

=item $zone->has_atree();

=item $zone->has_ttree();

=item $zone->has_ptree();

=item $zone->has_ntree();

=back


You can remove trees by

=over 4

=item $zone->remove_tree($layer);

=back


=head2 Access to embedding objects

=over 4

=item $bundle = $zone->get_bundle();

returns the L<Treex::Core::Bundle> instance which the zone belongs to

=item $doc = $zone->get_document();

returns the L<Treex::Core::Document> instance which the zone belongs to

=back


=head2 Other

=over 4

=item $zone1 = $zone0->copy($selector1);

creates a copy of the zone (currently copies only the a-tree) under the same language and a new selector

=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
