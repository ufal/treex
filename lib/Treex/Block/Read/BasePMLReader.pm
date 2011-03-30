package Treex::Block::Read::BasePMLReader;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

# PML operations
has _pmldoc_factory => ( is => 'ro', isa => 'Object', default => sub { Treex::PML::Factory->new(); } );

# Layers used in the conversion (must be overriden!)
has _layers => ( traits => ['Array'], is => 'ro', isa => 'ArrayRef[Str]', required => 1 );

# The file suffix pattern for files that are to be included in the conversion (must be overriden!)
has _file_suffix => ( is => 'ro', isa => 'Str', required => 1 );

has schema_dir => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'directory with pml-schemata for PCEDT data',
    required      => 1,
    trigger       => sub { my ( $self, $dir ) = @_; Treex::PML::AddResourcePath($dir); }
);

sub _copy_attr {
    my ( $self, $pml_node, $treex_node, $old_attr_name, $new_attr_name ) = @_;
    $treex_node->set_attr( $new_attr_name, $pml_node->attr($old_attr_name) );
    return;
}

sub _copy_list_attr {
    my ( $self, $pml_node, $treex_node, $old_attr_name, $new_attr_name, $ref ) = @_;
    my $list = $pml_node->attr($old_attr_name);
    return if not ref $list;

    if ($ref) {
        foreach (@$list) {s/^.*#//;}
    }
    $treex_node->set_attr( $new_attr_name, $list );
    return;
}

sub _convert_ttree {
    my ( $self, $pml_node, $treex_node, $language ) = @_;

    if ( $treex_node->is_root ) {
        my $value = $pml_node->attr('atree.rf');
        $value =~ s/^.*#//;
        $treex_node->set_attr( 'atree.rf', $value );

        foreach my $attr_name ( 'id', 'nodetype' ) {
            $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
    }

    else {
        my @scalar_attribs = (
            't_lemma', 'functor', 'id', 'nodetype', 'is_generated', 'subfunctor', 'is_member', 'is_name',
            'is_name_of_person', 'is_dsp_root', 'sentmod', 'tfa', 'is_parenthesis', 'is_state',
            'coref_special'
        );
        my @gram_attribs = (
            'sempos', 'gender', 'number', 'degcmp', 'verbmod', 'deontmod', 'tense', 'aspect', 'resultative',
            'dispmod', 'iterativeness', 'indeftype', 'person', 'numertype', 'politeness', 'negation'
        );
        my @list_attribs = (
            'compl.rf', 'coref_text.rf', 'coref_gram.rf', 'a/aux.rf'
        );

        $self->_copy_attr( $pml_node, $treex_node, 'deepord', 'ord' );

        foreach my $attr_name ( 'a/lex.rf', 'val_frame.rf' ) {
            my $value = $pml_node->attr($attr_name);
            next if not $value;
            $value =~ s/^.*#//;
            $value = ( $language ? $language . '-' : '' ) . 'v#' . $value if $attr_name eq 'val_frame.rf';    # lang prefixes for val_frames
            $treex_node->set_attr( $attr_name, $value );
        }

        foreach my $attr_name (@scalar_attribs) {
            $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
        foreach my $attr_name (@list_attribs) {
            $self->_copy_list_attr( $pml_node, $treex_node, $attr_name, $attr_name, 1 );
        }

        my %gram = ();
        foreach my $attr_name (@gram_attribs) {
            my $value = $pml_node->attr("gram/$attr_name");
            $gram{$attr_name} = $value if $value;
        }
        while ( my ( $attr_name, $value ) = each %gram ) {
            $treex_node->set_attr( "gram/$attr_name", $value );
        }
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child;
        $self->_convert_ttree( $pml_child, $treex_child, $language );
    }
    return;
}

sub _convert_atree {
    my ( $self, $pml_node, $treex_node ) = @_;

    foreach my $attr_name ( 'id', 'ord', 'afun' ) {
        $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
    }

    if ( not $treex_node->is_root ) {
        $self->_copy_attr( $pml_node, $treex_node, 'm/w/no_space_after', 'no_space_after' );
        foreach my $attr_name ( 'form', 'lemma', 'tag' ) {
            $self->_copy_attr( $pml_node, $treex_node, "m/$attr_name", $attr_name );
        }
        foreach my $attr_name ( 'is_member', 'is_parenthesis_root' ) {
            $self->_copy_attr( $pml_node, $treex_node, "$attr_name", $attr_name );
        }
        if ( $pml_node->attr('p') ) {
            my $value = $pml_node->attr('p/terminal.rf');
            $value =~ s/^.*#//;
            $treex_node->set_attr( 'p/terminal.rf', $value );
            $self->_copy_list_attr( $pml_node, $treex_node, 'p/nonterminals.rf', 'p/nonterminals.rf', 1 );
        }
    }
    elsif ( $pml_node->attr('ptree.rf') ) {
        $self->_copy_attr( $pml_node, $treex_node, 'ptree.rf', 'ptree.rf' );
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child;
        $self->_convert_atree( $pml_child, $treex_child );
    }
    return;
}

# the actual conversion of all trees from all layers
sub _convert_all_trees {
    my ($self) = @_;
    log_fatal('Block does not override the method _convert_all_trees.');
}

# create reference(s) to valency dictionar(y/ies)
sub _create_val_refs {
    my ($self) = @_;
    log_fatal('Block does not override the method _create_val_refs.');
}

# for each document, load all the needed files for all layers to the memory
sub _load_all_files {
    my ($self) = @_;
    log_fatal('Block does not override the method _load_all_files.');
}

sub next_document {

    my ($self) = @_;

    my $base_filename = $self->next_filename or return;
    my $suffix = $self->_file_suffix;
    $base_filename =~ s/$suffix//;

    my $pmldoc = $self->_load_all_files($base_filename);

    my $document = $self->new_document();    # pre-fills base name, path
    $base_filename =~ s/.*\///;
    $base_filename =~ s/_$//;
    $document->set_file_stem($base_filename);

    $self->_create_val_refs( $pmldoc, $document );

    $self->_convert_all_trees( $pmldoc, $document );

    return $document;
}

1;
__END__

=head1 Treex::Block::Read::BasePMLReader

Abstract base class for readers importing from PML trees (PDT, PCEDT). 

All derived classes must override the methods C<_convert_all_trees>, C<_create_val_refs>, C<_load_all_files> 
and the attributes C<_layers> and C<_file_suffix>.

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=back
  
=cut

# Copyright 2011 Zdenek Zabokrtsky, Josef Toman, Martin Popel, Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
