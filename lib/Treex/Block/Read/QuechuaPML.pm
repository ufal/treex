# The Quechua treebank by Annette Rios is versioned on Github:
# https://github.com/a-rios/squoia/tree/master/treebanks
# Its PML schema is called "quz_schema.xml".
package Treex::Block::Read::QuechuaPML;
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

has 'last_loaded_from' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'     => ( is => 'rw', isa => 'Int', default => 0 );



#------------------------------------------------------------------------------
# The parameter '_schema_dir' is required by BasePMLReader.
###!!! Do we need it? We have a single schema file, not an entire folder.
#------------------------------------------------------------------------------
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



#------------------------------------------------------------------------------
# The parameter '_layers' is required by BasePMLReader. We do not need it as
# the Quechua treebanks operates on a single layer but we must supply it.
#------------------------------------------------------------------------------
sub _build_layers
{
    return ['a'];
}



#------------------------------------------------------------------------------
# Loads all files corresponding to one document. In multi-layer PML schemes
# like PDT, each layer would have its own file (w, m, a, t) and there would be
# references to elements on other layers. Here we just read the single file
# that we have.
#------------------------------------------------------------------------------
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



#------------------------------------------------------------------------------
# Loops over trees in a PML document and converts them one-by-one.
#------------------------------------------------------------------------------
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
        # Read::PDT would now call _convert_mtree (or atree or ttree) from BasePMLReader.
        # But those methods expect node attributes from the PML schema of the Prague Dependency Treebank.
        # Our schema is different.
        $self->_convert_tree($pmldoc->{a}->tree($i), $root);
        $zone->set_sentence($root->get_subtree_string());
    }
    return;
};



#------------------------------------------------------------------------------
# Converts a tree of PML elements to a linguistic analytical tree.
#------------------------------------------------------------------------------
sub _convert_tree
{
    my $self = shift;
    my $pml_node = shift;
    my $treex_node = shift;
    # Somewhat misleadingly, the PML schema categorizes nodes as terminals and
    # nonterminals. However, this does not mean that the tree is phrase-based.
    # The nonterminal type seems to be reserved solely for the artificial
    # sentence root. All other nodes are terminal, although they can have
    # children.
    ###!!! We are not prepared for multiple roots per sentence, although the
    ###!!! schema does not exclude them!
    my $root_here = 0;
    if($treex_node->is_root())
    {
        $root_here = 1;
        $treex_node->set_attr('ord', 0);
    }
    else
    {
        $self->_copy_attr($pml_node, $treex_node, 'order', 'ord');
        $self->_copy_attr($pml_node, $treex_node, 'word', 'form');
        $self->_copy_attr($pml_node, $treex_node, 'pos', 'tag');
        # Besides <pos>, there is also <morph>. Elements of <morph> are <tag>
        # and there can be more than one <tag> in a <morph>. Example:
        #   <word>masicha</word>
        #   <translation>=compañero</translation>
        #   <pos>Root_VS</pos>
        #   <morph>
        #     <tag>NRoot</tag>
        #     <tag>+Fact</tag>
        #   </morph>
        my $morph_tags = join('|', $pml_node->attr('morph'));
        $treex_node->set_attr('conll/feat', $morph_tags);
        $self->_copy_attr($pml_node, $treex_node, 'translation', 'gloss');
        $self->_copy_attr($pml_node, $treex_node, 'label', 'deprel');
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



#------------------------------------------------------------------------------
# We must override this method because we are derived from BasePMLReader,
# regardless of the fact that we do not do anything with valency dictionaries.
#------------------------------------------------------------------------------
override '_create_val_refs' => sub
{
    my $self = shift;
    my $pmldoc = shift;
    my $document = shift;
};



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Read::QuechuaPML

=head1 DESCRIPTION

Imports trees from the PML format of the Quechua treebank.
Based on Ondřej Dušek's PDT reader.

The Quechua treebank by Annette Rios is versioned on Github:
L<https://github.com/a-rios/squoia/tree/master/treebanks>
Its PML schema is called C<quz_schema.xml>.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague
