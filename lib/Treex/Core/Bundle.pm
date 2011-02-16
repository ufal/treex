package Treex::Core::Bundle;

use Moose;
use Treex::Moose;
use MooseX::NonMoose;
use MooseX::Params::Validate;

extends 'Treex::PML::Node';

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
use Treex::Core::BundleZone;

use Treex::Core::Log;

my @layers = qw(t a n);

# --------- ACCESS TO ZONES ------------

sub get_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list (
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector' },
    );
    if ( defined $self->{zones} ) {
        foreach my $element ( $self->{zones}->elements ) {
            my ( $name, $value ) = @$element;
            if ( $value->{language} eq $language and ( $value->{selector} || '' ) eq ( $selector || '' ) ) {
                return $value;
            }
        }
    }
    return;
}

sub create_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list (
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector' },
    );
    my $new_zone = Treex::Core::BundleZone->new(
        {
            'language' => $language,
            'selector' => ( $selector || '' )
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
    my ( $language, $selector ) = pos_validated_list (
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector' },
    );
    my $zone = $self->get_zone( $language, $selector );
    if ( not defined $zone ) {
        $zone = $self->create_zone( $language, $selector );
    }
    return $zone;
}

sub get_all_zones {
    my $self = shift;
    pos_validated_list ( \@_);
    return map { $_->value() } $self->{zones}->elements;
}

# --------- ACCESS TO TREES ------------

sub get_all_trees {
    my $self = shift;
    pos_validated_list (\@_);

    return () unless $self->{zones};

    my @trees;
    foreach my $zone ( $self->{zones}->elements ) {
        my $structure = $zone->value;
        foreach my $layer (@layers) {
            if ( exists $structure->{trees}->{"${layer}_tree"} ) {
                push @trees, $structure->{trees}->{"${layer}_tree"};
            }
        }
    }
    return @trees;

}

sub create_tree {
    my $self = shift;
    my ( $tree_name ) = pos_validated_list (
        \@_,
        { isa => 'Str' },
    );
    
	$tree_name =~ s/Czech/cs/;
    $tree_name =~ s/English/en/;
    $tree_name =~ s/M$/A/;

    if ( $tree_name =~ /([A-Z])([a-z]{2})([A-Z])$/ ) {
        my ( $selector, $language, $layer ) = ( $1, $2, $3 );
        my $zone = $self->get_or_create_zone( $language, $selector );
        my $tree_root = $zone->create_tree($layer);
        return $tree_root;
    }

    else {
        log_fatal "Tree name $tree_name not matching expected pattern";
    }
}

sub get_tree {
    my $self = shift;
    my ( $tree_name ) = pos_validated_list (
        \@_,
        { isa => 'Str' },
    );
    $tree_name =~ s/Czech/cs/;
    $tree_name =~ s/English/en/;
    $tree_name =~ s/M$/A/;
    if ( $tree_name !~ /([ST])([a-z]{2})([A-Z])/ ) {
        log_fatal("Tree name not structured approapriately (e.g.SenM): $tree_name");
    }

    else {
        my ( $selector, $language, $layer ) = ( $1, $2, $3 );
        my $zone = $self->get_zone( $language, $selector );
        if ( not defined $zone ) {
            log_fatal "Unavailable zone $selector$language\n";
        }

        return $zone->get_tree($layer);
    }
}

sub has_tree {
    my $self = shift;
    my ( $tree_name ) = pos_validated_list (
        \@_,
        { isa => 'Str' },
    );

    $tree_name =~ s/Czech/cs/;
    $tree_name =~ s/English/en/;
    $tree_name =~ s/M$/A/;

    if ( $tree_name !~ /([ST])([a-z]{2})([A-Z])/ ) {
        log_fatal("Tree name not structured approapriately (e.g.SenM): $tree_name");
    }

    else {
        my ( $selector, $language, $layer ) = ( $1, $2, $3 );

        my $zone = $self->get_zone( $language, $selector );

        return defined $zone && $zone->has_tree($layer);
    }

}

# --------- ACCESS TO ATTRIBUTES ------------

sub set_attr {
    my $self = shift;
    my ( $attr_name, $attr_value ) = pos_validated_list (
        \@_,
        { isa => 'Str' },
        { isa => 'Any' },
    );

    if ( $attr_name =~ /^(\S+)$/ ) {
        return Treex::PML::Node::set_attr( $self, $attr_name, $attr_value );
    }

    elsif ( $attr_name =~ /^([ST])([a-z]{2}) (\S+)$/ ) {
        my ( $selector, $language, $attr_name ) = ( $1, $2, $3 );
        my $zone = $self->get_or_create_zone( $language, $selector );
        return $zone->{$attr_name} = $attr_value;
    }

    else {
        log_fatal "Attribute name not structured approapriately (e.g.'Sar text'): $attr_name";
    }
}

sub get_attr {
    my $self = shift;
    my ( $attr_name ) = pos_validated_list (
        \@_,
        { isa => 'Str' },
    );

    if ( $attr_name =~ /^(\S+)$/ ) {
        return Treex::PML::Node::attr( $self, $attr_name );
    }

    elsif ( $attr_name =~ /^([ST])([a-z]{2}) (\S+)$/ ) {
        my ( $selector, $language, $attr_name ) = ( $1, $2, $3 );
        my $zone = $self->get_zone( $language, $selector );
        if ( defined $zone ) {
            return $zone->{$attr_name};
        }
        else {
            return;
        }
    }

    else {
        log_fatal "Attribute name not structured approapriately (e.g.'Sar sentence'): $attr_name";
    }
}

# ------ ACCESS MESSAGE BOARD ----------

sub leave_message {
    my $self = shift;
    my ( $message_text ) = pos_validated_list (
        \@_,
        { isa => 'Message' },
    );
    if ( $self->get_attr('message_board') ) {
        push @{ $self->get_attr('message_board') }, $message_text;
    }
    else {
        $self->set_attr( 'message_board', Treex::PML::List->new($message_text) );
    }
}

sub get_messages {
    my $self = shift;
    pos_validated_list (\@_);
    if ( $self->get_attr('message_board') ) {
        return @{ $self->get_attr('message_board') };
    }
    else {
        return ();
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

Treex::Core::Bundle


=head1 DESCRIPTION

A bundle in TectoMT corresponds to one sentence in its various forms/representations
(esp. its representations on various levels of language description, but also
possibly including its counterpart sentence from a parallel corpus, or its
automatically created translation, and their linguistic representations,
be they created by analysis / transfer / synthesis). Attributes can be
attached to a bundle as a whole.


=head1 METHODS

=head2 Construction

=over 4

=item  my $new_bundle = $doc->create_bundle;

Adds a new empty tree bundle to the end of the document.
Bundle constructor should be never called directly!

=back



=head2 Access to attributes

=over 4

=item my $value = $bundle->get_attr($name);

Returns the value of the bundle attribute of the given name.


=item $bundle->set_attr($name,$value);

Sets the given attribute of the bundle with the given value.

=back



=head2 Access to the subsumed trees

=over 4

=item my $root_node = $bundle->get_tree($tree_name);

Returns the TectoMT::Node object which is the root of
the tree named $tree_name. Fatal error is caused if
no tree of the given name is present in the bundle.


=item $bundle->create_tree($tree_name);

Creates a new tree of the type $tree_name in the bundle.


=item $bungle->contains_tree($tree_name);

Returns true if a tree of the given name is present
in the budnle.

=item $bundle->get_tree_names();

Returns alphabetically sorted array of names of trees
contained in the bundle.

=item $bundle->get_all_trees();

Returns the root nodes of all trees in the bundle.

=back


=head2 Access to generic attributes and trees

Besides trees and bundle attributes with names statically predefined in the TectoMT
pml schema (such as 'SCzechT' or 'czech_source_sentence'), one can
use generic attributes and trees, which are parametrizable by
language (using ISO 639 codes) and direction (S for source, T for target).
Tree names then look e.g. like 'SarA' (source-side arabic analytical tree).
Attribute names look like 'Sar sentence' (source-side arabic sentence).


=over 4

=item my $value = $bundle->get_generic_attr($name);

=item $bundle->set_generic_attr($name,$value);

=item my $root_node = $bundle->get_generic_tree($tree_name);

=item $bundle->set_generic_tree($tree_name,$root_node);

=back


=head2 Access to the bundle message board

Short unstructured pieces of information can be stored with bundles,
e.g. because of special needs of inter-block communication. For example,
a message can be left in a bundle that the contained sentece cannot
be parsed by an ordinary parsing block and should be parsed later by
a fallback-parser block.

=over 4

=item $bundle->leave_message($message_text);

=item $bundle->get_messages();

=back


=head2 Access to the containers

=over 4

=item $document = $bundle->get_document();

Returns the TectoMT::Document object in which the bundle is contained.

=back



=head1 COPYRIGHT

Copyright 2006 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
