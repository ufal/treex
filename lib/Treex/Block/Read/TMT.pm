package Treex::Block::Read::TMT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

has '+schema_dir' => ( builder => '_build_schema_dir', lazy_build => 0 );
has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.tmt(\.gz)?$' );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

sub _build_schema_dir
{
    # Compute the path to the PML schemas relative to this block.
    my $rootpath = $INC{'Treex/Block/Read/TMT.pm'};
    $rootpath =~ s-/TMT\.pm$--;
    my $relpath = 'TMT_schema';
    my $fullpath = "$rootpath/$relpath";
    if(-d $fullpath)
    {
        log_info("Adding $fullpath to Treex::PML resource paths.");
        Treex::PML::AddResourcePath($fullpath);
        return $fullpath;
    }
}

# This method (as well as the layers attribute) is probably not needed for TMT files.
sub _build_layers
{
    my ($self) = @_;
    # There are several layers in TectoMT: ['m', 'a', 't', 'n', 'p'];
    # But all of them are in one tmt file and that is what we will read.
    # (We will only access the 'a' layer in that file.)
    return ['tmt'];
}



#------------------------------------------------------------------------------
# For each document, reads all necessary files for all layers into memory.
#------------------------------------------------------------------------------
override '_load_all_files' => sub
{
    my $self = shift;
    my $base_filename = shift;
    my %pmldoc;
    my $filename = "${base_filename}.tmt";
    if (!-e $filename)
    {
        $filename .= '.gz';
    }
    log_info("Loading $filename");
    # Read the TMT document.
    $pmldoc{'tmt'} = $self->_pmldoc_factory()->createDocumentFromFile($filename);
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
    # The method trees will return the array of top-level LM elements.
    # In the case of a TMT file, these are bundles (but they differ from Treex bundles).
    my @tmtbundles = $pmldoc->{tmt}->trees();
    # Each TMT bundle can have a list of trees; but these are only the predefined
    # Czech or English trees. For a generic any-language file, this list will be empty.
    # Instead, we have to look for an element called <generic_subbundles> and
    # its children of the form <generic_subbundle language="ta" direction="S">.
    # In the specific case of the Tamil Treebank, we can assume that there is
    # always just one generic subbundle with language "ta" and direction "S".
    if($self->language() ne 'ta')
    {
        log_warn('The Read::TMT block was created to read the Tamil Treebank and it has not been made general enough to read any TMT file.');
    }
    foreach my $tmtbundle (@tmtbundles)
    {
        # The first child is <trees/>.
        # The second child is <generic_subbundles>.
        # Its first and only child is <generic_subbundle>.
        #my $subbundle = $tmtbundle->firstson()->rbrother()->firstson();
        my $subbundle = $tmtbundle->attr('generic_subbundles/generic_subbundle');
        log_fatal('Cannot find the generic subbundle.') if(!defined($subbundle));
        # The subbundle has two children:
        # <sentence>
        # <trees>
        # In the case of the Tamil Treebank, the trees are the following (each type occurs once):
        # <m_tree>
        # <a_tree>
        my $m_tree = $subbundle->firstson()->rbrother()->firstson();
        my $a_tree = $m_tree->rbrother();
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone($self->language(), $self->selector());
        my $root = $zone->create_atree();
        # We can ignore the m_tree because all morphological attributes are also
        # copied to the a_tree.
        $self->_convert_tree($m_tree, $root);
        $zone->set_sentence($root->get_subtree_string());
    }
};



#------------------------------------------------------------------------------
# Converts an a-tree from the TMT PML structure to the Treex structure.
# Recursive.
#------------------------------------------------------------------------------
override '_convert_atree' => sub
{
    my $self = shift;
    my $pml_node = shift; # where to copy attributes from
    my $treex_node = shift; # where to copy attributes to
    # The following attributes are present for all nodes including the root.
    foreach my $attr_name ('id', 'ord', 'afun')
    {
        $self->_copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
    }
    # The following attributes are present for non-root nodes.
    if(not $treex_node->is_root())
    {
        # Attributes from the morphological layer.
        $self->_copy_attr($pml_node, $treex_node, 'm/form', 'form');
        $self->_copy_attr($pml_node, $treex_node, 'm/lemma', 'lemma');
        $self->_copy_attr($pml_node, $treex_node, 'm/tag', 'tag');
        $self->_copy_attr($pml_node, $treex_node, 'm/no_space_after', 'no_space_after');
        # Attributes from the analytical layer.
        # We have already copied afun, which may exist also for the root, but let's also copy it to deprel, which we keep only for non-root nodes.
        $self->_copy_attr($pml_node, $treex_node, 'afun', 'deprel');
        $self->_copy_attr($pml_node, $treex_node, 'is_member', 'is_member');
        # Derive the CoNLL-X attributes from the tag.
        my @features;
        if(defined($treex_node->tag()))
        {
            $treex_node->set_conll_cpos(substr($treex_node->tag(), 0, 1));
            $treex_node->set_conll_pos($treex_node->tag());
            # Decompose morphological tag to CoNLL features, except for part of speech.
            my @tagchars = split(//, $treex_node->tag());
            my @feanames = ('POS', 'SubPOS', 'Cas', 'Ten', 'Per', 'Num', 'Gen', 'Voi', 'Neg');
            for(my $i = 2; $i<=8; $i++)
            {
                push(@features, "$feanames[$i]=$tagchars[$i]") unless(!defined($tagchars[$i]) || $tagchars[$i] eq '-');
            }
            $self->_copy_attr($pml_node, $treex_node, 'afun', 'conll/deprel');
        }
        else
        {
            $treex_node->set_conll_cpos('_');
            $treex_node->set_conll_pos('_');
        }
        if(@features)
        {
            $treex_node->set_conll_feat(join('|', @features));
        }
        else
        {
            $treex_node->set_conll_feat('_');
        }
    }
    # Recursively copy descendant nodes.
    foreach my $pml_child ($pml_node->children())
    {
        my $treex_child = $treex_node->create_child();
        $self->_convert_atree($pml_child, $treex_child);
    }
    return;
};



#------------------------------------------------------------------------------
# We must override the method that creates references to valency dictionary.
# We do not expect any such references in the TMT data, so the overridden
# method is empty.
#------------------------------------------------------------------------------
override '_create_val_refs' => sub
{
    my ( $self, $pmldoc, $document ) = @_;
    return;
};



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Read::TMT

=head1 DESCRIPTION

Imports trees from the old TMT (TectoMT) format. This block has been specifically
created to rescue the original data of the Tamil Treebank v0.1. At present the
block is not general enough to read any TMT file.

Example:

TAMILTB=/net/data/TamilTB/TamilTB.v0.1/data
treex Read::TMT schema_dir=TMT_schema from=$TAMILTB/TamilTB.v0.1.tmt Write::CoNLLX deprel_attribute=afun > pokus.ta.conll

=head1 PARAMETERS

=over

=item schema_dir

Must be set to the directory with the TMT PML schema.
By default, the directory is expected in a path relative to the location of this block.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague
