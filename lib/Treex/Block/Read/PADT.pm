package Treex::Block::Read::PADT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;
use Treex::Tool::ElixirFM;
use Encode::Arabic::Buckwalter;

has '+schema_dir' => ( builder => '_build_schema_dir', lazy_build => 0 );
has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.syntax\.pml(\.gz)?$' );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1, default => 'ar' );
has '_no_space_after' => ( isa => 'HashRef', is => 'rw', default => sub { {} }, documentation => 'hash word id => boolean space after wor no=1/yes=0|undef' );

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
    # There are three layers in PADT: ['words', 'morpho', 'syntax'];
    # We will directly access only files from the 'syntax' layer.
    # The two lower layers are referenced from syntax and will be read as well.
    # It will happen automatically via references, so we are not supposed to list those lower layers here.
    ###!!! However! I want to access meta/document of the words layer and it is not made available automatically!
    return ['syntax', 'words'];
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
    # Get document id and normalize it.
    # ummah20040407_001     (složka AEP, soubor UMH_ARB_20040407.0001) ... Ummah Press Service (AEP = Arabic English Parallel News)
    # ASB20040928.0023      (složka ASB, soubor ASB_ARB_20040928.0023) ... As Sabah News Agency
    # 20000715_AFP_ARB.0001 (složka EAT, soubor AFP_ARB_20000715.0001) ... Agence France Presse (EAT = English Arabic Treebank; part of Arabic English Parallel News)
    # HYT_ARB_20010204.0082 (složka HYT, soubor HYT_ARB_20010204.0082) ... Al Hayat News Agency
    # ALH20010204.0082 ... taky Al Hayat
    # ANN20021101.0003      (složka NHR, soubor NHR_ARB_20021101.0003) ... An Nahar News Agency
    # XIA20030501.0001      (složka XIN, soubor XIN_ARB_20030501.0001) ... Xinhua News Agency
    my $csd = $pmldoc->{words}->listMetaData()->{pml_root}{meta}{document};
    $csd =~ s/ummah(\d{8})_(\d{3})/ummah.$1.0$2/;
    $csd =~ s/ASB(\d{8}\.\d{4})/assabah.$1/;
    $csd =~ s/(\d{8})_AFP_ARB\.(\d{4})/afp.$1.$2/;
    $csd =~ s/HYT_ARB_(\d{8}\.\d{4})/alhayat.$1/;
    $csd =~ s/ALH(\d{8}\.\d{4})/alhayat.$1/;
    $csd =~ s/ANN(\d{8}\.\d{4})/annahar.$1/;
    $csd =~ s/XIA(\d{8}\.\d{4})/xinhua.$1/;
    log_warn('Unrecognized document source '.$csd) if($csd !~ m/^(afp|ummah|assabah|alhayat|annahar|xinhua)\.\d/);
    log_info('Current source document: '.$csd);
    # The trees at the 'words' level correspond to paragraphs and each paragraph
    # consists of one or more units. We really need to access the units, as these
    # correspond to trees at the level of 'syntax'.
    my @units;
    my $np = $pmldoc->{words}->trees();
    for(my $ip = 0; $ip < $np; $ip++)
    {
        my $paragraph = $pmldoc->{words}->tree($ip);
        for(my $u = $paragraph->firstson(); defined($u); $u = $u->rbrother())
        {
            push(@units, $u);
        }
    }
    my $nunits = scalar(@units);
    # Erase the _no_space_after hash before processing the new document.
    my $nsa = $self->_no_space_after();
    %{$nsa} = ();
    # For each unit (sentence), loop over tokens and check whether they are separated by whitespace.
    for(my $i = 0; $i < $nunits; $i++)
    {
        my $unit = $units[$i];
        my $sentence = $unit->attr('form');
        # Make sure that 'no_space_after' is not set for the last token of the sentence.
        $sentence .= ' ';
        if(defined($sentence))
        {
            # Children of <Unit> are <Word>. Their attributes are id and form.
            for(my $w = $unit->firstson(); defined($w); $w = $w->rbrother())
            {
                my $wid = $w->attr('id');
                my $wform = $w->attr('form');
                # There shouldn't be any whitespace in the beginning of the sentence but just in case.
                $sentence =~ s/^\s+//;
                # Eat the current token from the beginning of the sentence.
                if(!($sentence =~ s/^\Q$wform\E//))
                {
                    log_warn('Unmatched unit/form and word/forms in '.$unit->attr('id'));
                    last;
                }
                # Look for whitespace after the token.
                if($sentence =~ s/^\s+//)
                {
                    $nsa->{$wid} = 0;
                }
                else
                {
                    $nsa->{$wid} = 1;
                }
            }
        }
    }
    # Read syntactic annotation.
    my $ntrees = $pmldoc->{syntax}->trees();
    log_warn("$nunits on the words level does not correspond to $ntrees trees on the syntax level") if($ntrees!=$nunits);
    for(my $tree_number = 0; $tree_number<$ntrees; $tree_number++)
    {
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone($self->language(), $self->selector());
        my $aroot = $zone->create_atree();
        $self->_convert_atree($pmldoc->{syntax}->tree($tree_number), $aroot);
        my $unit = $units[$tree_number];
        if(defined($unit))
        {
            my $id = $unit->attr('id');
            # Every ID starts with 'w-' for the 'words' layer. We collapse layers and do not need this.
            # However, we want the unit/bundle id to contain the document name so it is unique in the entire treebank.
            $id =~ s:^w-:$csd/:;
            $aroot->set_id($id);
            my $form = $unit->attr('form');
            if(defined($form))
            {
                $zone->set_sentence($form);
            }
            else
            {
                log_warn("Undefined form of unit $id.");
                $zone->set_sentence($aroot->get_subtree_string());
            }
        }
        else
        {
            log_warn("Undefined 'words' unit number $tree_number.");
            $zone->set_sentence($aroot->get_subtree_string());
        }
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
    my $nsa = $self->_no_space_after();
    # The following attributes are present for all nodes including the root.
    foreach my $attr_name ('id', 'ord', 'afun')
    {
        $self->_copy_attr($pml_node, $treex_node, $attr_name, $attr_name);
    }
    # The following attributes are present for non-root nodes.
    if(not $treex_node->is_root())
    {
        my @features;
        # Reference to the word layer can tell what Unit (of paragraph) this word belongs to.
        # It can also show us tokens that came from the same word and it can help with detokenization.
        # $pml_node->attr('m') typically refers to a <Token>. Its parent is a <Word>.
        # The id of the Word is like this: 'm-p1w1'.
        # The Word refers to the corresponding element of the word layer.
        # The id there is like: 'w-p1u1w1'. So here it also gives the index of Unit.
        #my @available_attributes = $pml_node->attribute_paths();
        #log_fatal(join("\n", ('Available attributes:', @available_attributes)));
        my $wrf = $pml_node->attr('w/w.rf');
        if(defined($wrf))
        {
            $wrf =~ s/^w\#//;
            $treex_node->wild()->{wrf} = $wrf;
            if($nsa->{$wrf})
            {
                $treex_node->set_no_space_after(1);
            }
        }
        # Attributes from the word layer.
        # The surface word may correspond to more than one nodes (morphological analysis and second-level tokenization).
        # It is also usually not vocalized, unlike the word form on the morphological layer.
        my $aform = $pml_node->attr('w/form');
        if(defined($aform))
        {
            $treex_node->wild()->{aform} = $aform;
        }
        # Attributes from the morphological layer.
        # Note that the *.morpho.pml file may contain multiple morphological analyses per surface word.
        # The disambiguation is only visible in *.syntax.pml where a node points to one 'm' element.
        # Tokens recognized by the morphological analyzer have their form transliterated to the Latin script.
        # Out-of-vocabulary words have the original form, i.e. unvocalized Arabic script.
        # Out-of-vocabulary words do not have the 'm' section. We have to go directly to the 'w' layer.
        if(!defined($pml_node->attr('m')))
        {
            my $rform = Encode::Arabic::Buckwalter::encode('buckwalter', $aform);
            $treex_node->set_form($aform);
            $treex_node->set_attr('translit', $rform);
            $treex_node->set_lemma($aform);
            $treex_node->set_tag('U---------');
            if(defined($rform))
            {
                $rform =~ s/\s+/_/g;
                $rform =~ s/\|/:/g;
                push(@features, 'rform='.$rform);
            }
            push(@features, 'root=OOV');
        }
        else
        {
            $self->_copy_attr($pml_node, $treex_node, 'm/form',      'form');
            $self->_copy_attr($pml_node, $treex_node, 'm/cite/form', 'lemma');
            $self->_copy_attr($pml_node, $treex_node, 'm/tag',       'tag');
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
                # wild/lemma_translit, if present, is written in Write::CoNLLU as MISC LTranslit.
                $treex_node->{wild}{lemma_translit} = $rlemma;
                $treex_node->set_lemma($alemma);
            }
            # Copy English glosses from the reflex element.
            # m/cite/reflex has type Treex::PML::List=ARRAY.
            my $glosses = $pml_node->attr('m/cite/reflex');
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
            my @feanames = ('POS', 'SubPOS', 'Mood', 'Voice', 'f5', 'Person', 'Gender', 'Number', 'Case', 'Defin');
            for(my $i = 1; $i<=9; $i++)
            {
                push(@features, "$feanames[$i]=$tagchars[$i]") unless(!defined($tagchars[$i]) || $tagchars[$i] eq '-');
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
            my $deprel;
            # Convert the old way of marking unknown afun to the ways used in Treex and in CoNLL.
            if($treex_node->afun() eq '???')
            {
                $treex_node->set_afun('NR');
                $treex_node->set_deprel('NR');
                $deprel = '_';
            }
            # The AuxS afun is reserved for tree roots and should never occur in a non-root node.
            # Nevertheless, it is listed in the PADT XML schema and it has occurred in the data.
            # We must not leave it in Treex because it is not allowed there and reading such a Treex document will fail mysteriously
            # (there will be no bundles in the document; this could be considered a bug in the PML reader, as of 10.5.2014).
            elsif($treex_node->afun() eq 'AuxS')
            {
                $treex_node->set_afun('NR');
                $treex_node->set_deprel('NR');
                $deprel = '_';
            }
            else
            {
                $deprel = $treex_node->afun();
                $treex_node->set_deprel($deprel);
            }
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
        # The PADT attribute coref is not compatible with the Treex attribute coref.
        if($pml_node->attr('coref'))
        {
            $treex_node->{wild}{coref} = $pml_node->attr('coref');
        }
        # Clause is the predicative function of the clausal predicate: Pred, Pnom, PredE, PredP...
        # The afun of subordinated clauses reflects their relation to the parent (Adv, Obj...) so the predicate must be labeled elsewhere.
        ###!!! Should we also set the Treex attributes is_clause_head and clause_number?
        if($pml_node->attr('clause'))
        {
            $treex_node->{wild}{clause} = $pml_node->attr('clause');
        }
        # If token = word, score seems to contain both the vocalized and unvocalized version of the word.
        # First token of a word: vocalized token and unvocalized word.
        # Non-first token of a word: vocalized token and nothing more.
        # 29.5.2013: Ota confirmed that <score> was a temporary auxiliary storage. We should not need it and it should probably be removed before releasing the data.
        #if($pml_node->attr('score'))
        #{
        #    $treex_node->{wild}{score} = $pml_node->attr('score');
        #}
        if($pml_node->attr('note'))
        {
            $treex_node->{wild}{note} = $pml_node->attr('note');
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



###!!! Debugging Treex::PML and the PADT PML format.
use Scalar::Util qw(reftype);
sub dbgstr
{
    my $x = shift;
    my $d = shift;
    $d = {} if(!defined($d));
    return '' if(!defined($x));
    my $r = reftype($x);
    my $s;
    # Undefined reftype means this is not a reference but a plain scalar.
    if(!defined($r))
    {
        $s = "'$x'";
    }
    elsif($r eq 'HASH')
    {
        my $xscalar = scalar($x);
        return '!' if(exists($d->{$xscalar}));
        $d->{$xscalar}++;
        $s = "$x ".dbgstrhash($x, $d);
    }
    elsif($r eq 'ARRAY')
    {
        my $xscalar = scalar($x);
        return '!' if(exists($d->{$xscalar}));
        $d->{$xscalar}++;
        $s = "$x ".dbgstrarray($x, $d);
    }
    elsif($r eq '')
    {
        $s = $x;
    }
    else
    {
        $s = "unknown reference type $r";
    }
    return $s;
}
sub dbgstrhash
{
    my $x = shift;
    my $d = shift;
    my @s;
    foreach my $k (sort(keys(%{$x})))
    {
        push(@s, "$k => ".dbgstr($x->{$k}, $d));
    }
    return '{ '.join(', ', @s).' }';
}
sub dbgstrarray
{
    my $x = shift;
    my $d = shift;
    my @s;
    foreach my $e (@{$x})
    {
        push(@s, dbgstr($e, $d));
    }
    return '[ '.join(', ', @s).' ]';
}

1;

__END__

=head1 Treex::Block::Read::PADT

Import trees from the Prague Arabic Dependency Treebank 2.0 (not released, converted to PML by Otakar Smrž and stored in an svn repository at ÚFAL;
a working copy might be in C</net/projects/padt>).

Example:

PADT=/net/projects/padt/data/Prague
treex Read::PADT 'from=$PADT/AEP/UMH_ARB_20040407.0001.syntax.pml' Write::CoNLLX deprel_attribute=conll/deprel > pokus.ar.conll

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.
By default, the directory is expected in a path relative to the location of this block.

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
