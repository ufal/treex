package Treex::Block::Read::AlksnisPML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML; # Without this, the following use Treex::PML::Instance generates many warnings, e.g. "Can't locate PML.pm"
use Treex::PML::Factory;
use Treex::PML::Instance;

has '+_layers'      => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.pml(\.gz)?$' );
has '+schema_dir'   => ( required => 0, builder => '_build_schema_dir' );
has 'language'      => ( is => 'ro', isa => 'Treex::Type::LangCode', required=>1 );

sub _build_schema_dir
{
    my ($self) = @_;
    my $path = __FILE__;
    $path =~ s/[^\/]+$//;
    $path .= '/PDT_schema';
    log_fatal "Cannot find schema in $path, please specify schema_dir explicitly" if !-d $path;
    Treex::PML::AddResourcePath($path);
    return $path;
}

sub _build_layers
{
    return ['a'];
}

override '_load_all_files' => sub
{
    my $self = shift;
    my $base_filename = shift;
    my %pmldoc;
    my $filename = "$base_filename.pml";
    if(!-e $filename)
    {
        $filename .= '.gz';
    }
    log_info("Loading $filename");
    ###!!! Do we need to maintain a hash of layers?
    $pmldoc{a} = $self->_pmldoc_factory()->createDocumentFromFile($filename);
    return \%pmldoc;
};

override '_convert_all_trees' => sub
{
    my $self = shift;
    my $pmldoc = shift;
    my $document = shift;
    # Get the number of trees.
    my $trees = $pmldoc->{a};
    my $n_trees = scalar($trees->trees());
    # Convert the trees one-by-one.
    for(my $i = 0; $i < $n_trees; $i++)
    {
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone($self->language(), $self->selector());
        my $root = $zone->create_atree();
        ###!!! Read::PDT would now call _convert_mtree (or atree or ttree) from BasePMLReader.
        ###!!! But those methods expect node attributes from the PML schema of the Prague Dependency Treebank.
        ###!!! Our schema is different.
        $self->_convert_tree($pmldoc->{a}->tree($i), $root);
        $zone->set_sentence($root->get_subtree_string());
    }
    return;
};

sub _convert_tree
{
    my $self = shift;
    my $pml_node = shift;
    my $treex_node = shift;
    foreach my $attr_name ('id', 'ord')
    {
        $self->_copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
    }
    $self->_copy_attr($pml_node, $treex_node, 'syfun', 'deprel');
    if(!$treex_node->is_root())
    {
        foreach my $attr_name ('form', 'lemma')
        {
            $self->_copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
        }
        $self->_copy_attr($pml_node, $treex_node, 'ana', 'tag');
        #$self->_copy_attr($pml_node, $treex_node, 'role', 'functor');
    }
    foreach my $pml_child ($pml_node->children())
    {
        my $treex_child = $treex_node->create_child();
        $self->_convert_tree($pml_child, $treex_child);
    }
    # It is not guaranteed that the ord values in the input tree form a 1..N sequence.
    if($treex_node->is_root())
    {
        $treex_node->_normalize_node_ordering();
    }
}

override '_create_val_refs' => sub
{
    my $self = shift;
    my $pmldoc = shift;
    my $document = shift;
    # We do not do anything with valency dictionaries.
    # But we must override this method to make BasePMLReader happy.
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Read::AlksnisPML

=head1 DESCRIPTION

Imports trees from the PML format of the Alksnis treebank (Lithuanian).
Based on Ondřej Dušek's PDT reader.

=head1 PARAMETERS

=over

=item schema_dir

Must be set to the directory with a corresponding PML schema.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University, Prague
