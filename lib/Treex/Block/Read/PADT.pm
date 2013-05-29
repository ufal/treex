package Treex::Block::Read::PADT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;
use Encode::Arabic::Buckwalter;
###!!! DZ: How to do this properly? Should we add this to the list of Treex libraries? Or should we move the Perl modules?
require 'Treex/Core/share/tred_extension/elixir/libs/ElixirFM.pm';

has '+schema_dir' => ( builder => '_build_schema_dir', lazy_build => 0 );
has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.syntax\.pml(\.gz)?$' );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1, default => 'ar' );

sub _build_schema_dir
{
    # Compute the path to the PML schemas relative to this block.
    my $rootpath = $INC{'Treex/Block/Read/PADT.pm'};
    $rootpath =~ s-/PADT\.pm$--;
    my $relpath = 'PADT_schema';
    my $fullpath = "$rootpath/$relpath";
    if(-d $fullpath)
    {
        log_info("Adding $fullpath to Treex::PML resource paths.");
        Treex::PML::AddResourcePath($fullpath);
        return $fullpath;
    }
}

sub _build_layers
{
    my ($self) = @_;
    ###!!!return ['a'];
    #return ['words', 'morpho', 'syntax'];
    return ['syntax'];
}



#------------------------------------------------------------------------------
# For each document, reads all necessary files for all layers into memory.
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



my %cpos =
(
    'N' => 'noun',
    'A' => 'adj',
    'S' => 'pron',
    'Q' => 'num',
    'V' => 'verb',
    'D' => 'adv',
    'P' => 'prep',
    'C' => 'conj',
    'F' => 'part',
    'I' => 'int',
    'G' => 'punc',
    'X' => 'foreign',
    'Y' => 'acronym',
    'Z' => 'zeroinfl',
    'U' => 'unk' # unknown (OOV) word; this tag added by this block, not present in the original data
);
sub tag2cpos
{
    my $tag = shift;
    return '_' if(!defined($tag));
    my $fc = substr($tag, 0, 1);
    return exists($cpos{$fc}) ? $cpos{$fc} : '_'.$fc.'_';
}



#------------------------------------------------------------------------------
# Converts an a-tree from the PADT PML structure to the Treex structure.
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
        my @features;
        # Attributes from the morphological layer.
        # Tokens recognized by the morphological analyzer have their form transliterated to the Latin script.
        # Out-of-vocabulary words have the original form, i.e. unvocalized Arabic script.
        # Out-of-vocabulary words do not have the 'm' section. We have to go directly to the 'w' layer.
        if(!defined($pml_node->attr('m')))
        {
            my $aform = $pml_node->attr('w/form');
            my $rform = Encode::Arabic::Buckwalter::encode('buckwalter', $aform);
            $treex_node->set_form($aform);
            $treex_node->set_attr('translit', $rform);
            $treex_node->set_lemma($aform);
            $treex_node->set_tag('U---------');
            $rform =~ s/\s+/_/g;
            $rform =~ s/\|/:/g;
            push(@features, 'rform='.$rform);
            push(@features, 'root=OOV');
        }
        else
        {
            foreach my $attr_name ('form', 'lemma', 'tag')
            {
                $self->_copy_attr($pml_node, $treex_node, "m/$attr_name", $attr_name);
            }
            # Transliterate form and lemma to vocalized Arabic script.
            # (The data contain words and tokens, whereas tokens are subunits of words.
            # The forms of words are stored in unvocalized Arabic script as they were on input.
            # The forms and lemmas of tokens are vocalized and romanized, so we must use ElixirFM to provide the Arabic script for them.)
            if(defined($treex_node->form()))
            {
                my $aform = ElixirFM::orth($treex_node->form());
                my $rform = ElixirFM::phon($treex_node->form());
                push(@features, 'rform='.$rform);
                $treex_node->set_attr('translit', $rform);
                $treex_node->set_form($aform);
            }
            if(defined($treex_node->lemma()))
            {
                my $alemma = ElixirFM::orth($treex_node->lemma());
                my $rlemma = ElixirFM::phon($treex_node->lemma());
                push(@features, 'rlemma='.$rlemma);
                $treex_node->{wild}{translit_lemma} = $rlemma;
                $treex_node->set_lemma($alemma);
            }
            # Copy English glosses from the reflex element.
            # m/core/reflex has type Treex::PML::List=ARRAY.
            my $glosses = $pml_node->attr('m/core/reflex');
            if(defined($glosses))
            {
                my $gloss = join(',', map {s/\s+/_/g; $_;} @{$glosses});
                $treex_node->{wild}{gloss} = $gloss;
                push(@features, 'gloss='.$gloss);
            }
            # Attributes specific to Arabic morphology.
            if(defined($pml_node->attr('m/root')))
            {
                my $root = $pml_node->attr('m/root');
                $treex_node->{wild}{root} = $root;
                $root =~ s/\s+/_/g;
                $root =~ s/\|/:/g;
                push(@features, 'root='.$root);
            }
            if(defined($pml_node->attr('m/morphs')))
            {
                my $morphs = $pml_node->attr('m/morphs');
                $treex_node->{wild}{morphs} = $morphs;
                #$morphs =~ s/\s+/_/g;
                #$morphs =~ s/\|/:/g;
                #push(@features, 'morphs='.$morphs);
            }
        }
        if(defined($treex_node->tag()))
        {
            $treex_node->set_conll_cpos(tag2cpos($treex_node->tag()));
            $treex_node->set_conll_pos($treex_node->tag());
            # Decompose morphological tag to CoNLL features, except for part of speech.
            # It will facilitate training of the Malt Parser.
            my @tagchars = split(//, $treex_node->tag());
            for(my $i = 1; $i<=$#tagchars; $i++)
            {
                push(@features, "f$i=$tagchars[$i]") unless($tagchars[$i] eq '-');
            }
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
        # Attributes from the syntactic (analytical) layer.
        # The 'parallel' attribute in PADT has values 'Co' (coordination) and 'Ap' (apposition).
        # We cannot simply copy the value to 'is_member'; we need a boolean value instead.
        if($pml_node->attr('parallel'))
        {
            $treex_node->set_is_member(1);
        }
        if($pml_node->attr('paren'))
        {
            $treex_node->set_is_parenthesis_root(1);
        }
        if(defined($treex_node->afun()))
        {
            my $deprel = $treex_node->afun();
            if($pml_node->attr('parallel'))
            {
                $deprel .= '_'.$pml_node->attr('parallel');
            }
            if($pml_node->attr('paren'))
            {
                $deprel .= '_'.$pml_node->attr('paren');
            }
            $treex_node->set_conll_deprel($deprel);
        }
        if($pml_node->attr('coref'))
        {
            $treex_node->{wild}{coref} = $pml_node->attr('coref');
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

Example:

PADT=/net/projects/padt/data/Prague
treex Read::PADT 'from=$PADT/AEP/UMH_ARB_20040407.0001.syntax.pml' schema_dir=$PADT/syntax.schema.xml Write::CoNLLX deprel_attribute=conll/deprel > pokus.ar.conll

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.
By default, the directory is expected in a path relative to the location of this block.

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
