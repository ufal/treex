package Treex::Block::Read::PEDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

has '+_file_suffix' => ( default => '\.[atp]\.gz$' );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', default => 'en' );

has p_layer => ( isa => 'Bool', is => 'ro', default => 1, documentation=> 'Do we have phrase-structure trees? Should we load *.p.gz files?');

has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
sub _build_layers {
    my ($self) = @_;
    if ($self->p_layer){
        return [ 'a', 't', 'p' ];
    }
    else{
        return ['a', 't'];
    }
}

has '+schema_dir' => ( builder => '_build_schema_dir', lazy_build => 0 );
sub _build_schema_dir
{
    # Compute the path to the PML schemas relative to this block.
    # TODO this solution is taken from Read::PADT, but it is not suitable for CPAN.
    my $rootpath = $INC{'Treex/Block/Read/PEDT.pm'};
    $rootpath =~ s-/PEDT\.pm$--;
    my $relpath = 'PEDT_schema';
    my $fullpath = "$rootpath/$relpath";
    if(-d $fullpath)
    {
        log_info("Adding $fullpath to Treex::PML resource paths.");
        Treex::PML::AddResourcePath($fullpath);
        return $fullpath;
    }
}


override '_load_all_files' => sub {

    my ( $self, $base_filename ) = @_;
    my %pmldoc;

    foreach my $layer ( @{ $self->_layers } ) {
        my $filename = "${base_filename}.${layer}.gz";
        log_info "Loading $filename";
        $pmldoc{$layer} = $self->_pmldoc_factory->createDocumentFromFile($filename);
    }
    return \%pmldoc;

};

override '_create_val_refs' => sub {

    my ( $self, $pmldoc, $document ) = @_;

    return if not $pmldoc->{t};

    my $engvallex = $pmldoc->{t}->metaData('refnames')->{'vallex'};
    $engvallex = $pmldoc->{t}->metaData('references')->{$engvallex};

    my ( %refnames, %refs );
    $refnames{'vallex'} = $self->_pmldoc_factory->createAlt( ['v'] );
    $refs{'v'} = $engvallex;
    $document->changeMetaData( 'references', \%refs );
    $document->changeMetaData( 'refnames',   \%refnames );

};

override '_convert_all_trees' => sub {

    my ( $self, $pmldoc, $document ) = @_;

    foreach my $tree_number ( 0 .. ( $pmldoc->{t}->trees - 1 ) ) {

        my $bundle = $document->create_bundle;
        my $zone = $bundle->create_zone( $self->language, $self->selector );

        my $troot = $zone->create_ttree;
        $self->_convert_ttree( $pmldoc->{t}->tree($tree_number), $troot, undef );
        $self->_finish_ttree( $pmldoc->{t}->tree($tree_number), $troot );

        my $aroot = $zone->create_atree;
        $self->_convert_atree( $pmldoc->{a}->tree($tree_number), $aroot );

        if ($self->p_layer){
            my $proot = $zone->create_ptree;
            $self->_convert_ptree( $pmldoc->{p}->tree($tree_number), $proot );

            foreach my $p_node ( $proot, $proot->get_descendants ) {
                my $type = $p_node->get_pml_type_name();
                $type =~ s/p-(.*)\.type/$1/;
                $p_node->{'#name'} = $type;
            }
        }

      $zone->set_sentence( $aroot->get_subtree_string );
  }

};

sub _finish_ttree {
    my ( $self, $pml_node, $treex_node ) = @_;

    if ( not $treex_node->is_root ) {
        foreach my $attr_name ('nombank_data', 'bbn_tag') {
            $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->get_document->get_node_by_id( $pml_child->attr('id') );
        $self->_finish_ttree( $pml_child, $treex_child );
    }
    return;
};

sub _convert_ptree {
    my ( $self, $pml_node, $treex_node ) = @_;

    foreach my $attr_name ( 'id', 'index', 'coindex', 'is_head' ) {
        $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
    }

    my $key = $pml_node->attr('phrase') ? 'phrase' : 'tag';
    $self->_copy_attr( $pml_node, $treex_node, $key, $key );

    if ( $treex_node->get_pml_type_name() =~ m/nonterminal/ ) {
        $self->_copy_list_attr( $pml_node, $treex_node, 'functions', 'functions' );
    }
    else {
        for my $attr_name ( 'form', 'lemma' ) {
            $self->_copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child();
        $self->_convert_ptree( $pml_child, $treex_child );
    }
    return;
}

1;

__END__

=head1 Treex::Block::Read::PEDT

Import from PEDT 2.0 trees.

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=back
  
=cut

# Copyright 2011-2014 Josef Toman, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
