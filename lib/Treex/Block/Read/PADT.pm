package Treex::Block::Read::PADT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.syntax\.pml(\.gz)?$' );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1, default => 'ar' );

sub _build_layers
{
    my ($self) = @_;
    ###!!!return ['a'];
    return ['words', 'morpho', 'syntax'];
}



#------------------------------------------------------------------------------
# For each document, reads all necessary files for all layers to memory.
#------------------------------------------------------------------------------
override '_load_all_files' => sub
{
    my $self = shift;
    my $base_filename = shift;
    my %pmldoc;
    # There are three layers: words, morpho, syntax
    foreach my $layer (@{$self->_layers()})
    {
        my $filename = "${base_filename}.${layer}.pml";
        if (!-e $filename)
        {
            $filename .= '.gz';
        }
        log_info("Loading $filename");
        $pmldoc{$layer} = $self->_pmldoc_factory()->createDocumentFromFile($filename);
    }
    return \%pmldoc;
};



#------------------------------------------------------------------------------
# Converts all trees in all layers to the Treex format.
#------------------------------------------------------------------------------
override '_convert_all_trees' => sub
{
    my $self = shift;
    my $pmldoc = shift;
    my $document = shift;
    my $ntrees = $pmldoc->{syntax}->trees();
    for(my $tree_number = 0; $tree_number<$ntrees; $tree_number++)
    {
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone($self->language(), $self->selector());
        my $aroot = $zone->create_atree();
        $self->_convert_atree($pmldoc->{syntax}->tree($tree_number), $aroot);
        $zone->set_sentence($aroot->get_subtree_string());
    }
};



#------------------------------------------------------------------------------
# We must override the method that creates references to valency dictionary.
# We do not expect any such references in the current version of PADT, so the
# overridden method is empty.
#------------------------------------------------------------------------------
override '_create_val_refs' => sub
{
    my ( $self, $pmldoc, $document ) = @_;
    return;
};

1;

__END__

=head1 Treex::Block::Read::PADT

Import trees from the Prague Arabic Dependency Treebank 2.0 (not released, converted to PML by Otakar Smrž and stored in an svn repository at ÚFAL;
a working copy might be in C</net/projects/padt>).

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=item t_layer

Must be set to 0 if t-layer is not available or is not needed.

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
