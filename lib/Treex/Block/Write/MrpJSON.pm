package Treex::Block::Write::MrpJSON;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+extension' => ( default => '.sdp' );
has 'valency_dict_name' => ( is => 'ro', isa => 'Str', default => 'engvallex.xml',
    documentation => 'Name of the file with the valency dictionary to which the val_frame.rf attributes point. '.
    'Full path is not needed. The XML logic will somehow magically find the file.');



#------------------------------------------------------------------------------
# Processes the current language zone. Although the tectogrammatical tree is
# our primary source of information, we may have to reach to the analytical and
# morphological annotation, too.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    # Compute the text anchors for each a-node. We cannot do it directly for
    # t-nodes, but each t-node may be linked to zero, one or more a-nodes.
    # First character of the sentence has position 0. Node anchor is given as
    # a closed-open interval, i.e., the right margin is the position of the first
    # character outside the node.
    my $sentence_rest = $zone->sentence();
    my @anodes = $aroot->get_descendants({'ordered' => 1});
    my $from = 0;
    foreach my $anode (@anodes)
    {
        my $form = $anode->form();
        my $l = length($form);
        if(substr($sentence_rest, 0, $l) eq $form)
        {
            my $to = $from + $l;
            $anode->wild()->{anchor} = {'from' => $from, 'to' => $to};
            $sentence_rest = substr($sentence_rest, $to);
            $from = $to;
            my $nspaces = $sentence_rest =~ s/^\s+//;
            $from += $nspaces;
        }
        else
        {
            # For debugging purposes, show the anchoring of the previous tokens.
            log_warn($zone->sentence());
            foreach my $a (@anodes)
            {
                if($a == $anode)
                {
                    last;
                }
                my $f = $a->form();
                my $af = $a->wild()->{anchor}->{from};
                my $at = $a->wild()->{anchor}->{to};
                log_warn("'$f' from $af to $at");
            }
            log_warn("Current position = $from");
            log_fatal("Word form '$form' does not match the rest of sentence '$sentence_rest'.");
        }
    }
    my @json = ();
    # Sentence (graph) identifier.
    push(@json, ['id', $self->get_sentence_id($zone)]);
    # MFP flavors (http://mrp.nlpl.eu/2020/index.php?page=11#terminology):
    # 0 ... bi-lexical dependency graphs; nodes injectively correspond to surface
    #       lexical units (tokens). Each node is directly linked to one specific
    #       token (conversely, there may be semantically empty tokens), and the
    #       nodes inherit the linear order of their corresponding tokens.
    # 1 ... anchored semantic graphs; arbitrary parts of the sentence (e.g.,
    #       subtoken or multitoken) can be node anchors; multiple nodes can be
    #       anchored to overlapping substrings.
    # 2 ... unanchored semantic graphs; correspondence between nodes and the
    #       surface string is not an inherent part of the representation of
    #       meaning.
    push(@json, ['flavor', 0, 'numeric']);
    # Framework 'ptt' = Prague Tectogrammatical Trees (an established name,
    # although the coreference edges break treeness).
    push(@json, ['framework', 'ptt']);
    # Version: I am not sure what is the thing whose versions we number here.
    # I think that the Prague tectogrammatical trees changed for the last time
    # when version 2.0 of PDT and PCEDT was released, so we will put 2.0 here.
    # But maybe it is the version of the particular dataset that we are
    # generating now?
    push(@json, ['version', 2.0, 'numeric']);
    # Time: Should this be the time when the file was generated? Then we should
    # probably make sure that all sentences in the file will get the same time
    # stamp, no?
    push(@json, ['time', '2020-04-04 (10:00)']);
    # Full sentence text.
    push(@json, ['input', $zone->sentence()]);
    # Encode JSON.
    my @json1 = ();
    foreach my $pair (@json)
    {
        my $name = '"'.$pair->[0].'"';
        my $value;
        if(defined($pair->[2]) && $pair->[2] eq 'numeric')
        {
            $value = $pair->[1];
        }
        else
        {
            $value = $pair->[1];
            $value =~ s/"/\\"/g;
            $value = '"'.$value.'"';
        }
        push(@json1, "$name: $value");
    }
    my $json = '{'.join(', ', @json1).'}';
    print {$self->_file_handle()} ("$json\n");
    ###!!! FIX THE REST!
    # Compute correspondences between t-nodes and a-nodes. We will need them to
    # provide the anchoring of the nodes in the input text.
    my @tnodes = $troot->get_descendants({ordered => 1});
    foreach my $tnode (@tnodes)
    {
        my $anode = $tnode->get_lex_anode();
        if(!defined($anode))
        {
            # Sometimes there is no direct link from a generated t-node to an a-node,
            # but there is a coreference link to another t-node, which is realized on surface.
            # Then we want to use the coreferenced a-node for both the t-nodes.
            # Example (wsj_0062.treex.gz#4): "Garbage made its debut with the promise to give consumers..."
            # T-tree (partial): ACT(made, Garbage); PAT(promise, give); ACT(give, #PersPron)-coref->(Garbage)
            # We want to deduce: ACT(give, Garbage)
            my @coref_tnodes = $tnode->get_coref_nodes();
            # We are only interested in nodes that are in the same sentence.
            @coref_tnodes = grep {$_->get_root() == $troot} @coref_tnodes;
            # We are only interested in nodes that are realized on surface.
            my @coref_anodes = grep {defined($_)} map {$_->get_lex_anode()} @coref_tnodes;
            ###!!! We do not know how to choose one of several coreference targets. We will pick the first one.
            if(@coref_anodes)
            {
                $anode = $coref_anodes[0];
            }
        }
        if(defined($anode))
        {
            # Occasionally a token is re-tokenized on the t-layer and there are several t-nodes corresponding to one a-node.
            # Example: "1/2" -> "1", "#Slash", "2" (annotated as coordination headed by #Slash).
            # We store the link to the first t-node found for subsequent functions that can deal with at most one t-node.
            # We store separately links to all t-nodes found for functions that can use them all.
            $anode->wild()->{tnode} = $tnode unless(defined($anode->wild()->{tnode}));
            push(@{$anode->wild()->{tnodes}}, $tnode);
        }
        $tnode->wild()->{valency_frame} = $self->get_valency_frame($tnode);
    }
    # We require that the token ids make an unbroken sequence, starting at 1.
    # Unfortunately, this is not guaranteed in all a-trees. For example, in PCEDT 2.0 file wsj_0006.treex.gz, sentence 1, several numbers are skipped.
    # So we have to re-index the nodes ourselves.
    $aroot->_normalize_node_ordering();
    @anodes = $aroot->get_descendants({ordered => 1});
    my @frames = ([]); # identifiers of valency frames for nodes that have them; dummy first element for the root node [0]
    foreach my $anode (@anodes)
    {
        my $ord = $anode->ord();
        my $tag = $anode->tag();
        my $form = $self->decode_characters($anode->form(), $tag);
        my $lemma = $self->get_lemma($anode);
        push(@frames, $self->get_valency_frame_for_a_node($anode));
    }
}



#------------------------------------------------------------------------------
# Construct sentence number according to Stephan's convention. The result
# should be a numeric string.
#------------------------------------------------------------------------------
sub get_sentence_id
{
    my $self = shift;
    my $zone = shift;
    my $sid = 0;
    # Option 1: The input file comes from the Penn Treebank / Wall Street Journal
    # and is named according to the PTB naming conventions.
    # Bundle->get_position() is not efficient (see comment there) so we may consider simply counting the sentences using an attribute of this block.
    my $isentence = $zone->get_bundle()->get_position()+1;
    my $ptb_section_file = $zone->get_document()->file_stem();
    if($ptb_section_file =~ s/^wsj_//i)
    {
        $sid = sprintf("2%s%03d", $ptb_section_file, $isentence);
    }
    # Option 2: The input file comes from the Brown Corpus.
    elsif($ptb_section_file =~ s/^c([a-r])(\d\d)//)
    {
        my $genre = $1;
        my $ifile = $2;
        my $igenre = ord($genre)-ord('a');
        $sid = sprintf("4%02d%02d%03d", $igenre, $ifile, $isentence);
    }
    # Option 3: The input file comes from the Prague Dependency Treebank.
    elsif($ptb_section_file =~ m/^(cmpr|lnd?|mf)(9\d)(\d+)_(\d+)$/)
    {
        my $source = $1;
        my $year = $2;
        my $issue = $3;
        my $ifile = $4;
        my $isource = $source eq 'cmpr' ? 0 : $source =~ m/^ln/ ? 1 : 2;
        $sid = sprintf("1%d%d%04d%03d", $isource, $year, $issue, $ifile);
    }
    else
    {
        log_warn("File name '$ptb_section_file' does not follow expected patterns, cannot construct sentence identifier");
    }
    return $sid;
}



#------------------------------------------------------------------------------
# Returns lemma for output. If there is no t-node, returns a-node's lemma.
# If there is one t-node, returns its t-lemma. If there are more than one
# t-node, concatenates their t-lemmas.
#------------------------------------------------------------------------------
sub get_lemma
{
    my $self = shift;
    my $anode = shift;
    my $lemma;
    # Is there a lexically corresponding tnode?
    my $tnode = $anode->wild()->{tnode};
    my @tnodes;
    # Unfortunately the sort() does not help always. It is not rare that the annotation of PCEDT is wrong.
    # For instance, in sentence 32 of wsj_2300, the token "7/8" yields three t-nodes but their ord values order them as "#Slash 8 7".
    @tnodes = sort {$a->ord() <=> $b->ord()} (@{$anode->wild()->{tnodes}}) if(defined($anode->wild()->{tnodes}));
    if(scalar(@tnodes)>1)
    {
        # There are two or more t-nodes linked to one a-node. Two model cases:
        # 1. Retokenized a-nodes such as "1/2" --> "1", "#Slash", "2".
        # 2. Doubled or multiplied nodes to cover ellipsis, e.g. "yield" --> "yield", "yield".
        # 3. Generated nodes "#Cor" that are the source point of coreference leading to the lexical node.
        # In case 1, we want to see the lemmas of all t-nodes involved.
        # In case 2, we want just one copy of the lemma.
        # In case 3, we do not want to see "#Cor" in the lemma.
        my @lemmas = map {$self->decode_characters($_->t_lemma())} (@tnodes);
        my @coreflemmas = grep {$_ =~ m/^\#/} (@lemmas);
        my @noncoreflemmas = grep {$_ !~ m/^\#/} (@lemmas);
        if(scalar(@coreflemmas) && scalar(@noncoreflemmas)) # case 3
        {
            $lemma = join('_', @noncoreflemmas);
        }
        elsif(grep {$_ ne $lemmas[0]} (@lemmas)) # case 1
        {
            $lemma = join('_', @lemmas);
        }
        else # case 2
        {
            $lemma = $lemmas[0];
        }
    }
    elsif(defined($tnode))
    {
        # This is a content word and there is a lexically corresponding t-node.
        $lemma = $self->decode_characters($tnode->t_lemma());
    }
    else
    {
        # This is a function word or punctuation and it does not have its own t-node.
        $lemma = $self->decode_characters($anode->lemma());
    }
    return $lemma;
}



#------------------------------------------------------------------------------
# Returns reference to valency frame. For a-nodes with one t-node this is the
# valency frame of the t-node. If there is no t-node or if the t-node does not
# point to a valency frame, the result is undefined. If there are more than one
# t-node, all are searched for valency frames and the first frame found is
# returned (if any).
#------------------------------------------------------------------------------
sub get_valency_frame_for_a_node
{
    my $self = shift;
    my $anode = shift;
    my $frame;
    # Is there a lexically corresponding tnode?
    my $tnode = $anode->wild()->{tnode};
    my @tnodes;
    @tnodes = sort {$a->ord() <=> $b->ord()} (@{$anode->wild()->{tnodes}}) if(defined($anode->wild()->{tnodes}));
    if(scalar(@tnodes)>1)
    {
        # There are two or more t-nodes linked to one a-node. Two model cases:
        # 1. Retokenized a-nodes such as "1/2" --> "1", "#Slash", "2".
        # 2. Doubled or multiplied nodes to cover ellipsis, e.g. "yield" --> "yield", "yield".
        foreach my $tnode (@tnodes)
        {
            if(defined($tnode->wild()->{valency_frame}))
            {
                $frame = $tnode->wild()->{valency_frame};
                last;
            }
        }
    }
    elsif(defined($tnode))
    {
        # This is a content word and there is a lexically corresponding t-node.
        if(defined($tnode->wild()->{valency_frame}))
        {
            $frame = $tnode->wild()->{valency_frame};
        }
    }
    return $frame;
}



#------------------------------------------------------------------------------
# Finds a-node that lexically corresponds to the t-node and returns its ord.
#------------------------------------------------------------------------------
sub get_a_ord_for_t_node
{
    my $self = shift;
    my $tnode = shift;
    my $aroot = shift; # We need this in order to check that the result is in the same sentence, see below.
    # If t-node is root, we will not find its lexically corresponding a-node.
    # We want the a-root even though the correspondence is no longer lexical.
    if($tnode->is_root())
    {
        return 0;
    }
    else
    {
        my $anode = $tnode->get_lex_anode();
        # Ellipsis may cause that the anode is in previous sentence.
        # We are only interested in anodes that are in the same sentence!
        if(defined($anode) && $anode->get_root()==$aroot)
        {
            return $anode->ord();
        }
        else
        {
            # This could happen if we called the function on a generated t-node.
            # All other t-nodes must have one lexical a-node and may have any number of auxiliary a-nodes.
            return undef;
        }
    }
}



#------------------------------------------------------------------------------
# Recursively looks for ancestors of t-nodes that can be projected on a-nodes.
# Paratactic structures may cause a fork, i.e. more than one ancestor.
# Generated ancestors (without corresponding a-nodes in the same sentence) will
# create chains of functors.
# If a normal ancestor (effective parent) cannot be projected, we will
# recursively look for both types of its ancestors: effective parents and
# coap heads.
# If a coap head cannot be projected, we will recursively search only for
# superordinated coap heads in nested paratactic structures. If there are none,
# the coap links will be lost without trace. (We could interlink the conjuncts
# directly but such solution would not be consistent with the rest of the
# data.)

# The data structure:
# array of references to hashes with the following keys:
#   tnode ........ either the original tnode or one of its ancestors
#   outfunctor ... either the original functor or chain of functors on the path
#                  from the original tnode to the ancestor
#   anode ........ index of the anode corresponding to the current tnode

# The algorithm:
# 1. At the beginning there is just one node and we look for its parents.
#    We make it the current node. It's not marked OK (we want its parents, not
#    itself).
# 2. If the node is root, the sought for parent does not exist. Return undef
#    and terminate.
# 3. Current node is not OK and we are looking for its closest ancestors.
# 3a We always look for is_member relations (for normal nodes and coaproots).
#    If we find a superordinated coaproot, it is one of the ancestors.
#    The coaproot's functor plus ".member" is the outfunctor of the relation.
#    If the current node already had an outfunctor, attach it after the new
#    outfunctor so we get e.g. "DISJ.member.CONJ.member" or "DISJ.member.RSTR".
# 3b In addition, for non-coaproot nodes we look for effective parents. There
#    may be more than one effective parent if they are coordinated. The current
#    node is not root so we should find at least one effective parent and add
#    it to ancestors.
#    The functor of the current node becomes outfunctor of these relations.
#    If the current node already had an outfunctor, attach it after the new
#    outfunctor so we get e.g. "PAT.RSTR".
# 3c We have got an array of ancestors. If the current node is coaproot and if
#    we have not found a superordinated coaproot, the array will be empty!
# 3d Remove the current node from the array and replace it with the array of
#    newly found ancestors. If we found at least one ancestor, the first
#    ancestor will become the new current node. Otherwise the new current node
#    will be the next node in the array, if any.
# 4. If there is no current node, we have reached the end of the array and we
#    have got the complete answer. The array may also be empty. If it is not,
#    then all nodes in the array are OK. Terminate.
#    If there is a current node, go to step 5.
# 5. Figure out whether the current node can be projected on an a-node from the
#    same sentence. If so, then the node is OK, we remember the corresponding
#    a-node and go to step 6.
#    If not, then we return to step 3.
# 6. Unless we are at the end of the array, we move to the next node to the
#    right and make it the new current node. If we are at the end, no node will
#    be current. Return to step 4.

#------------------------------------------------------------------------------
sub find_a_parent
{
    my $self = shift;
    my $tnode = shift;
    my $aroot = shift; # We need this in order to check that the result is in the same sentence, see below.
    return undef if($tnode->is_root());
    my %record = ('tnode' => $tnode, 'outfunctor' => undef, 'anode' => undef);
    my @nodes = (\%record);
    my $current = 0;
    while(1)
    {
        # Effective parents are important around coordination or apposition:
        # - CoAp root (conjunction) has no effective parent.
        # - Effective parent of conjuncts is somewhere above the conjunction (its direct parent, unless there is another coordination involved).
        # - Effective parents of shared modifier are the conjuncts.
        my @eparents;
        unless($nodes[$current]{tnode}->is_coap_root())
        {
            @eparents = $nodes[$current]{tnode}->get_eparents();
        }
        my @ancestors;
        foreach my $ep (@eparents)
        {
            my $outfunctor = $nodes[$current]{tnode}->functor();
            $outfunctor .= '.'.$nodes[$current]{outfunctor} if(defined($nodes[$current]{outfunctor}));
            push(@ancestors, {'tnode' => $ep, 'outfunctor' => $outfunctor, 'anode' => undef});
        }
        if($nodes[$current]{tnode}->is_member())
        {
            my $coaproot = $nodes[$current]{tnode}->parent();
            my $outfunctor = $coaproot->functor().'.member';
            $outfunctor .= '.'.$nodes[$current]{outfunctor} if(defined($nodes[$current]{outfunctor}));
            push(@ancestors, {'tnode' => $coaproot, 'outfunctor' => $outfunctor, 'anode' => undef});
        }
        # Replace the current node with its ancestors.
        # $current will now point to the first ancestor.
        # If the list of ancestors is empty, $current will point to the next queued node, if any.
        splice(@nodes, $current, 1, @ancestors);
    project_current:
        # Return from the loop and from the function is granted.
        # If no ancestor is found, @nodes will shrink and $current eventually will exceed $#nodes.
        # If ancestors are found, the root at the latest will have $aord defined and $current will grow (several paths to the root can be returned).
        if($current>$#nodes)
        {
            return @nodes;
        }
        my $aord = $self->get_a_ord_for_t_node($nodes[$current]{tnode}, $aroot);
        if(defined($aord))
        {
            $nodes[$current]{anode} = $aord;
            $current++;
            goto project_current;
        }
    }
}



#------------------------------------------------------------------------------
# Finds all relations of an a-node to its parents. The relations are
# projections of dependencies in the t-tree. An a-node may have zero, one or
# more parents. The relations are added to the matrix and the array of root
# flags is updated. We expect to get the references to matrix and roots from
# the caller.
#------------------------------------------------------------------------------
sub get_parents
{
    my $self = shift;
    my $anode = shift;
    my $matrix = shift;
    my $roots = shift;
    my $aroot = shift; # We need this in order to check that the result is in the same sentence, see below.
    my $ord = $anode->ord();
    # Is there a lexically corresponding tnode?
    my $tn = $anode->wild()->{tnode};
    my @tnodes;
    @tnodes = sort {$a->ord() <=> $b->ord()} (@{$anode->wild()->{tnodes}}) if(defined($anode->wild()->{tnodes}));
    $roots->[$ord] = '-';
    if(defined($tn))
    {
        # This is a content word and there is at least one lexically corresponding t-node.
        # Add parent relations for all corresponding t-nodes. (Some of them may collapse in the a-tree to a reflexive link.)
        foreach my $tnode (@tnodes)
        {
            my @parents = $self->find_a_parent($tnode, $aroot);
            foreach my $parent (@parents)
            {
                if($parent->{tnode}->is_root())
                {
                    $roots->[$ord] = '+';
                }
                my $functor = $parent->{outfunctor};
                # Mark dependencies projected from generated t-nodes. They are often responsible for problems, e.g. cycles in graphs.
                if($tnode->is_generated())
                {
                    $functor .= '*';
                }
                ###!!! If there are two or more paths to the same a-parent, only the last functor will survive.
                $matrix->[$ord][$parent->{anode}] = $functor;
            }
        }
    }
    return $matrix;
}



#------------------------------------------------------------------------------
# Takes a matrix of graph relations: $matrix[$i][$j] = 'ACT' means that node $i
# depends on node $j and the label of the relation is 'ACT'. Returns array of
# binary values that tell for each node whether it is a predicate (has
# children) or not.
#------------------------------------------------------------------------------
sub get_is_pred
{
    my $self = shift;
    my $matrix = shift;
    # How many predicates are there and what is their mapping to the all-node indices?
    # The artificial root node does not count as predicate because it does not have a corresponding token!
    my @ispred;
    for(my $i = 1; $i<=$#{$matrix}; $i++)
    {
        for(my $j = 1; $j<=$#{$matrix->[$i]}; $j++)
        {
            if(defined($matrix->[$i][$j]))
            {
                $ispred[$j]++;
            }
        }
    }
    return @ispred;
}



#------------------------------------------------------------------------------
# Translates selected characters that in Penn Treebank and PCEDT were encoded
# in an old-fashioned pre-Unicode way. Takes a string and returns the adjusted
# version of the string. Should be called for every word form and lemma.
#------------------------------------------------------------------------------
sub decode_characters
{
    my $self = shift;
    my $x = shift;
    my $tag = shift; # Could be used to distinguish between possessive apostrophe and right single quotation mark. Currently not used.
    # Cancel escaping of brackets. The codes are uppercased in forms (and POS tags) and lowercased in lemmas.
    $x =~ s/-LRB-/(/ig;
    $x =~ s/-RRB-/)/ig;
    $x =~ s/-LCB-/{/ig;
    $x =~ s/-RCB-/}/ig;
    # Cancel escaping of slashes and asterisks.
    $x =~ s-\\/-/-g;
    $x =~ s/\\\*/*/g;
    # English opening double quotation mark.
    $x =~ s/``/\x{201C}/g;
    # English closing double quotation mark.
    $x =~ s/''/\x{201D}/g;
    # English opening single quotation mark.
    $x =~ s/^`$/\x{2018}/g;
    # English closing single quotation mark.
    # Includes cases where the character is used as apostrophe: 's s' 're 've n't etc.
    # According to the Unicode standard, U+2019 is the preferred character for both the single quote and the apostrophe,
    # despite their different semantics. See also
    # http://www.cl.cam.ac.uk/~mgk25/ucs/quotes.html and
    # http://www.unicode.org/versions/Unicode6.2.0/ch06.pdf (page 200)
    $x =~ s/'/\x{2019}/g;
    # N-dash.
    $x =~ s/--/\x{2013}/g;
    # Ellipsis.
    $x =~ s/\.\.\./\x{2026}/g;
    return $x;
}



#------------------------------------------------------------------------------
# For a t-node, gets the reference to its corresponding valency frame, if it
# exists.
#------------------------------------------------------------------------------
sub get_valency_frame
{
    my $self = shift;
    my $tnode = shift;
    my $frame_id = $tnode->val_frame_rf();
    return if(!defined($frame_id));
    $frame_id =~ s/^.*#//;
    return Treex::Tool::Vallex::ValencyFrame::get_frame_by_id($self->valency_dict_name(), $self->language(), $frame_id);
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::MrpJSON

=head1 DESCRIPTION

Prints out all t-trees (including coreference, so the result is no longer a tree)
in the JSON line-based format of the CoNLL Meaning Representation Parsing tasks
(MRP 2019 and 2020).

The format is described here:
L<http://mrp.nlpl.eu/2020/index.php?page=14#format>

Sample usage:

C<treex -Len Read::Treex from='!/net/data/pcedt2.0/data/00/wsj_00[012]*.treex.gz' Write::MrpJSON path=./trial-pcedt extension=.mrp>

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=item C<valency_dict_name>

File name of the valency lexicon to which the valency frame references point. This is a required parameter.
For the English part of PCEDT 2.0, its value should probably be "engvallex.xml".
(DZ: But I do not know how Treex is supposed to actually find the file. In PCEDT, the file is not in the same folder as the tree files.
It is in ../../valency_lexicons, from the point of view of a tree file. The headers of the tree files contain a reference but it also
lacks the full path.)

    <references>
      <reffile id="cs-v" name="vallex" href="vallex3.xml" />
      <reffile id="en-v" name="vallex" href="engvallex.xml" />
    </references>

=back

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
