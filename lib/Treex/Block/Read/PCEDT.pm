package Treex::Block::Read::PCEDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

has p_layer => ( isa => 'Bool', is => 'ro', default => 1, documentation=> 'Do we have phrase-structure trees? Should we load *.p.gz files?');
# layers: analytical, tectogrammatical, constituent (p-) trees
has '+_layers' => ( default => sub { [ 'a', 't', 'p' ] } );

# Czech and English
has _languages => ( traits => ['Array'], is => 'ro', isa => 'ArrayRef[Str]', required => 1, default => sub { [ 'cs', 'en' ] } );

has '+_file_suffix' => ( default => '(en|cs)\.[atp]\.gz$' );

# convert p-trees
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
        my $treex_child;
        if ($pml_child->attr('#name') eq 'nonterminal') {
            $treex_child = $treex_node->create_nonterminal_child();
        }
        else {
            $treex_child = $treex_node->create_terminal_child();
        }
        $self->_convert_ptree( $pml_child, $treex_child );
    }
    return;
}

override '_load_all_files' => sub {

    my ( $self, $base_filename ) = @_;
    my %pmldoc;

    foreach my $language ( @{ $self->_languages } ) {
        foreach my $layer ( @{ $self->_layers } ) {
            next if $layer eq 'p' and $language eq 'cs';
            my $filename = "${base_filename}$language.${layer}.gz";
            log_info "Loading $filename";
            $pmldoc{$language}{$layer} = $self->_pmldoc_factory->createDocumentFromFile($filename);
        }
    }

    log_fatal "different number of trees in Czech and English t-files"
        if $pmldoc{en}{t}->trees != $pmldoc{cs}{t}->trees;

    return \%pmldoc;
};

override '_create_val_refs' => sub {
    my ( $self, $pmldoc, $document ) = @_;

    my $cs_vallex = $pmldoc->{cs}{t}->metaData('refnames')->{'vallex'};
    $cs_vallex = $pmldoc->{cs}{t}->metaData('references')->{$cs_vallex};
    my $en_vallex = $pmldoc->{en}{t}->metaData('refnames')->{'vallex'};
    $en_vallex = $pmldoc->{en}{t}->metaData('references')->{$en_vallex};

    my ( %refnames, %refs );
    $refnames{'vallex'} = $self->_pmldoc_factory->createAlt( [ 'cs-v', 'en-v' ] );
    $refs{'cs-v'}       = $cs_vallex;
    $refs{'en-v'}       = $en_vallex;
    $document->changeMetaData( 'references', \%refs );
    $document->changeMetaData( 'refnames',   \%refnames );

    return;
};

override '_convert_all_trees' => sub {

    my ( $self, $pmldoc, $document ) = @_;

    foreach my $tree_number ( 0 .. ( $pmldoc->{en}{t}->trees - 1 ) ) {

        my $bundle = $document->create_bundle;
        foreach my $language ( @{ $self->_languages } ) {
            my $zone = $bundle->create_zone($language);

            my $troot = $zone->create_ttree;
            $self->_convert_ttree( $pmldoc->{$language}{t}->tree($tree_number), $troot, $language );

            my $aroot = $zone->create_atree;
            $self->_convert_atree( $pmldoc->{$language}{a}->tree($tree_number), $aroot );

            $zone->set_sentence( $aroot->get_subtree_string );

            if ( $self->p_layer && $language eq 'en' ) {
                my $proot = $zone->create_ptree;
                $self->_convert_ptree( $pmldoc->{$language}{p}->tree($tree_number), $proot );

                foreach my $p_node ( $proot, $proot->get_descendants ) {
                    my $type = $p_node->get_pml_type_name();
                    $type =~ s/p-(.*)\.type/$1/;
                    $p_node->{'#name'} = $type;
                }
            }
        }
    }

    return;
};

1;

__END__

=head1 Treex::Block::Read::PCEDT

Import from PCEDT trees. 

Adds handling two languages and p-trees to the behavior of BasePMLReader. 

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=back
  
=cut

# Copyright 2011 Zdenek Zabokrtsky, Josef Toman, Martin Popel, Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

