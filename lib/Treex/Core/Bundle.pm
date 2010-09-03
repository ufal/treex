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
