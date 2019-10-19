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
# ALKSNIS v2 (the first publicly released version) used schema "antisDplus_schema.pml".
# ALKSNIS v2.2 uses "AlksnisSchema-1.3.pml".
# There are some important differences in the schemas! Use the parameter schema_version=antisDplus_schema to toggle the old version.
has 'schema_version' => ( is => 'ro', isa => 'Str', default => 'AlksnisSchema-1.3', documentation => 'Use "antisDplus_schema" to toggle the old version.' );
has 'language'       => ( is => 'ro', isa => 'Treex::Type::LangCode', required=>1 );

has 'last_loaded_from' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'     => ( is => 'rw', isa => 'Int', default => 0 );

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
        # Make sure that the bundle id contains the name of the file.
        my $loaded_from = $document->loaded_from(); # the full path to the input file
        my $file_stem = $document->file_stem(); # this will be used in the comment
        if($loaded_from eq $self->last_loaded_from())
        {
            $self->set_sent_in_file($self->sent_in_file() + 1);
        }
        else
        {
            $self->set_last_loaded_from($loaded_from);
            $self->set_sent_in_file(1);
        }
        my $sent_in_file = $self->sent_in_file();
        $bundle->set_id("$file_stem-s$sent_in_file");
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
    # Unlike some other PML applications, Alksnis does not have a PML element
    # corresponding to the artificial root node. Therefore if we are in the
    # Treex root, we must create a child but keep the Alksnis root as the
    # source for the child.
    my $root_here = 0;
    if($treex_node->is_root())
    {
        $root_here = 1;
        $treex_node->set_attr('ord', 0);
        my $treex_child = $treex_node->create_child();
        $treex_node = $treex_child;
    }
    $self->_copy_attr($pml_node, $treex_node, 'word_ref', 'ord');
    if($self->schema_version() eq 'antisDplus_schema')
    {
        $self->_copy_attr($pml_node, $treex_node, 'form', 'form');
        $self->_copy_attr($pml_node, $treex_node, 'lemma', 'lemma');
        $self->_copy_attr($pml_node, $treex_node, 'ana', 'tag');
        $self->_copy_attr($pml_node, $treex_node, 'syfun', 'deprel');
    }
    else # AlksnisSchema-1.3
    {
        $self->_copy_attr($pml_node, $treex_node, 'token', 'form');
        $self->_copy_attr($pml_node, $treex_node, 'lemma', 'lemma');
        $self->_copy_attr($pml_node, $treex_node, 'morph', 'tag');
        $self->_copy_attr($pml_node, $treex_node, 'synt', 'deprel');
    }
    foreach my $pml_child ($pml_node->children())
    {
        my $treex_child = $treex_node->create_child();
        $self->_convert_tree($pml_child, $treex_child);
    }
    # It is not guaranteed that the ord values in the input tree form a 1..N sequence.
    if($root_here)
    {
        $treex_node->get_root()->_normalize_node_ordering();
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
