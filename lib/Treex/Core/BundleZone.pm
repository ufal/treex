package Treex::Core::BundleZone;

use Moose;
use Treex::Moose;
use MooseX::NonMoose;
#use Treex::Core::Log;

use Treex::Core::Node::A;
use Treex::Core::Node::T;
use Treex::Core::Node::N;

extends 'Treex::Core::Zone';


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

sub create_a_tree {
	my ($self) = @_;
	return $self->create_tree('a');
}

sub create_t_tree {
	my ($self) = @_;
	return $self->create_tree('t');
}

sub create_n_tree {
	my ($self) = @_;
	return $self->create_tree('n');
}

#sub create_p_tree {
#	my ($self) = @_;
#	return $self->create_tree('p');
#}

sub create_tree {
    my ($self, $layer) = @_;

    my $class = "Treex::Core::Node::".uc($layer);
    my $tree_root = eval "$class->new()" or log_fatal $!; #layer subclasses not available yet

    my $bundle = $self->get_bundle;
    $tree_root->_set_zone($self);

    my $new_tree_name = lc($layer) . "_tree";
    $self->{trees}->{$new_tree_name} = $tree_root;

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
    my $tree = $self->{trees}->{$tree_name};

    if ( not defined $tree ) {
        log_fatal("No $tree_name available in the bundle, bundle id=" . $self->get_attr('id'));
    }
    return $tree;
}

sub get_a_tree {
	my ($self) = @_;
	return $self->get_tree('a');
}

sub get_t_tree {
	my ($self) = @_;
	return $self->get_tree('t');
}

sub get_n_tree {
	my ($self) = @_;
	return $self->get_tree('n');
}

sub get_p_tree {
	my ($self) = @_;
	return $self->get_tree('p');
}

sub has_tree {
    my ($self, $layer) = @_;
    my $tree_name = lc($layer) . "_tree";
    return defined $self->{trees}->{$tree_name};
}

sub get_all_trees {
   my ($self) = @_;

   return grep {defined}
       map {$self->{trees}->{$_."_tree"};} qw(a t n p);

}

sub sentence {
    my ($self) = @_;
    return $self->get_attr('sentence');
}

sub set_sentence {
    my ($self, $text) = @_;
    return $self->set_attr('sentence', $text);
}

1;
