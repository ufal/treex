package Treex::Core::TectoMTStyleAccessors;

our $VERSION = '0.1';

use Moose::Role;
use Report;

requires '_pml_attribute_hash'; # return $self for Node and Bundle, but not for Document (delegation)

sub get_attr {
    my ( $self, $attr_name ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_hash = $self->_pml_attribute_hash();
    Report::fatal('get_attr() called on an disconnected node!') if !defined $attr_hash;

    if (ref($attr_hash) eq "HASH") { # meta-data seems to be an unblessed hash, docasne!!!!
        return $attr_hash->{$attr_name};
    }
    else {
        return $attr_hash->attr($attr_name);
    }
}

sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 3;
    if ( $attr_name eq 'id' ) {
        if ( not defined $attr_value or $attr_value eq '' ) {
            Report::fatal 'Setting undefined or empty ID is not allowed';
        }
        $self->get_document->index_node_by_id( $attr_value, $self );
    } elsif ( ref($attr_value) eq 'ARRAY' ) {
        $attr_value = Treex::PML::List->new( @{$attr_value} );
    }
    my $attr_hash = $self->_pml_attribute_hash()
        or Report::fatal("set_attr($attr_name, $attr_value) called on disconnected node!");

    if (ref($attr_hash) eq "HASH") { # meta-data seems to be an unblessed hash, docasne!!!!
        return $attr_hash->{$attr_name} = $attr_value;
    }
    else { # fs-nodes
        return Treex::PML::Node::set_attr($self,$attr_name,$attr_value); # better to find superclass, but speed?
    }
}

sub get_deref_attr {
    my ( $self, $attr_name ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->_pml_attribute_hash()->attr($attr_name);

    return if !$attr_value;
    my $document = $self->get_document();
    return [ map { $document->get_node_by_id($_) } @{$attr_value} ]
        if ref($attr_value) eq 'Treex::PML::List';
    return $document->get_node_by_id($attr_value);
}

sub set_deref_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 3;
    if ( ref($attr_value) eq 'ARRAY' ) {
        my @list = map { $_->get_attr('id') } @{$attr_value};
        $attr_value = Treex::PML::List->new(@list);
    } else {
        $attr_value = $attr_value->get_attr('id');
    }

    # attr setting always through TectoMT set_attr, as it can be overidden (and it is in Node/N.pm)
    #return $fsnode{ ident $self}->set_attr( $attr_name, $attr_value );
    return $self->set_attr( $attr_name, $attr_value );
}

##-- begin proposal
# Example usage:
# TectoMT::Node::T methods get_lex_anode and get_aux_anodes could use:
# my $a_lex = $t_node->get_r_attr('a/lex.rf'); # returns the node or undef
# my @a_aux = $t_node->get_r_attr('a/aux.rf'); # returns the nodes or ()
sub get_r_attr {
    my ( $self, $attr_name ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ != 2;
    my $attr_value = $self->_pml_attribute_hash()->attr($attr_name);

    return if !$attr_value;
    my $document = $self->get_document();
    if (wantarray) {
        Report::fatal("Attribute '$attr_name' is not a list, but get_r_attr() called in a list context.")
              if ref($attr_value) ne 'Treex::PML::List';
        return map { $document->get_node_by_id($_) } @{$attr_value};
    }

    Report::fatal("Attribute $attr_name is a list, but get_r_attr() not called in a list context.")
          if ref($attr_value) eq 'Treex::PML::List';
    return $document->get_node_by_id($attr_value);
}

# Example usage:
# $t_node->set_r_attr('a/lex.rf', $a_lex);
# $t_node->set_r_attr('a/aux.rf', @a_aux);
sub set_r_attr {
    my ( $self, $attr_name, @attr_values ) = @_;
    Report::fatal('Incorrect number of arguments') if @_ < 3;
    my $fs = $self->_pml_attribute_hash();

    # TODO $fs->type nefunguje - asi protoze se v konstruktorech nenastavuje typ
    if ( $fs->type($attr_name) eq 'Treex::PML::List' ) {
        my @list = map { $_->get_attr('id') } @attr_values;

        # TODO: overriden Node::N::set_attr is bypassed by this call
        return $fs->set_attr( $attr_name, Treex::PML::List->new(@list) );
    }
    Report::fatal("Attribute '$attr_name' is not a list, but set_r_attr() called with @attr_values values.")
          if @attr_values > 1;

    # TODO: overriden Node::N::set_attr is bypassed by this call
    return $fs->set_attr( $attr_name, $attr_values[0]->get_attr('id') );
}




1;
