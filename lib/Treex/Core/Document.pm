package Treex::Core::Document;

use Moose;
use Treex::Moose;
use Treex::Core::Config;
use Treex::Core::DocZone;
use Treex::Core::Bundle;

with 'Treex::Core::TectoMTStyleAccessors';

use Treex::PML;
Treex::PML::UseBackends('PMLBackend');
Treex::PML::AddResourcePath( Treex::Core::Config::pml_schema_dir());

use Scalar::Util qw( weaken );

has loaded_from => ( is => 'rw', isa => 'Str', default => '' );
has path        => ( is => 'rw', isa => 'Str' );
has file_stem   => ( is => 'rw', isa => 'Str', default => 'noname' );
has file_number => ( is => 'rw', isa => 'Str', builder => 'build_file_number' );
my $highest_file_number = 1;

sub build_file_number {
    return sprintf "%03d", $highest_file_number++;
}

# Full filename without the extension
sub full_filename {
    my $self = shift;
    if ($Treex::Core::Config::params_validate) { ## no critic (ProhibitPackageVars)
        pos_validated_list( \@_ );
    }
    return ( $self->path ? $self->path : '' ) . $self->file_stem . $self->file_number;
}

has _pmldoc => (
    isa      => 'Treex::PML::Document',
    is       => 'rw',
    init_arg => 'pml_doc',
    writer   => '_set_pmldoc',
    handles  => {
        set_filename => 'changeFilename',
        map { $_ => $_ }
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
    builder => '_create_empty_pml_doc',
);

has _index => (
    is => 'rw',
    default => sub { return {} },
);

has _latest_node_number => (    # for generating document-unique IDs
    is      => 'rw',
    default => 0,
);

use Treex::PML::Factory;
my $factory = Treex::PML::Factory->new();

sub BUILD {
    my $self = shift;
    my ($params_rf) = @_;

    my $pmldoc;

    if ( defined $params_rf ) {

        # creating Treex::Core::Document from an already existing Treex::PML::Document instance
        if ( $params_rf->{pmldoc} ) {
            $pmldoc = $params_rf->{pmldoc};
        }

        # loading Treex::Core::Document from a file
        elsif ( $params_rf->{filename} ) {
            $pmldoc = $factory->createDocumentFromFile( $params_rf->{filename} );
        }

    }

    # constructing treex document from an existing file
    if ($pmldoc) {
        $self->_set_pmldoc($pmldoc);

        # ensuring Treex::Core types (partially copied from the factory)
        my $meta = $self->metaData('pml_root')->{meta};
        if ( defined $meta->{zones} ) {
            foreach my $doczone ( map { $_->value() } $meta->{zones}->elements ) {

                # $doczone hashref will be reused as the blessed instance variable
                Treex::Core::DocZone->new($doczone);
            }
        }

        foreach my $bundle ( $self->get_bundles ) {
            bless $bundle, 'Treex::Core::Bundle';
            $bundle->_set_document($self);

            if ( defined $bundle->{zones} ) {
                foreach my $zone ( map { $_->value() } $bundle->{zones}->elements ) {

                    # $zone hashref will be reused as the blessed instance variable
                    Treex::Core::BundleZone->new($zone);
                    $zone->_set_bundle($bundle);

                    foreach my $tree ( $zone->get_all_trees ) {
                        my $layer;
                        if ($tree->type->get_structure_name =~ /(\S)-(root|node|nonterminal|terminal)/) {
                            $layer = uc($1);
                        } else {
                            log_fatal "Unexpected member in zone structure: " . $tree->type->get_structure_name;
                        }
                        foreach my $node ( $tree, $tree->descendants ) {    # must still call Treex::PML::Node's API
                            bless $node, "Treex::Core::Node::$layer";
                            $self->index_node_by_id( $node->get_id, $node );
                        }
                        $tree->_set_zone($zone);
                    }

                    # TODO: Backward links from a-nodes to n-nodes
                    # should be created in n-nodes' constructors,
                    # which must be called after constructing a-nodes.
                    # TODO: Now, we don't call node constructors at all
                    # during loading, we just re-bless Treex::PML::Nodes.
                    if ( $zone->has_ntree ) {
                        foreach my $nnode ( $zone->get_ntree()->get_descendants() ) {
                            foreach my $anode ( $nnode->get_anodes() ) {
                                $anode->_set_n_node($nnode);
                            }
                        }
                    }
                }
            }
        }
    }
    return;
}

sub _pml_attribute_hash {
    my $self = shift;
    if ($Treex::Core::Config::params_validate) { ## no critic (ProhibitPackageVars)
        pos_validated_list( \@_ );
    }
    return $self->metaData('pml_root')->{meta};
}


#my $_treex_schema_file = Treex::PML::ResolvePath( '.', 'treex_schema.xml', 1 );
my $_treex_schema_file = Treex::Core::Config::pml_schema_dir . "/" . 'treex_schema.xml';
if ( not -f $_treex_schema_file ) {
    log_fatal "Can't find PML schema $_treex_schema_file";
}

my $_treex_schema = Treex::PML::Schema->new( { filename => $_treex_schema_file } );

sub _create_empty_pml_doc {
    my $fsfile = Treex::PML::Document->create
        (
        name => "x",                         #$filename,  ???
        FS   => Treex::PML::FSFormat->new(
            {
                'deepord' => ' N'            # ???
            }
        ),
        trees    => [],
        backend  => 'PMLBackend',
        encoding => "utf-8",
        );

    $fsfile->changeMetaData( 'schema-url', 'treex_schema.xml' );
    $fsfile->changeMetaData( 'schema',     $_treex_schema );
    $fsfile->changeMetaData( 'pml_root', { meta => {}, bundles => undef, } );
    return $fsfile;
}

# --- INDEXING

sub index_node_by_id {
    my $self = shift;
    my ( $id, $node ) = pos_validated_list(
        \@_,
        { isa => 'Id' },
        { isa => 'Maybe[Treex::Core::Node]' },    #jde to takhle?
    );
    my $index = $self->_index;
    if ( defined $node ) {
        $index->{$id} = $node;
        weaken $index->{$id};
    }
    else {
        delete $index->{$id};
    }
    return;
}

sub id_is_indexed {
    my $self = shift;
    my ($id) = pos_validated_list(
        \@_,
        { isa => 'Id' },
    );
    return ( defined $self->_index->{$id} );
}

sub get_node_by_id {

    #komentare se vztahuji k TectoMT a vztahu M a A vrstvy -> neni to uz vyresene jinak?
    my $self = shift;
    my ($id) = pos_validated_list(
        \@_,
        { isa => 'Id' },
    );
    if ( defined $self->_index->{$id} ) {
        return $self->_index->{$id};
    }
    elsif ( $id =~ /^[ST](Czech|English)/ ) {

        # PROZATIMNI RESENI
        # nejsou linky mezi M a A vrstvou, je nutne mezi nimi skakat pomoci teto funkce
        # toto osetruje pripady typu 'SenM' a 'SEnglishA'
        $id =~ s/^([ST])Czech/$1cs/;
        $id =~ s/^([ST])English/$1en/;
        return $self->get_node_by_id($id);
    }
    else {
        log_fatal "ID not indexed: id=\"$id\"";

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
    return;
}

sub get_all_node_ids {
    my $self = shift;
    if ($Treex::Core::Config::params_validate) { ## no critic (ProhibitPackageVars)
        pos_validated_list( \@_ );
    }
    return ( keys %{ $self->_index } );
}

# ----------------- ACCESS TO BUNDLES ----------------------

sub get_bundles {
    my $self = shift;
    if ($Treex::Core::Config::params_validate) { ## no critic (ProhibitPackageVars)
        pos_validated_list( \@_ );
    }
    return $self->trees;
}

sub create_bundle {
    my ( $self, $arg_ref ) = @_;

    #    pos_validated_list( \@_ );

    my $fsfile = $self->_pmldoc();
    my $new_bundle;
    my $position_of_new;

    if ( $arg_ref and ( $arg_ref->{after} or $arg_ref->{before} ) ) {
        my $reference_bundle = ( $arg_ref->{after} ) ? $arg_ref->{after} : $arg_ref->{before};
        my $position_of_reference = $reference_bundle->get_position;
        $position_of_new = $position_of_reference + ( $arg_ref->{after} ? 1 : 0 );
    }

    else {    # default: append at the end of the document
        $position_of_new = scalar( $self->get_bundles() );
    }

    $new_bundle = $fsfile->new_tree($position_of_new);
    $new_bundle->set_type_by_name( $fsfile->metaData('schema'), 'bundle.type' );
    bless $new_bundle, "Treex::Core::Bundle";    # is this correct/sufficient with Moose ????
    $new_bundle->_set_document($self);

    $new_bundle->set_id( "s" . ( $fsfile->lastTreeNo + 1 ) );

    return $new_bundle;
}

# -------------- ACCESS TO ZONES ---------------------------------------

sub create_zone {

    #Now it doesn't support compound Zone selector as Scs
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector', default => '' },
    );

    #my ( $self, $language, $selector ) = @_;
    #
    #if ( $language =~ /(.+)(..)/ ) {
    #    $language = $2;
    #    $selector = $1;
    #}

    my $new_zone = Treex::Core::DocZone->new(
        {
            'language' => $language,
            'selector' => $selector
        }
    );

    my $new_element = Treex::PML::Seq::Element->new( 'zone', $new_zone );

    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        $meta->{zones}->unshift_element_obj($new_element);
    }
    else {
        $meta->{zones} = Treex::PML::Seq->new( [$new_element] );
    }

    return $new_zone;
}

sub get_zone {

    #Now it doesn't support compound Zone selector as Scs
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector', default => '' },
    );

    #my ( $self, $language, $selector ) = @_;

    #if ( $language =~ /(.+)(..)/ ) {    # temporarily expecting just two-letter language codes !!!
    #    $language = $2;
    #    $selector = $1;
    #}

    my $meta = $self->metaData('pml_root')->{meta};
    if ( defined $meta->{zones} ) {
        foreach my $element ( $meta->{zones}->elements ) {
            my ( undef, $value ) = @$element; # $name is not needed
            if ( $value->{language} eq $language and ( $value->{selector} || '' ) eq ( $selector || '' ) ) {
                return $value;
            }
        }
    }
    return;
}

sub get_or_create_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'LangCode' },
        { isa => 'Selector', default => '' },
    );

    my $fs_zone = $self->get_zone( $language, $selector );
    if ( not defined $fs_zone ) {
        $fs_zone = $self->create_zone( $language, $selector );
    }
    return $fs_zone;
}

# ----------------- ACCESS TO ATTRIBUTES -------------------

sub set_attr {
    my $self = shift;
    my ( $attr_name, $attr_value ) = pos_validated_list(
        \@_,
        { isa => 'Str' },
        { isa => 'Any' },
    );

    if ( $attr_name =~ /^(\S+)$/ ) {
        return Treex::PML::Node::set_attr(
            $self->metaData('pml_root')->{meta},
            $attr_name, $attr_value
        );
    }

    elsif ( $attr_name =~ /^([ST]?.*)([a-z]{2}) (\S+)$/ ) {
        my ( $selector, $language, $attr_name ) = ( $1, $2, $3 );
        my $zone = $self->get_or_create_zone( $language, $selector );
        return $zone->set_attr( $attr_name, $attr_value );
    }

    else {
        log_fatal "Attribute name not structured approapriately (e.g.'Sar text'): $attr_name";
    }
}

sub get_attr {
    my $self = shift;
    my ($attr_name) = pos_validated_list(
        \@_,
        { isa => 'Str' },
    );

    if ( $attr_name =~ /^(\S+)$/ ) {
        return Treex::PML::Node::attr( $self->metaData('pml_root')->{meta}, $attr_name );
    }

    elsif ( $attr_name =~ /^([ST]?.*)([a-z]{2}) (\S+)$/ ) {
        my ( $selector, $language, $attr_name ) = ( $1, $2, $3 );
        my $fs_zone = $self->get_zone( $language, $selector );
        if ( defined $fs_zone ) {
            return $fs_zone->get_attr($attr_name);
        }
        else {
            return;
        }
    }

    else {
        log_fatal "Attribute name not structured approapriately (e.g.'Sar sentence'): $attr_name";
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__



=for Pod::Coverage BUILD build_file_number

=head1 NAME

Treex::Core::Document - representation of a text and its linguistic analyses in the Treex framework

=head1 DESCRIPTION

A document consists of a sequence of bundles, mirroring a sequence
of natural language sentences (typically, but not necessarily,
originating from the same text). Attributes (attribute-value pairs)
can to attached to a document as a whole.

=head1 ATTRIBUTES

Treex::Core::Document's instances have the following attributes:

=over 4

=item loaded_from

=item path

=item file_stem

=item file_number

=back

The attributes can be accessed using semi-affordance accessors:
getters have the same names as attributes, while setters start with
'set_'. For example:

=over 4

=item my $value = $doc->path;

=item my $doc->set_path( $value );

=back

The attributes are accessible also by the following methods:

=over 4

=item my $value = $document->get_attr( $name );

Returns the value of the document attribute of the given name.

=item  $document->set_attr( $name, $value );

Sets the given attribute of the document with the given value.

=back



=head1 METHODS

=head2 Constructor

=over 4

=item  my $new_document = Treex::Core::Document->new;

creates a new empty document object.

=item  my $new_document = Treex::Core::Document->new( { pmldoc => $pmldoc } );

creates a Treex::Core::Document instance from an already existing Treex::PML::Document instance

=item  my $new_document = Treex::Core::Document->new( { filename => $filename } );

loads a Treex::Core::Document instance from a .treex file

=back


=head2 Access to zones

Document zones are instances of Treex::Core::DocZone, parametrized
by ISO TODO??? language code and possibly also by another free label
called selector, whose purpose is to distinguish zones for the same language
but from a different source.

=over 4

=item my $zone = $doc->create_zone( $langcode, ?$selector );

=item my $zone = $doc->get_zone( $langcode, ?$selector );

=item my $zone = $doc->get_or_create_zone( $langcode, ?$selector );

=back


=head2 Access to bundles

=over 4

=item my @bundles = $document->get_bundles();

Returns the array of bundles contained in the document.


=item my $new_bundle = $document->create_bundle();

Creates a new empty bundle and appends it
at the end of the document.

=item my $new_bundle = $document->new_bundle_before( $existing_bundle );

Creates a new empty bundle and inserts it
in front of the existing bundle.

=item my $new_bundle = $document->new_bundle_after( $existing_bundle );

Creates a new empty bundle and inserts it
after the existing bundle.

=back


=head2 Node indexing

=over 4

=item  $document->index_node_by_id( $id, $node );

The node is added to the id2node hash table (as mentioned above, it
is done automatically in $node->set_attr() if the attribute name
is 'id'). When using undef in the place of the second argument, the entry
for the given id is deleted from the hash.


=item my $node = $document->get_node_by_id( $id );

Return the node which has the value $id in its 'id' attribute,
no matter to which tree and to which bundle in the given document
the node belongs to.

It is prohibited in TectoMT for IDs to point outside of the current document.
In rare cases where your data has such links, we recommend you to split the
documents differently or hack it by dropping the problematic links.

=item $document->id_is_indexed( $id );

Return true if the given id is already present in the indexing table.

=item $document->get_all_node_ids();

Return the array of all node identifiers indexed in the document.

=back


=head2 Other

=over 4

=item my $filename = $doc->full_filename;

full filename without the extension

=back


=head1 AUTHOR

Zdenek Zabokrtsky

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright 2005-2011 by UFAL

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


