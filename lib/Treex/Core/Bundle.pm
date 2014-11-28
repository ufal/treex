package Treex::Core::Bundle;

use namespace::autoclean;

use Moose;
use Treex::Core::Common;
use MooseX::NonMoose;

extends 'Treex::PML::Node';
with 'Treex::Core::WildAttr';

has document => (
    is       => 'ro',
    writer   => '_set_document',
    reader   => 'get_document',
    weak_ref => 1,
);

has id => ( is => 'rw' );

use Treex::Core::Node;
use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;
use Treex::Core::Node::P;
use Treex::Core::BundleZone;

use Treex::Core::Log;

# --------- ACCESS TO ZONES ------------

sub BUILD {
    log_fatal 'Because of node indexing, no bundles can be created outside of documents. '
        . 'You have to use $document->create_bundle() instead of $bundle->new().';

}

sub get_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
    );
    if ( defined $self->{zones} ) {
        foreach my $element ( $self->{zones}->elements ) {
            my ( undef, $value ) = @$element;    # $name is not needed
            if (( $value->{language} eq $language or $language eq 'mul' )
                and ( $value->{selector} || '' ) eq $selector
                )
            {
                return $value;
            }
        }
    }
    return;
}

sub create_zone {
    my $self = shift;
    my ( $language, $selector, $params_rf ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
        { isa => 'Ref' },
    );

    if ( $self->get_zone( $language, $selector ) ) {
        if (defined $params_rf and $params_rf->{overwrite}) {

        }
        else {
            log_fatal("Bundle already contains a zone with language='$language' and selector='$selector'. "
                          . "Use create_zone(...,{overwrite=>1}) to remove it first.")
        }
    }



    my $new_zone = Treex::Core::BundleZone->new(
        {
            'language' => $language,
            'selector' => $selector,
        }
    );

    my $new_element = Treex::PML::Seq::Element->new( 'zone', $new_zone );

    $new_zone->_set_bundle($self);

    #    $new_subbundle->set_type_by_name( $self->get_document->metaData('schema'), 'zone' );

    if ( defined $self->{zones} ) {
        $self->{zones}->unshift_element_obj($new_element);
    }
    else {
        $self->{zones} = Treex::PML::Seq->new( [$new_element] );
    }

    return $new_zone;
}

sub get_or_create_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
    );
    my $zone = $self->get_zone( $language, $selector );
    if ( !defined $zone ) {
        $zone = $self->create_zone( $language, $selector );
    }
    return $zone;
}

sub get_all_zones {
    my $self = shift;
    if ( $self->{zones} ) {
        return map { $_->value() } $self->{zones}->elements;
    }
    else {
        return ();
    }
}

sub remove_zone {
    my ( $self, $language, $selector ) = @_;

    my $zone = $self->get_zone( $language, $selector );
    if ( !$zone ) {
        log_fatal "Non-existing zone cannot be removed";
    }

    # remove all trees first, so that their nodes are correctly removed from the index
    foreach my $tree ( $zone->get_all_trees ) {
        $zone->remove_tree( $tree->get_layer );
    }

    $self->{zones}->delete_value($zone)
        or log_fatal "Zone to be deleted was not found. This should never happen";
    return;
}

sub remove {
    my ( $self ) = @_;

    # clean the bundle's content first (to ensure de-indexing)
    foreach my $zone ( $self->get_all_zones ) {
        $self->remove_zone( $zone->language, $zone->selector );
    }

    my $position = 0;

    # find the bundle's position (this is quite inefficient, as the info about
    # bundle's position is stored nowhere), and delete the bundle using Treex::PML API
  BUNDLE:
    foreach my $bundle ( $self->get_document->get_bundles ) {
        if ( $bundle eq $self ) {
            last BUNDLE;
        }
        else {
            $position++;
        }
    }

    $self->get_document->delete_tree($position);
    bless $self, 'Treex::Core::Node::Removed';
    return;
}


# --------- ACCESS TO TREES ------------

sub get_all_trees {
    my $self = shift;
    if ($Treex::Core::Config::params_validate) {    ## no critic (ProhibitPackageVars)
        pos_validated_list( \@_ );
    }

    return () if !$self->{zones};

    my @trees;
    foreach my $zone ( $self->{zones}->elements ) {
        my $structure = $zone->value;
        foreach my $layer (Treex::Core::Types::layers()) {
            $layer = lc $layer;
            if ( exists $structure->{trees}->{"${layer}_tree"} ) {
                push @trees, $structure->{trees}->{"${layer}_tree"};
            }
        }
    }
    return @trees;

}

sub create_tree {
    my $self = shift;
    my ( $language, $layer, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Layer' },
        { isa => 'Treex::Type::Selector', default => '' }
    );

    my $zone = $self->get_or_create_zone( $language, $selector );
    my $tree_root = $zone->create_tree($layer);
    return $tree_root;
}

sub get_tree {
    my $self = shift;
    my ( $language, $layer, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Layer' },
        { isa => 'Treex::Type::Selector', default => '' }
    );

    my $zone = $self->get_zone( $language, $selector );
    log_fatal "Unavailable zone for selector=$selector language=$language\n" if !$zone;
    return $zone->get_tree($layer);
}

sub has_tree {
    my $self = shift;
    my ( $language, $layer, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Layer' },
        { isa => 'Treex::Type::Selector', default => '' }
    );
    my $zone = $self->get_zone( $language, $selector );
    return defined $zone && $zone->has_tree($layer);
}

sub get_position {
    my ($self) = @_;

    # search for position of the bundle
    # (ineffective, because there's no caching of positions of bundles so far)
    my $position_of_reference;
    my $fsfile = $self->get_document->_pmldoc;
    foreach my $position ( 0 .. $fsfile->lastTreeNo ) {
        if ( $fsfile->tree($position) eq $self ) {
            $position_of_reference = $position;
            last;
        }
    }

    if ( !defined $position_of_reference ) {
        log_fatal "document structure inconsistency: can't detect position of bundle $self";
    }

    return $position_of_reference;
}

# --------- ACCESS TO ATTRIBUTES ------------

sub get_attr {
    my $self = shift;
    my ($attr_name) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );
    return $self->{$attr_name};
}

# ------- other -------------

sub following {
    return Treex::Core::Node::following(@_);
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=for Pod::Coverage BUILD set_attr get_attr

=encoding utf-8

=head1 NAME

Treex::Core::Bundle - a set of equivalent sentences in the Treex framework

=head1 DESCRIPTION

A set of equivalent sentences (translations, or variants) and their linguistic representations in the Treex framework
A bundle in Treex corresponds to one sentence or more sentences, typically 
translations or variants of each other, with all their linguistic 
representations. Each bundle is divided into zones (instances of 
L<Treex::Core::BundleZone>), each of them containing 
exactly one sentence and its representations.

=head1 ATTRIBUTES

Each bundle has two attributes:

=over 4

=item id

identifier accessible by the getter method C<id()> and by the setter method 
C<set_id($id)>

=item document

the document (an instance of L<Treex::Core::Document>) 
which this bundle belongs to; accessible only by the getter method C<document()>

=back



=head1 METHODS

=head2 Construction

You cannot create a bundle by a constructor from scratch. You can create a 
bundle only within an existing documents, using the following methods of 
L<Treex::Core::Document>:

=over 4

=item create_bundle

=item new_bundle_before

=item new_bundle_after

=back


=head2 Access to zones

Bundle zones are instances of 
L<Treex::Core::BundleZone>, parametrized by language 
code and possibly also by another free label called selector, whose purpose is 
to distinguish zones for the same language but from a different source.

=over 4

=item my $zone = $bundle->create_zone( $langcode, ?$selector, ?$params_rf );

If the third argument is {overwrite=>1}, then the newly created empty zone
overwrites the previously existing one (if any). Fatal error appears if
the zone to be created already exists and this switch is not used.

=item my $zone = $bundle->get_zone( $langcode, ?$selector );

=item my $zone = $bundle->get_or_create_zone( $langcode, ?$selector );

=item my @zones = $bundle->get_all_zones();

=back


=head2 Access to trees

Even if trees are not contained directly in bundle (there is the intermediate 
zone level), they can be accessed using the following shortcut methods:

=over 4

=item my $tree_root = $bundle->get_tree( $language, $layer, ?$selector);


=item my $tree_root = $bundle->create_tree( $language, $layer, ?$selector );


=item $bundle->has_tree( $language, $layer, ?$selector );


=item my @tree_roots = $bundle->get_all_trees();

=back



=head2 Other

=over 4

=item $bundle->remove_zone( $language, $selector );

delete all zone's trees and remove the zone from the bundle

=item my $position = $bundle->get_position();

position of the bundle within the document (number, starting from 0)

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
