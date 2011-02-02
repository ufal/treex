package Treex::Core::BundleZone;

use Moose;
use Treex::Moose;
use MooseX::NonMoose;
use Treex::Core::Log;

use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;

extends 'Treex::Core::Zone';

# using additional attributes is not straighforward, since
# the underlying (non-moose) class is a blessed array reference;
# (maybe it'll be better to shift everywhere $zone ----> $zone->value)


sub _set_bundle {
    my ($self, $bundle) = @_;
    $self->set_attr('_bundle',$bundle);
}

sub get_bundle {
    my ($self, $bundle) = @_;
    return $self->get_attr('_bundle');
}

sub get_document {
    my $self = shift;
    return $self->get_bundle->get_document;
}

sub create_tree {
    my ($self,$layer) = @_;

    my $class = "Treex::Core::Node::".uc($layer);
    my $tree_root = eval "$class->new()" or log_fatal $!; #layer subclasses not available yet

    my $bundle = $self->get_bundle;
    $tree_root->_set_bundle($bundle);

    my $new_tree_name = lc($layer) . "_tree";
    $self->value->{trees}->{$new_tree_name} = $tree_root;

    my $new_id = "$new_tree_name-".$bundle->get_id."-root";
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


sub get_tree {
    my ($self, $layer) = @_;

    my $tree_name = lc($layer) . "_tree";
    my $tree = $self->value->{trees}->{$tree_name};

    if ( not defined $tree ) {
        log_fatal("No $tree_name available in the bundle, bundle id=" . $self->get_attr('id'));
    }
    return $tree;
}

sub get_all_trees {
   my ($self) = @_;

   return grep {defined}
       map {$self->value->{trees}->{$_."_tree"};} qw(a t n p);

}




1;
