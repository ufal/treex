package Treex::Block::Write::MrpJSON;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+extension' => ( default => '.mrp' );
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
    my $sentence = $self->decode_sentence_and_anchor_anodes($zone);
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
    push(@json, ['flavor', 1, 'numeric']);
    # Framework 'ptg' = Prague Tectogrammatical Graphs (since we treat
    # coreference links as edges, the structure is no longer a tree).
    push(@json, ['framework', 'ptg']);
    # The version should be '1.0' (as of April 2020), a decimal number,
    # indicating the MRP format revision.
    push(@json, ['version', '1.0', 'numeric']);
    # Time: Should this be the time when the file was generated? Then we should
    # probably make sure that all sentences in the file will get the same time
    # stamp, no?
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    # Stephan says they dropped hour-minute part between data releases in 2019, so now it's only the date.
    my $timestamp = sprintf("%4d-%02d-%02d", $year+1900, $mon+1, $mday);
    push(@json, ['time', $timestamp]);
    # Full sentence text.
    push(@json, ['input', $sentence]);
    # There is always one top node and it is always the artificial root (id 0).
    push(@json, ['tops', [0], 'list of numeric']);
    # Assign integer numbers to nodes for the purpose of the JSON references.
    # Users are used to integer node identifiers, so we will not use $tnode->id(),
    # which is a string like 'EnglishT-wsj_0001-s2-t3'.
    my @tnodes = $troot->get_descendants({ordered => 1});
    my %id;
    my $i = 0;
    $id{$troot->id()} = $i;
    $i = 1;
    foreach my $tnode (@tnodes)
    {
        $id{$tnode->id()} = $i;
        $i++;
    }
    # Compute correspondences between t-nodes and a-nodes. We will need them to
    # provide the anchoring of the nodes in the input text.
    my @nodes_json = ();
    my @edges_json = ();
    # We could label the root #Root, which does not occur in PML files.
    # But per Stephan Oepen's request, we leave the root unlabeled.
    push(@nodes_json, [['id', $id{$troot->id()}, 'numeric']]); # , ['label', '#Root']
    foreach my $tnode (@tnodes)
    {
        my @node_json = ();
        push(@node_json, ['id', $id{$tnode->id()}, 'numeric']);
        push(@node_json, ['label', $tnode->t_lemma()]);
        # A t-node refers to zero or one lexical a-node, and to any number of auxiliary a-nodes.
        my $anode = $tnode->get_lex_anode();
        my @auxiliaries = $tnode->get_aux_anodes();
        my @anchors = ();
        # Sometimes a t-node refers to an a-node in a previous sentence.
        # Example: gapping across sentence boundary, as in wsj_0430, sentence 2 refers to "hold up" in sentence 1:
        # 1. Nothing was going to hold up the long-delayed settlement of Britton vs. Thomasini.
        # 2. Not even an earthquake.
        # In such cases, we must not take the anchors because they do not refer to the current sentence text!
        # Hence we must test that the a-roots match.
        if(defined($anode) && $anode->get_root() == $aroot)
        {
            if(exists($anode->wild()->{anchor}))
            {
                push(@anchors, [['from', $anode->wild()->{anchor}->{from}, 'numeric'], ['to', $anode->wild()->{anchor}->{to}, 'numeric']]);
            }
        }
        foreach my $aux (@auxiliaries)
        {
            if($aux->get_root() == $aroot && exists($aux->wild()->{anchor}))
            {
                push(@anchors, [['from', $aux->wild()->{anchor}->{from}, 'numeric'], ['to', $aux->wild()->{anchor}->{to}, 'numeric']]);
            }
        }
        if(scalar(@anchors) > 0)
        {
            # Order the anchors left-to-right by their occurrence in the text.
            @anchors = sort {my $r = $a->[0][1] <=> $b->[0][1]; unless($r) {$r = $a->[1][1] <=> $b->[1][1]} $r} (@anchors);
            push(@node_json, ['anchors', \@anchors, 'list of structures']);
        }
        # Export selected attributes and grammatemes of the node (especially the ones that are annotated manually in PDT 3.5).
        my @properties = ();
        my @values = ();
        # Sentence modality.
        if(defined($tnode->sentmod()) && $tnode->sentmod() ne '')
        {
            push(@properties, 'sentmod');
            push(@values, $tnode->sentmod());
        }
        # Semantic part-of-speech category.
        if(defined($tnode->gram_sempos()) && $tnode->gram_sempos() ne '')
        {
            push(@properties, 'sempos');
            push(@values, $tnode->gram_sempos());
        }
        # Older data (English in PCEDT) do not have sempos but they have formeme,
        # first part of which is like sempos (and second part corresponds to
        # information that in PDT is covered by subfunctors).
        elsif(defined($tnode->formeme()) && $tnode->formeme() ne '')
        {
            my $sempos = $tnode->formeme();
            $sempos =~ s/:.*$//;
            push(@properties, 'sempos');
            push(@values, $sempos);
        }
        # Factual modality.
        if(defined($tnode->gram_factmod()) && $tnode->gram_factmod() ne '')
        {
            push(@properties, 'factmod');
            push(@values, $tnode->gram_factmod());
        }
        # Diatgram grammateme (diathesis).
        if(defined($tnode->gram_diatgram()) && $tnode->gram_diatgram() ne '')
        {
            push(@properties, 'diatgram');
            push(@values, $tnode->gram_diatgram());
        }
        # Typgroup: does the noun in plural signify a pair or a tuple?
        if(defined($tnode->gram_typgroup()) && $tnode->gram_typgroup() ne '')
        {
            push(@properties, 'typgroup');
            push(@values, $tnode->gram_typgroup());
        }
        # The block Write::SDP2015 reads engvallex.xml because it asks whether a frame role is obligatory.
        # We currently do not do that, so we can output the frame reference ($tnode->val_frame_rf())
        # without reading the frame from engvallex.xml to $tnode->wild()->{valency_frame}.
        #$tnode->wild()->{valency_frame} = $self->get_valency_frame($tnode);
        if(defined($tnode->val_frame_rf()) && $tnode->val_frame_rf() !~ m/^_?$/)
        {
            push(@properties, 'frame');
            push(@values, $tnode->val_frame_rf());
        }
        # Topic-focus articulation.
        if(defined($tnode->tfa()))
        {
            push(@properties, 'tfa');
            push(@values, $tnode->tfa());
        }
        push(@node_json, ['properties', \@properties, 'list']);
        push(@node_json, ['values', \@values, 'list']);
        push(@nodes_json, \@node_json);
        # Being a member of a paratactic structure (coordination or apposition)
        # is an independent attribute of a node in Treex but in MRP, we have to
        # encode it as a part of the relation label.
        my $label = $tnode->functor();
        if($tnode->subfunctor())
        {
            $label .= '.'.$tnode->subfunctor();
        }
        if($tnode->is_member())
        {
            push(@edges_json, [['source', $id{$tnode->parent()->id()}, 'numeric'], ['target', $id{$tnode->id()}, 'numeric'], ['label', $label], ['attributes', ['member'], 'list'], ['values', ['true'], 'list of numeric']]);
        }
        else
        {
            push(@edges_json, [['source', $id{$tnode->parent()->id()}, 'numeric'], ['target', $id{$tnode->id()}, 'numeric'], ['label', $label]]);
        }
        # Get effective parents.
        unless($tnode->is_coap_root())
        {
            my @eparents = $tnode->get_eparents();
            @eparents = grep {$_ != $tnode->parent()} (@eparents);
            foreach my $eparent (@eparents)
            {
                push(@edges_json, [['source', $id{$eparent->id()}, 'numeric'], ['target', $id{$tnode->id()}, 'numeric'], ['label', $label], ['attributes', ['effective'], 'list'], ['values', ['true'], 'list of numeric']]);
            }
        }
        # Get coreference edges.
        my @gcoref = $tnode->get_coref_gram_nodes();
        my @tcoref = $tnode->get_coref_text_nodes();
        my ($bridgenodes, $bridgetypes) = $tnode->get_bridging_nodes();
        # We are only interested in nodes that are in the same sentence.
        @gcoref = grep {$_->get_root() == $troot} (@gcoref);
        foreach my $cnode (@gcoref)
        {
            push(@edges_json, [['source', $id{$tnode->id()}, 'numeric'], ['target', $id{$cnode->id()}, 'numeric'], ['label', 'coref.gram']]);
        }
        # We are only interested in nodes that are in the same sentence.
        @tcoref = grep {$_->get_root() == $troot} (@tcoref);
        foreach my $cnode (@tcoref)
        {
            push(@edges_json, [['source', $id{$tnode->id()}, 'numeric'], ['target', $id{$cnode->id()}, 'numeric'], ['label', 'coref.text']]);
        }
        for(my $i = 0; $i <= $#{$bridgenodes}; $i++)
        {
            # We are only interested in nodes that are in the same sentence.
            if($bridgenodes->[$i]->get_root() == $troot)
            {
                push(@edges_json, [['source', $id{$tnode->id()}, 'numeric'], ['target', $id{$bridgenodes->[$i]->id()}, 'numeric'], ['label', 'bridging.'.$bridgetypes->[$i]]]);
            }
        }
    }
    push(@json, ['nodes', \@nodes_json, 'list of structures']);
    push(@json, ['edges', \@edges_json, 'list of structures']);
    # Encode JSON.
    my $json = $self->encode_json(@json);
    print {$self->_file_handle()} ("$json\n");
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
        $sid = sprintf("1%d%d%04d%03d%03d", $isource, $year, $issue, $ifile, $isentence);
    }
    else
    {
        log_warn("File name '$ptb_section_file' does not follow expected patterns, cannot construct sentence identifier");
    }
    return $sid;
}



#------------------------------------------------------------------------------
# Computes text anchors for each a-node. The task is tricky because we also
# want to translate some characters to Unicode, which may change the total
# number of characters, as well as their offsets. The method returns the
# sentence with translated characters, while the anchors are stored directly
# as wild attributes of the a-nodes.
#------------------------------------------------------------------------------
sub decode_sentence_and_anchor_anodes
{
    my $self = shift;
    my $zone = shift;
    my $aroot = $zone->get_tree('a');
    my @anodes = $aroot->get_descendants({'ordered' => 1});
    my $sentence_rest = $zone->sentence();
    my $decoded_sentence = '';
    # We cannot apply decode_characters() to the whole sentence. Some regular
    # expression could match across node boundary and the result would differ
    # from the concatenation of decoded nodes.
    # First character of the sentence has position 0. Node anchor is given as
    # a closed-open interval, i.e., the right margin is the position of the first
    # character outside the node.
    my $from = 0;
    foreach my $anode (@anodes)
    {
        my $form = $anode->form();
        my $l = length($form);
        ###!!! If English text was processed by Treex, chances are that certain characters
        ###!!! were normalized in <form> but not in <sentence>, which will cause errors now.
        ###!!! Try to fix known instances using ad-hoc rules.
        if($form eq '``' && $sentence_rest =~ m/^"/) # "
        {
            $form = '"';
            $l = length($form);
        }
        elsif($form eq "''" && $sentence_rest =~ m/^"/) # "
        {
            $form = '"';
            $l = length($form);
        }
        ###!!! End of hacking normalized characters.
        if(substr($sentence_rest, 0, $l) eq $form)
        {
            # We have matched the original form against the original sentence rest.
            # Now it is time to decode the characters in the form.
            my $decoded_form = $self->decode_characters($form);
            my $decoded_length = length($decoded_form);
            $sentence_rest = substr($sentence_rest, $l);
            $decoded_sentence .= $decoded_form;
            my $to = $from + $decoded_length;
            $anode->wild()->{decoded_form} = $decoded_form;
            $anode->wild()->{anchor} = {'from' => $from, 'to' => $to};
            $from = $to;
            # Now deal with spaces after the node, if any.
            my $nspaces = $sentence_rest =~ s/^(\s+)//;
            my $spaces = $1;
            if($nspaces)
            {
                $decoded_sentence .= $spaces;
                $from += $nspaces;
            }
        }
        else # form does not match the rest of the sentence!
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
    ###!!! Sanity check. Make sure that the anchors indeed yield the decoded forms of a-nodes.
    foreach my $anode (@anodes)
    {
        my $decoded_form = $anode->wild()->{decoded_form};
        my $form_by_anchors = substr($decoded_sentence, $anode->wild()->{anchor}{from}, $anode->wild()->{anchor}{to} - $anode->wild()->{anchor}{from});
        if($form_by_anchors ne $decoded_form)
        {
            log_fatal("Something went wrong: decoded form is '$decoded_form' but the anchors point to '$form_by_anchors'.");
        }
    }
    return $decoded_sentence;
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
    ###!!! DZ 31.5.2020:
    ###!!! The decoding of characters was encouraged by Stephan Oepen and introduced for the SDP 2014 and 2015 SemEval tasks (separate blocks Write::SDP(2015)).
    ###!!! However, it is no longer wanted in CoNLL MRP shared task 2020 because of compatibility with other frameworks that cover the Wall Street Journal.
    ###!!! And it is unsuitable for the Czech data from PDT because it targets the English Penn Treebank.
    ###!!! Even if we want to use it, it should be moved to a separate block, which would then be called before Write::MrpJSON!
    if(0)
    {
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
        $x =~ s/`/\x{2018}/g; # `
        # English closing single quotation mark.
        # Includes cases where the character is used as apostrophe: 's s' 're 've n't etc.
        # According to the Unicode standard, U+2019 is the preferred character for both the single quote and the apostrophe,
        # despite their different semantics. See also
        # http://www.cl.cam.ac.uk/~mgk25/ucs/quotes.html and
        # http://www.unicode.org/versions/Unicode6.2.0/ch06.pdf (page 200)
        $x =~ s/'/\x{2019}/g; # '
        # N-dash.
        $x =~ s/--/\x{2013}/g;
        # Ellipsis.
        $x =~ s/\.\.\./\x{2026}/g;
    }
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



#------------------------------------------------------------------------------
# Takes a list of pairs [name, value] and returns the corresponding JSON
# structure {"name1": "value1", "name2": "value2"}. The pair is an arrayref;
# if there is a third element in the array and it says "numeric", then the
# value is treated as numeric, i.e., it is not enclosed in quotation marks.
#------------------------------------------------------------------------------
sub encode_json
{
    my $self = shift;
    my @json = @_;
    # Encode JSON.
    my @json1 = ();
    foreach my $pair (@json)
    {
        my $name = '"'.$pair->[0].'"';
        my $value;
        if(defined($pair->[2]))
        {
            if($pair->[2] eq 'numeric')
            {
                $value = $pair->[1];
            }
            elsif($pair->[2] eq 'list')
            {
                # Assume that each list element is a string.
                my @array_json = ();
                foreach my $element (@{$pair->[1]})
                {
                    my $element_json = $element;
                    $element_json = $self->escape_json_string($element_json);
                    $element_json = '"'.$element_json.'"';
                    push(@array_json, $element_json);
                }
                $value = '['.join(', ', @array_json).']';
            }
            elsif($pair->[2] eq 'list of numeric')
            {
                # Assume that each list element is numeric.
                my @array_json = ();
                foreach my $element (@{$pair->[1]})
                {
                    push(@array_json, $element);
                }
                $value = '['.join(', ', @array_json).']';
            }
            elsif($pair->[2] eq 'list of structures')
            {
                # Assume that each list element is a structure.
                my @array_json = ();
                foreach my $element (@{$pair->[1]})
                {
                    my $element_json = $self->encode_json(@{$element});
                    push(@array_json, $element_json);
                }
                $value = '['.join(', ', @array_json).']';
            }
            else
            {
                log_fatal("Unknown value type '$pair->[2]'.");
            }
        }
        else # value is a string
        {
            if(!defined($pair->[1]))
            {
                log_warn("Unknown value of attribute '$name'.");
            }
            $value = $pair->[1];
            $value = $self->escape_json_string($value);
            $value = '"'.$value.'"';
        }
        push(@json1, "$name: $value");
    }
    my $json = '{'.join(', ', @json1).'}';
    return $json;
}



#------------------------------------------------------------------------------
# Takes a string and escapes characters that would prevent it from being used
# in JSON. (For control characters, it throws a fatal exception instead of
# escaping them because they should not occur in anything we export in this
# block.)
#------------------------------------------------------------------------------
sub escape_json_string
{
    my $self = shift;
    my $string = shift;
    # https://www.ietf.org/rfc/rfc4627.txt
    # The only characters that must be escaped in JSON are the following:
    # \ " and control codes (anything less than U+0020)
    # Escapes can be written as \uXXXX where XXXX is UTF-16 code.
    # There are a few shortcuts, too: \\ \"
    $string =~ s/\\/\\\\/g; # escape \
    $string =~ s/"/\\"/g; # escape " # "
    if($string =~ m/[\x{00}-\x{1F}]/)
    {
        log_fatal("The string must not contain control characters.");
    }
    return $string;
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

Note that the MRP graphs can be visualized using 'mtool' (maintained by the
organizers of the MRP task) and by the 'dot' tool:

C<treex -Len Read::Treex from=... Write::MrpJSON to=... | /net/work/people/zeman/mrptask/sharedata/mtool/main.py --read mrp --write dot --ids - wsj.dot && dot -Tpdf wsj.dot &gt; wsj.pdf>

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
