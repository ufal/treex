package Treex::Core::Document;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;
use Treex::Core::TectoMTStyleAccessors;

with 'Treex::Core::TectoMTStyleAccessors';

use Treex::PML;
use Scalar::Util qw( weaken );

use Treex::Core::Bundle;

use Report; # taky nahradit necim novym

has _pmldoc => (
    isa=>'Treex::PML::Document',
    is=>'rw',
    init_arg => 'pml_doc',
    handles => {
        map {$_=>$_}
            qw( load clone save writeFile writeTo filename URL
                changeFilename changeURL fileFormat changeFileFormat
                backend changeBackend encoding changeEncoding userData
                changeUserData metaData changeMetaData listMetaData
                appData changeAppData listAppData

                FS changeFS

                hint changeHint pattern_count pattern patterns
                changePatterns tail changeTail

                trees changeTrees treeList tree lastTreeNo notSaved
                currentTreeNo currentNode nodes value_line value_line_list
                insert_tree set_tree append_tree new_tree delete_tree
                destroy_tree swap_trees move_tree_to test_tree_type
                determine_node_type )
        },
    default => sub { _create_empty_pml_doc() },
);

has _index => (
    is => 'rw',
    default => sub {return {} },
);

has _latest_node_number => ( # for generating document-unique IDs
    is => 'rw',
    default => 0,
);


sub _pml_attribute_hash {
    my $self = shift;
    return $self->metaData('pml_root')->{meta};
}


Treex::PML::UseBackends('PMLBackend');
Treex::PML::AddResourcePath(
    $ENV{"TRED_DIR"},
    $ENV{"TRED_DIR"} . "/resources/",
    $ENV{"TMT_ROOT"} . "/pml_schemas/"
);

my $_treex_schema_file = Treex::PML::ResolvePath( '.', 'treex_schema.xml', 1 );
my $_treex_schema = Treex::PML::Schema->new( { filename => $_treex_schema_file } );

sub _create_empty_pml_doc {
    my $fsfile = Treex::PML::Document->create
    (
        name => "x",                                                           #$filename,  ???
        FS   => Treex::PML::FSFormat->new(
            {
                'deepord' => ' N'                                              # ???
            }
        ),
        trees    => [],
        backend  => 'PMLBackend',
        encoding => "utf-8",
    );

    $fsfile->changeMetaData( 'schema-url', 'treex_schema.xml' );
    $fsfile->changeMetaData( 'schema', $_treex_schema );
    $fsfile->changeMetaData( 'pml_root', { meta => {}, bundles => undef, } );
    return $fsfile;
}


sub get_tied_fsfile { # !!! before all usages are removed
    my $self = shift;
    return $self->_get_pmldoc;
}


# --- INDEXING

sub index_node_by_id() {
    my ( $self, $id, $node ) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 3;
    my $index = $self->_get_index;
    if ( defined $node ) {
        $index->{$id} = $node;
        weaken $index->{$id};
    }
    else {
        delete $index->{$id};
    }
}

sub id_is_indexed {
    my ( $self, $id ) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 2;
    my $index = $self->_get_index;
    return ( defined $index->{$id} );
}

sub get_node_by_id() {
    my ( $self, $id ) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 2;
    my $index = $self->_get_index;
    if ( defined $index->{$id} ) {
        return $index->{$id};
    } elsif ( $id =~ /^[ST](Czech|English)/ ) {
        # PROZATIMNI RESENI
        # nejsou linky mezi M a A vrstvou, je nutne mezi nimi skakat pomoci teto funkce
        # toto osetruje pripady typu 'SenM' a 'SEnglishA'
        $id =~ s/^([ST])Czech/$1cs/;
        $id =~ s/^([ST])English/$1en/;
        return $self->get_node_by_id($id);
    } else {
        Report::fatal "ID not indexed: id=\"$id\"";
        # This is something very fatal. TectoMT assumes every node ID to
        # be valid and pointing to a node *in the given document*.
        # (It is fine to have a node with no a/lex.rf
        # attribute, but if the attribute is there, the value
        # has to be an ID within the document.)
        #
        # If your data violates the requirement and your IDs point to
        # a different document, the only hack we suggest is to drop such
        # references...
    }
}

sub get_all_node_ids() {
    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;
    my $index = $self->_get_index;
    return ( keys %{$index} );
}


# ----------------- ACCESS TO BUNDLES ----------------------

sub get_bundles {
    my $self = shift;
    return $self->trees;
}


sub new_bundle {
    my $self = shift;
    $self->create_bundle(@_);
}


sub create_bundle {

    my ($self) = @_;
    Report::fatal("Incorrect number of arguments") if @_ != 1;

    my $fsfile = $self->_get_pmldoc();

    # Minimal position is 0, maximal position is number of bundles minus 1.
    # Next free position is equal to the current number of bundles.
    my $position   = scalar( $self->get_bundles() );

    my $new_bundle = $fsfile->new_tree($position);
    $new_bundle->set_type_by_name( $fsfile->metaData('schema'), 'bundle.type' );

    bless $new_bundle,"Treex::Core::Bundle"; # is this correct/sufficient with Moose ????
    $new_bundle->_set_document($self);
    $new_bundle->set_id("s".($position+1));

#    $new_bundle->_set_position($position); #???

    return $new_bundle;
}


# ----------------- ACCESS TO ATTRIBUTES -------------------

sub _get_zone {
    my ($self, $language, $purpose) = @_;
    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        foreach my $element ( $meta->{zones}->elements ) {
            my ( $name, $value ) = @$element;
            if ( $value->{language} eq $language and $value->{purpose} eq $purpose ) {
                return $value;
            }
        }
    }
    return undef;
}


sub _create_zone {
    my ($self, $language, $purpose) = @_;

    my $new_zone = Treex::PML::Seq::Element->new('zone', Treex::PML::Struct->new({
        'language'=>$language,
        'purpose'=>$purpose}) );


    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        $meta->{zones}->unshift_element_obj($new_zone);
    }
    else {
        $meta->{zones} = Treex::PML::Seq->new( [$new_zone ] );
    }

    return $new_zone->value;
}


sub _get_or_create_zone {
    my ($self, $language, $purpose) = @_;
    my $fs_zone = $self->_get_zone($language, $purpose);
    if (not defined $fs_zone) {
        $fs_zone = $self->_create_zone($language,$purpose);
    }
    return $fs_zone;
}



sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal "set_attr: incorrect number of arguments" if @_ != 3;

    if ($attr_name =~ /^(\S+)$/) {
        return Treex::PML::Node::set_attr( $self->metaData('pml_root')->{meta},
                                           $attr_name, $attr_value );
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
        return Treex::PML::Node::attr( $self->metaData('pml_root')->{meta}, $attr_name );
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





__PACKAGE__->meta->make_immutable;


1;
