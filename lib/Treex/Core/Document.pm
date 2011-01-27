package Treex::Core::Document;

use Moose;
use MooseX::FollowPBP;
use Treex::Core::TectoMTStyleAccessors;
use Treex::Core::Config;
use Treex::Core::DocZone;

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
        set_filename => 'changeFilename',
        map {$_=>$_}
            qw( load clone save writeFile writeTo filename URL
                changeFilename changeURL fileFormat changeFileFormat
                backend changeBackend encoding changeEncoding userData
                changeUserData metaData changeMetaData listMetaData
                appData changeAppData listAppData

                documentRootData

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

#sub get_pml {
#    my $self = shift;
#    return $self->_pml
#}

use Treex::PML::Factory;
my $factory = Treex::PML::Factory->new();

sub BUILD {
    my ($self, $params_rf) = @_;

    my $pmldoc;

    if (defined $params_rf) {

        # creating Treex::Core::Document from an already existing Treex::PML::Document instance
        if ($params_rf->{pmldoc}) {
            $pmldoc = $params_rf->{pmldoc};
        }

        # loading Treex::Core::Document from a file
        elsif ($params_rf->{filename}) {
            $pmldoc = $factory->createDocumentFromFile($params_rf->{filename});
        }

    }

    # constructing treex document from an existing file
    if ($pmldoc) {

        $self->_set_pmldoc($pmldoc);
        $self->_set_index({});

        # ensuring Treex::Core types (partially copied from the factory)
        my $meta = $self->metaData('pml_root')->{meta};
        if ( defined $meta->{zones} ) {
            foreach my $element ( $meta->{zones}->elements ) {
                bless $element, 'Treex::Core::DocZone';
            }
        }

        foreach my $bundle ($self->get_bundles) {
            bless $bundle, 'Treex::Core::Bundle';

            if ( defined $bundle->{zones} ) {
                foreach my $zone ( $bundle->{zones}->elements ) {
                    bless $zone, 'Treex::Core::BundleZone';

                    foreach my $tree ($zone->get_all_trees) {
                        $tree->type->get_structure_name =~ /(\S)-(root|node)/
                            or Report::fatal "Unexpected member in zone structure: ".$tree->type;
                        my $layer = uc($1);
                        foreach my $node ($tree, $tree->descendants) { # must still call Treex::PML::Node's API
                            bless $node, "Treex::Core::Node::$layer";
                            $self->index_node_by_id($node->get_id,$node);
                        }
                    }
                }
            }

            $bundle->_set_document($self);
        }
    }
    return $self;

}


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
    Treex::Core::Config::pml_schema_dir(),
);

#my $_treex_schema_file = Treex::PML::ResolvePath( '.', 'treex_schema.xml', 1 );
my $_treex_schema_file = Treex::Core::Config::pml_schema_dir."/". 'treex_schema.xml';
if (not -f $_treex_schema_file) {
  Report::fatal "Can't find PML schema $_treex_schema_file"; 
}

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


#sub get_tied_fsfile { # !!! before all usages are removed  # check this!
#    my $self = shift;
#    return $self->_get_pmldoc;
#}


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



# -------------- ACCESS TO ZONES ---------------------------------------

sub create_zone {
    my ($self, $language, $selector) = @_;

    if ($language =~ /(.+)(..)/) {
        $language = $2;
        $selector = $1;
    }

    my $new_zone = Treex::Core::DocZone->new('zone', Treex::PML::Struct->new(
        {
            'language' => $language,
            'selector' => $selector
        }
    ));

    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        $meta->{zones}->unshift_element_obj($new_zone);
    }
    else {
        $meta->{zones} = Treex::PML::Seq->new( [$new_zone ] );
    }

    return $new_zone;
}


sub get_zone {
    my ($self, $language, $selector) = @_;

    if ($language =~ /(.+)(..)/) { # temporarily expecting just two-letter language codes !!!
        $language = $2;
        $selector = $1;
    }

    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        foreach my $element ( $meta->{zones}->elements ) {
            my ( $name, $value ) = @$element;
            if ( $value->{language} eq $language and ($value->{selector}||'') eq ($selector||'') ) {
                return $element;
            }
        }
    }
    return;
}

sub get_or_create_zone {
    my ($self, $language, $selector) = @_;
    my $fs_zone = $self->get_zone($language, $selector);
    if (not defined $fs_zone) {
        $fs_zone = $self->create_zone($language,$selector);
    }
    return $fs_zone;
}


# ----------------- ACCESS TO ATTRIBUTES -------------------


sub set_attr {
    my ( $self, $attr_name, $attr_value ) = @_;
    Report::fatal "set_attr: incorrect number of arguments" if @_ != 3;

    if ($attr_name =~ /^(\S+)$/) {
        return Treex::PML::Node::set_attr( $self->metaData('pml_root')->{meta},
                                           $attr_name, $attr_value );
    }

    elsif ($attr_name =~ /^([ST]?.*)([a-z]{2}) (\S+)$/) {
        my ($selector, $language, $attr_name) = ($1,$2,$3);
        my $zone = $self->get_or_create_zone($language,$selector);
        return $zone->set_attr($attr_name, $attr_value);
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

    elsif ($attr_name =~ /^([ST]?.*)([a-z]{2}) (\S+)$/) {
        my ($selector, $language, $attr_name) = ($1,$2,$3);
        my $fs_zone = $self->get_zone($language,$selector);
        if (defined $fs_zone) {
            return $fs_zone->get_attr($attr_name);
        }
        else {
            return;
        }
    }

    else {
        Report::fatal "Attribute name not structured approapriately (e.g.'Sar sentence'): $attr_name";
    }
}





__PACKAGE__->meta->make_immutable;


1;

__END__


=head1 NAME

Treex::Core::Document



=head1 DESCRIPTION


A document consists of a sequence of bundles, mirroring a sequence
of natural language sentences (typically, but not necessarily,
originating from the same text). Attributes (attribute-value pairs)
 can to attached to a document as a whole.

=head1 METHODS

=head2 Constructor

=over 4

=item  my $new_document = Treex::Core::Document->new();

Creates a new empty document object.

=item  my $new_document = Treex::Core::Document->new( { 'fsfile' => $fsfile } );

Creates a TectoMT document corresponding to the specified Fsfile object.

=item  my $new_document = Treex::Core::Document->new( { 'filename' => $filename } );

Loads the tmt file and creates a TectoMT document corresponding to its content.

=back


=head2 Accessing directly the PML files

=over 4

=item open, save, save_as
Not implemented yet.

=item my $filename = $fsfile->get_fsfile_name();

=back

=head2 Access to attributes

=over 4

=item my $value = $document->get_attr($name);

Returns the value of the document attribute of the given name.

=item  $document->set_attr($name,$value);

Sets the given attribute of the document with the given value.
If the attribute name is 'id', then the document's indexing table
is updated.

=back


=head2 Access to generic attributes and trees

Besides document attributes with names statically predefined in the TectoMT
pml schema (such as 'czech_source_text'), one can
use generic attributes, which are parametrizable by
language (using ISO 639 codes) and direction (S for source, T for target).
Attribute names then look e.g. like 'Sar text' (source-side arabic text).

=over 4

=item my $value = $document->get_generic_attr($name);

=item $document->set_generic_attr($name,$value);

=back




=head2 Access to the contained bundles

=over 4

=item my @bundles = $document->get_bundles();

Returns the array of bundles contained in the document.


=item my $new_bundle = $document->create_bundle();

Creates a new empty bundle and appends it
at the end of the document.

=item my $new_bundle = $document->new_bundle_before($existing_bundle);

Creates a new empty bundle and inserts it
in front of the existing bundle.

=item my $new_bundle = $document->new_bundle_after($existing_bundle);

Creates a new empty bundle and inserts it
after the existing bundle.

=back


=head2 Node indexing

=over 4

=item  $document->index_node_by_id($id,$node);

The node is added to the id2node hash table (as mentioned above, it
is done automatically in $node->set_attr() if the attribute name
is 'id'). When using undef in the place of the second argument, the entry
for the given id is deleted from the hash.


=item my $node = $document->get_node_by_id($id);

Return the node which has the value $id in its 'id' attribute,
no matter to which tree and to which bundle in the given document
the node belongs to.

It is prohibited in TectoMT for IDs to point outside of the current document.
In rare cases where your data has such links, we recommend you to split the
documents differently or hack it by dropping the problematic links.

=item $document->id_is_indexed($id);

Return true if the given id is already present in the indexing table.

=item $document->get_all_node_ids();

Return the array of all node identifiers indexed in the document.

=back



=head1 COPYRIGHT

Copyright 2006 Zdenek Zabokrtsky.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
