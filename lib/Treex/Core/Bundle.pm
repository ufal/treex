package Treex::Core::Bundle;

our $VERSION = '0.1';

use Moose;
use MooseX::NonMoose;
use MooseX::FollowPBP;

extends 'Treex::PML::Node';

has document => (is => 'ro',
                 writer => '_set_document',
                 reader => 'get_document',
             );

has id => (is => 'rw' );

use Treex::Core::Node;
use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;

use Report;

my @layers = qw(t a n);

# --------- ACCESS TO TREES ------------

sub get_all_trees {
    my ($self) = @_;

    return () unless $self->{zones};

    my @trees;
    foreach my $zone ($self->{zones}->elements) {
        my $structure = $zone->value;
        foreach my $layer (@layers) {
            if (exists $structure->{trees}->{"${layer}_tree"}) {
                push @trees, $structure->{trees}->{"${layer}_tree"};
            }
        }
    }
    return @trees;

}



sub _get_zone {
    my ( $fs_bundle_root, $language, $purpose ) = @_;
    if ( defined $fs_bundle_root->{zones} ) {
        foreach my $element ( $fs_bundle_root->{zones}->elements ) {
            my ( $name, $value ) = @$element;
            if ( $value->{language} eq $language and $value->{purpose} eq $purpose ) {
                return $value;
            }
        }
    }
    return undef;
}

sub _create_zone {
    my ( $self, $fs_bundle_root, $language, $purpose ) = @_;
    my $new_subbundle = Treex::PML::Seq::Element->new(
        'zone',
        Treex::PML::Struct->new(
            {
                'language'  => $language,
                'purpose' => $purpose
            }
        )
      );

#    $new_subbundle->set_type_by_name( $self->get_document->metaData('schema'), 'zone' );

    if ( defined $fs_bundle_root->{zones} ) {
        $fs_bundle_root->{zones}->unshift_element_obj($new_subbundle);
    } else {
        $fs_bundle_root->{zones} = Treex::PML::Seq->new( [$new_subbundle] );
    }

    return $new_subbundle->value;
}

sub _get_or_create_zone {
    my ( $self, $language, $purpose ) = @_;
    my $fs_bundle_root = $self;
    my $fs_subbundle = _get_zone( $fs_bundle_root, $language, $purpose );
    if ( not defined $fs_subbundle ) {
        $fs_subbundle = $self->_create_zone( $fs_bundle_root, $language, $purpose );
    }
    return $fs_subbundle;
}



sub create_tree {
    my ( $self, $tree_name ) = @_;
    Report::fatal "set_tree: incorrect number of arguments" if @_ != 2;

    $tree_name =~ s/Czech/cs/;
    $tree_name =~ s/English/en/;
    $tree_name =~ s/M$/A/;

    if ( $tree_name =~ /([A-Z])([a-z]{2})([A-Z])$/ ) {

        my ( $purpose, $language, $layer ) = ( $1, $2, $3 );

        my $class = "Treex::Core::Node::$layer";

        my $tree_root = eval "$class->new()" or Report::fatal $!; #layer subclasses not available yet

        $tree_root->_set_bundle($self);

        my $fs_zone = $self->_get_or_create_zone( $language, $purpose );
        my $new_tree_name = lc($layer) . "_tree";
        $fs_zone->{trees}->{$new_tree_name} = $tree_root;

        my $new_id = "$tree_name-".$self->get_id."-root";
#        $tree_root->set_attr( 'id', $new_id );
#        $self->get_document->index_node_by_id($new_id, $tree_root);

        $tree_root->set_id($new_id);

        # pml-typing
        $tree_root->set_type_by_name( $self->get_document->metaData('schema'), lc($layer).'-root.type' );

        # vyresit usporadavaci atribut!
        my $ordering_attribute = $tree_root->get_ordering_member_name;
        if (defined $ordering_attribute) {
            $tree_root->set_attr( $ordering_attribute, 0 );
        }

        return $tree_root;
    }

    else {
        Report::fatal "Tree name $tree_name not matching expected pattern";
    }
}


sub get_tree {
    my ( $self, $tree_name ) = @_;
    Report::fatal "get_tree: incorrect number of arguments" if @_ != 2;

    $tree_name =~ s/Czech/cs/;
    $tree_name =~ s/English/en/;
    $tree_name =~ s/M$/A/;

    if ( $tree_name !~ /([ST])([a-z]{2})([A-Z])/ ) {
        Report::fatal("Tree name not structured approapriately (e.g.SenM): $tree_name");
    }

    else {
        my ( $purpose, $language, $layer ) = ( $1, $2, $3 );

        my $fs_bundle_root = $self;
        my $fs_zone = _get_zone( $fs_bundle_root, $language, $purpose );

        my $tree;

        if ( defined $fs_zone ) {
            my $new_tree_name = lc($layer) . "_tree";
            $tree = $fs_zone->{trees}->{$new_tree_name};
        }

        if ( not defined $tree ) {
            Report::fatal "No generic tree named $tree_name available in the bundle, bundle id=" . $self->get_attr('id');
        }

        return $tree;

    }
}


# --------- ACCESS TO ATTRIBUTES ------------


sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal "set_attr: incorrect number of arguments" if @_ != 3;

    if ($attr_name =~ /^(\S+)$/) {
        return Treex::PML::Node::set_attr( $self, $attr_name, $attr_value );
    }

    elsif ($attr_name =~ /^([ST])([a-z]{2}) (\S+)$/) {
        my ($purpose, $language, $attr_name) = ($1,$2,$3);
        my $fs_zone = $self->_get_or_create_zone($language,$purpose);
        return $fs_zone->{$attr_name} = $attr_value;
    }

    else {
        Report::fatal "Attribute name not structured approapriately (e.g.'Sar text'): $attr_name";
    }
}

sub get_attr {
    my ( $self, $attr_name ) = @_;
    Report::fatal "set_attr: incorrect number of arguments" if @_ != 2;

    if ($attr_name =~ /^(\S+)$/) {
        return Treex::PML::Node::attr( $self, $attr_name );
    }

    elsif ($attr_name =~ /^([ST])([a-z]{2}) (\S+)$/) {
        my ($purpose, $language, $attr_name) = ($1,$2,$3);
        my $fs_zone = $self->_get_zone($language,$purpose);
        if (defined $fs_zone) {
            return $fs_zone->{$attr_name};
        }
        else {
            return undef;
        }
    }

    else {
        Report::fatal "Attribute name not structured approapriately (e.g.'Sar sentence'): $attr_name";
    }
}




# ------ ACCESS MESSAGE BOARD ----------

sub leave_message {
    my ( $self, $message_text ) = @_;
    if ( not defined $message_text or $message_text eq "" ) {
        Report::fatal "Undefined or empty message";
    }
    if ( $self->get_attr('message_board') ) {
        push @{ $self->get_attr('message_board') }, $message_text;
    } else {
        $self->set_attr( 'message_board', Treex::PML::List->new($message_text) );
    }
}

sub get_messages {
    my ($self) = @_;
    Report::fatal "get_messages: incorrect number of arguments" if @_ != 1;
    if ( $self->get_attr('message_board') ) {
        return @{ $self->get_attr('message_board') };
    } else {
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
