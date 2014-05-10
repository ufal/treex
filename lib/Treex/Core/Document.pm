package Treex::Core::Document;

use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Core::DocZone;
use Treex::Core::Bundle;

use Treex::PML;
Treex::PML::UseBackends('PMLBackend');
Treex::PML::AddResourcePath( Treex::Core::Config->pml_schema_dir() );

with 'Treex::Core::WildAttr';

use Scalar::Util qw( weaken reftype );

use PerlIO::via::gzip;
use Storable;
use Digest::MD5 qw(md5_hex);

has loaded_from => ( is => 'rw', isa => 'Str', default => '' );
has path        => ( is => 'rw', isa => 'Str' );
has file_stem   => ( is => 'rw', isa => 'Str', default => 'noname' );
has file_number => ( is => 'rw', isa => 'Str', builder => 'build_file_number' );
has compress => ( is => 'rw', isa => 'Bool', default => undef, documentation => 'compression to .gz' );
has storable => (
    is            => 'rw',
    isa           => 'Bool',
    default       => undef,
    documentation => 'using Storable with gz compression instead of Treex::PML'
);

has _hash => ( is => 'rw', isa => 'Str' );

sub get_hash {
    my $self = shift;
    if ( ! defined($self->_hash) ) {
        $Storable::canonical = 1;
        $self->_set_hash(md5_hex(Storable::nfreeze($self)));
        $Storable::canonical = 0;
    }
    return $self->_hash;
}

sub set_hash {
    my ($self, $hash) = @_;

    $self->_set_hash($hash);

    return;
}

has _pmldoc => (
    isa      => 'Treex::PML::Document',
    is       => 'rw',
    init_arg => 'pml_doc',
    writer   => '_set_pmldoc',
    handles  => {
        set_filename => 'changeFilename',
        map { $_ => $_ }
            qw( clone writeFile writeTo filename URL
            changeFilename changeURL fileFormat changeFileFormat
            backend changeBackend encoding changeEncoding userData
            changeUserData metaData changeMetaData listMetaData
            appData changeAppData listAppData

            documentRootData

            FS changeFS

            hint changeHint pattern_count pattern patterns
            changePatterns tail changeTail

            trees changeTrees treeList tree delete_tree lastTreeNo notSaved
            currentTreeNo currentNode nodes value_line value_line_list
            determine_node_type )
    },
    builder => '_create_empty_pml_doc',
);

has _index => (
    is => 'rw',
    default => sub { return {} },
);

has _backref => (
    is => 'rw',
    default => sub { return {} },
);

has _latest_node_number => (    # for generating document-unique IDs
    is      => 'rw',
    default => 0,
);

use Treex::PML::Factory;
my $factory = Treex::PML::Factory->new();

my $highest_file_number = 1;

# the description attribute is stored inside the meta structures of pml documents,
# that is why it is not realized as a regular Moose attribute

sub set_description {
    my ( $self, $attr_value ) = @_;

    return Treex::PML::Node::set_attr(
        $self->metaData('pml_root')->{meta},
        'description', $attr_value
    );
}

sub description {
    my $self = shift;
    return Treex::PML::Node::attr( $self->metaData('pml_root')->{meta}, 'description' );
}

sub build_file_number {
    return sprintf "%03d", $highest_file_number++;
}

# Full filename without the extension
sub full_filename {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    my $path = '';
    if (defined $self->path && $self->path ne ''){
        $path = $self->path;
        $path .= '/' if $path !~ m{/$};
    }
    return  $path . $self->file_stem . $self->file_number;
}

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

            if ( $params_rf->{filename} =~ /.streex$/ ) {
                log_fatal 'Storable (.streex) docs must be retrieved by Treex::Core::Document->retrieve_storable($filename)';
            }

            else {

                # If the file contains invalid PML (e.g. unknown afun value)
                # Treex::PML fails with die.
                # TODO: we should rather catch the die message and report it via log_fatal
                $pmldoc = eval {
                    # In r10421, ZŽ added here recover => 1:
                    # $factory->createDocumentFromFile( $params_rf->{filename}, { recover => 1 });
                    # However, if the file contains invalid PML (e.g. unknown afun value), the recover=>1 option
                    # results in returning a $pmldoc which seems to be OK, but it contains no bundles,
                    # so Treex crashes on subsequent blocks which is misleading for users.
                    # If we really want to be fault-tolerant, it seems we would need to set Treex::PML::Instance::Reader::STRICT=0,
                    # but I don't no enough about PML internals and I think it's better to make such errors fatal.
                    # Martin Popel
                    $factory->createDocumentFromFile( $params_rf->{filename});
                };
                log_fatal "Error while loading " . $params_rf->{filename} . ( $@ ? "\n$@" : '' )
                    if !defined $pmldoc;
            }
        }
    }

    # constructing treex document from an existing file
    if ($pmldoc) {
        $self->_set_pmldoc($pmldoc);

        # ensuring Treex::Core types (partially copied from the factory)
        if ($self->metaData) {
            my $meta = $self->metaData('pml_root')->{meta};
            if ( $meta and defined $meta->{zones} ) {
                foreach my $doczone ( map { $_->value() } $meta->{zones}->elements ) {

                # $doczone hashref will be reused as the blessed instance variable
                    Treex::Core::DocZone->new($doczone);
                }
            }
        }
        $self->_rebless_and_index();
    }

    $self->deserialize_wild;
    foreach my $bundle ( $self->get_bundles ) {
        $bundle->deserialize_wild;
        foreach my $bundlezone ( $bundle->get_all_zones ) {
            foreach my $node ( map { $_->get_descendants( { add_self => 1 } ) } $bundlezone->get_all_trees ) {
                $node->deserialize_wild;
            }
        }
    }

    return;
}

sub _rebless_and_index {
    my $self = shift;
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
                    if ( $tree->type->get_structure_name =~ /(\S)-(root|node|nonterminal|terminal)/ ) {
                        $layer = uc($1);
                    }
                    else {
                        log_fatal "Unexpected member in zone structure: " . $tree->type->get_structure_name;
                    }
                    foreach my $node ( $tree, $tree->descendants ) {    # must still call Treex::PML::Node's API
                        bless $node, "Treex::Core::Node::$layer";
                        $self->index_node_by_id( $node->get_id, $node );
                    }
                    $tree->_set_zone($zone);
                }
            }
        }
    }
    return;
}

sub _pml_attribute_hash {
    my $self = shift;
    return $self->metaData('pml_root')->{meta};
}

#my $_treex_schema_file = Treex::PML::ResolvePath( '.', 'treex_schema.xml', 1 );
my $_treex_schema_file = Treex::Core::Config->pml_schema_dir . "/" . 'treex_schema.xml';
if ( not -f $_treex_schema_file ) {
    log_fatal "Can't find PML schema $_treex_schema_file";
}

my $_treex_schema = Treex::PML::Schema->new( { filename => $_treex_schema_file } );

sub _create_empty_pml_doc {    ## no critic (ProhibitUnusedPrivateSubroutines)
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
        { isa => 'Treex::Type::Id' },
        { isa => 'Maybe[Treex::Core::Node]' },    #jde to takhle?
    );
    my $index = $self->_index;
    if ( defined $node ) {
        $index->{$id} = $node;
        weaken $index->{$id};

        my $refs = $node->_get_referenced_ids;
        foreach my $type ( keys %{$refs} ) {
            $self->index_backref( $type, $id, $refs->{$type} );
        }
    }
    else {
        delete $index->{$id};
    }
    return;
}

# Add references to the reversed references list
sub index_backref {
    my ( $self, $type, $source, $targets ) = @_;
    my $backref = $self->_backref;

    foreach my $target ( @{$targets} ) {
        next if ( !defined($target) );
        my $target_backrefs = $backref->{$target} // {};
        $backref->{$target} = $target_backrefs;

        $target_backrefs->{$type} = [] if ( !$target_backrefs->{$type} );
        push @{ $target_backrefs->{$type} }, $source;
    }
    return;
}

# Remove references from the reversed references list
sub remove_backref {
    my ( $self, $type, $source, $targets ) = @_;
    my $backref = $self->_backref;

    foreach my $target ( @{$targets} ) {
        next if ( !defined($target) );
        my $target_backrefs = $backref->{$target};
        next if ( !$target_backrefs );

        $target_backrefs->{$type} = [ grep { $_ ne $source } @{ $target_backrefs->{$type} } ];
    }
    return;
}

# Return a hash of references ( type->[nodes] ) leading to the node with the given id
sub get_references_to_id {
    my ( $self, $id ) = @_;
    my $backref = $self->_backref;

    return if ( !$backref->{$id} );
    return $backref->{$id};    # TODO clone ?
}

# Remove all references and backreferences leading to the $node (calls remove_reference() on the source nodes)
sub _remove_references_to_node {
    my ( $self, $node ) = @_;
    my $id      = $node->id;
    my $backref = $self->_backref;

    # First, delete backreferences to the $node
    my $refs = $node->_get_referenced_ids();
    foreach my $type ( keys %{$refs} ) {
        $self->remove_backref( $type, $id, $refs->{$type} );
    }

    # Second, delete references to the $node
    return if ( !$backref->{$id} );
    my $node_backref = $backref->{$id};

    foreach my $type ( keys %{$node_backref} ) {
        foreach my $source ( @{ $node_backref->{$type} } ) {
            $self->get_node_by_id($source)->remove_reference( $type, $id );
        }
    }

    # Third, delete backreferences from the $node
    delete $backref->{$id};
    return;
}

sub id_is_indexed {
    my $self = shift;
    my ($id) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Id' },
    );
    return ( defined $self->_index->{$id} );
}

sub get_node_by_id {
    my $self = shift;
    my ($id) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::Id' },
    );
    if ( defined $self->_index->{$id} ) {
        return $self->_index->{$id};
    }
    else {
        log_fatal "ID not indexed: id=\"$id\"";

        # This is something very fatal. Treex assumes every node ID to
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
    log_fatal('Incorrect number of arguments') if @_ != 1;
    my $self = shift;
    return ( keys %{ $self->_index } );
}

# ----------------- ACCESS TO BUNDLES ----------------------

sub get_bundles {
    log_fatal('Incorrect number of arguments') if @_ != 1;
    my $self = shift;
    return $self->trees;
}

sub create_bundle {
    my ( $self, $arg_ref ) = @_;
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
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
    );

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

sub get_all_zones {
    my $self = shift;
    my $meta = $self->metaData('pml_root')->{meta};
    return if !$meta->{zones};
    
    # Each element is a pair [$name, $value]. We need just the values.
    return map {$_->[1]}  $meta->{zones}->elements;
}

sub get_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
    );

    foreach my $zone ($self->get_all_zones()) {
        return $zone if $zone->language eq $language && $zone->selector eq $selector;
    }
    return;
}

sub get_or_create_zone {
    my $self = shift;
    my ( $language, $selector ) = pos_validated_list(
        \@_,
        { isa => 'Treex::Type::LangCode' },
        { isa => 'Treex::Type::Selector', default => '' },
    );

    my $fs_zone = $self->get_zone( $language, $selector );
    if ( not defined $fs_zone ) {
        $fs_zone = $self->create_zone( $language, $selector );
    }
    return $fs_zone;
}

# -------------- LOADING AND SAVING ---------------------------------------

sub load {
    my $self = shift;
    return $self->_pmldoc->load(@_);

    # TODO: this is unfinished: should be somehow connected with the code in BUILD
}

sub save {
    my $self = shift;
    my ($filename) = @_;

    if ( $filename =~ /\.streex$/ ) {
        open( my $F, ">:via(gzip)", $filename ) or log_fatal $!;
        print $F Storable::nfreeze($self);
        close $F;

        # using  Storable::nstore_fd($self,*$F) emits 'Inappropriate ioctl for device'
    }

    else {
        $self->_serialize_all_wild();
        return $self->_pmldoc->save(@_);
    }

    return;
}

sub _serialize_all_wild {
    my ($self) = @_;
    $self->serialize_wild;
    foreach my $bundle ( $self->get_bundles ) {
        $bundle->serialize_wild;
        foreach my $bundlezone ( $bundle->get_all_zones ) {
            foreach my $node ( map { $_->get_descendants( { add_self => 1 } ) } $bundlezone->get_all_trees ) {
                $node->serialize_wild;
            }
        }
    }
    return;
}

sub retrieve_storable {
    my ( $class, $file ) = @_;    # $file stands for a file name, but it can be also file handle (needed by the TrEd backend for .streex)

    my $FILEHANDLE;
    my $opened = 0;

    if ( ref($file) and reftype($file) eq 'GLOB' ) {
        $FILEHANDLE = $file;
    }
    else {
        log_fatal "filename=$file, but Treex::Core::Document->retrieve_storable(\$filename) can be used only for .streex files"
            unless $file =~ /\.streex$/;
        open $FILEHANDLE, "<:via(gzip)", $file or log_fatal($!);
        $opened = 1;
    }

    my $serialized;

    # reading it this way is silly, but both slurping the file or
    #  using Storable::retrieve_fd lead to errors when used with via(gzip)
    while (<$FILEHANDLE>) {
        $serialized .= $_;
    }

    if ( $opened ) {
        close($FILEHANDLE);
    }

    # my $retrieved_doc = Storable::retrieve_fd(*$FILEHANDLE) or log_fatal($!);
    my $retrieved_doc = Storable::thaw($serialized) or log_fatal $!;

    if ( not ref($file) ) {
        $retrieved_doc->set_loaded_from($file);
        my ( $volume, $dirs, $file_name ) = File::Spec->splitpath($file);
        $retrieved_doc->set_path( $volume . $dirs );

        # $retrieved_doc->changeFilename($file); # why this doesn't affect the name displayed in TrEd?
    }

    # *.streex files saved before r8789 (2012-05-29) have no PML types with nodes, let's fix it
    # TODO: delete this hack as soon as no such old streex files are needed.
    foreach my $bundle ( $retrieved_doc->get_bundles() ) {
        foreach my $bundlezone ( $bundle->get_all_zones() ) {
            foreach my $node ( map { $_->get_descendants() } $bundlezone->get_all_trees() ) {

                # skip this hack if we are dealing with a new streex file
                #return $retrieved_doc if $node->type;
                # This shortcut does not work since old files have only *some* nodes without types
                $node->fix_pml_type();
            }
        }
    }

    return $retrieved_doc;
}

__PACKAGE__->meta->make_immutable;

1;

__END__



=for Pod::Coverage BUILD build_file_number description set_description

=encoding utf-8

=head1 NAME

Treex::Core::Document - representation of a text and its linguistic analyses in the Treex framework

=head1 DESCRIPTION

A document consists of a sequence of bundles, mirroring a sequence
of natural language sentences (typically, but not necessarily,
originating from the same text). Attributes (attribute-value pairs)
can be attached to a document as a whole.

=head1 ATTRIBUTES

C<Treex::Core::Document>'s instances have the following attributes:

=over 4

=item description

Textual description of the file's content that is stored in the file.

=item loaded_from

=item path

=item file_stem

=item file_number

=back

The attributes can be accessed using semi-affordance accessors:
getters have the same names as attributes, while setters start with
C<set_>. For example, the attribute C<path> has a getter C<path()> and a setter C<set_path($path)>



=head1 METHODS

=head2 Constructor

=over 4

=item  my $new_document = Treex::Core::Document->new;

creates a new empty document object.

=item  my $new_document = Treex::Core::Document->new( { pmldoc => $pmldoc } );

creates a C<Treex::Core::Document> instance from an already existing L<Treex::PML::Document> instance

=item  my $new_document = Treex::Core::Document->new( { filename => $filename } );

loads a C<Treex::Core::Document> instance from a .treex file

=back


=head2 Access to zones

Document zones are instances of L<Treex::Core::DocZone>, parametrized
by language code and possibly also by another free label
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

=item $document->index_node_by_id( $id, $node );

The node is added to the document's indexing table C<id2node> (it is done
automatically in L<Treex::Core::Node::set_attr()|Treex::Core::Node/set_attr>
if the attribute name is 'C<id>'). When using C<undef> in the place of the
second argument, the entry for the given id is deleted from the hash.


=item my $node = $document->get_node_by_id( $id );

Return the node which has the value C<$id> in its 'C<id>' attribute,
no matter to which tree and to which bundle in the given document
the node belongs to.

It is prohibited in Treex for IDs to point outside of the current document.
In rare cases where your data has such links, we recommend you to split the
documents differently or hack it by dropping the problematic links.

=item $document->id_is_indexed( $id );

Return C<true> if the given C<id> is already present in the indexing table.

=item $document->get_all_node_ids();

Return the array of all node identifiers indexed in the document.

=item $document->get_references_to_id( $id );

Return all references leading to the given node id in a hash (keys are reference types, e.g. 'alignment',
'a/lex.rf' etc., values are arrays of nodes referencing this node).

=item $document->remove_refences_to_id( $id );

Remove all references to the given node id (calls remove_reference() on each referencing node).

=back

=head2 Serializing

=over 4

=item my $document = load($filename, \%opts)

Loads document from C<$filename> given C<%opts> using L<Treex::PML::Document::load()>

=item $document->save($filename)

Saves document to C<$filename> using L<Treex::PML::Document::save()>,
or by the Storable module if the file's extension is .streex.gz.

=item Treex::Core::Document->retrieve_storable($filename)

Loading a document from the .streex (Storable) format.

=back

=head2 Other

=over 4

=item my $filename = $doc->full_filename;

full filename without the extension

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
