package Treex::Block::Write::SDP2014;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value
Readonly my $NO_NUMBER => -1;     # CoNLL-ST format: undefined integer value

has '+language' => ( required => 1 );
has '+extension' => ( default => '.conll' );
has 'formatted' => ( is => 'ro', isa => 'Bool', default => 0, documentation => 'Append spaces to values so that all columns are aligned.' );
has 'compact' => ( is => 'ro', isa => 'Bool', default => 0,
    documentation => 'Default is unreadable CoNLL-2009-like format with large and variable number of columns. '.
    'This parameter triggers a compact format resembling CoNLL 2006, with fixed number of columns; however, HEAD and DEPREL columns may contain comma-separated lists of values.' );



#------------------------------------------------------------------------------
# We will output tectogrammatical annotation but we want the output to include
# all input tokens, including those that are hidden on the tectogrammatical
# layer.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    # Print sentence identifier.
    # We assume that the input file comes from the PTB and is named according to PTB naming conventions.
    # Bundle->get_position() is not efficient (see comment there) so we may consider simply counting the sentences using an attribute of this block.
    my $ptb_section_file = $zone->get_document()->file_stem();
    $ptb_section_file =~ s/^wsj_//i;
    printf {$self->_file_handle()} ("#2%s%03d\n", $ptb_section_file, $zone->get_bundle()->get_position()+1);
    # Compute correspondences between t-nodes and a-nodes.
    my @tnodes = $troot->get_descendants({ordered => 1});
    foreach my $tnode (@tnodes)
    {
        my $anode = $tnode->get_lex_anode();
        if(defined($anode))
        {
            # Occasionally a token is re-tokenized on the t-layer and there are several t-nodes corresponding to one a-node.
            # Example: "1/2" -> "1", "#Slash", "2" (annotated as coordination headed by #Slash).
            # We store the link to the first t-node found for subsequent functions that can deal with at most one t-node.
            # We store separately links to all t-nodes found for functions that can use them all.
            $anode->wild()->{tnode} = $tnode unless(defined($anode->wild()->{tnode}));
            push(@{$anode->wild()->{tnodes}}, $tnode);
        }
    }
    # We require that the token ids make an unbroken sequence, starting at 1.
    # Unfortunately, this is not guaranteed in all a-trees. For example, in PCEDT 2.0 file wsj_0006.treex.gz, sentence 1, several numbers are skipped.
    # So we have to re-index the nodes ourselves.
    $aroot->_normalize_node_ordering();
    my @anodes = $aroot->get_descendants({ordered => 1});
    my @conll = ([]); # left part of table, fixed features per token; dummy first line for the root node [0]
    my @matrix = ([]); # right part of table, relations between nodes: $matrix[$i][$j]='ACT' means node $i depends on node $j and its role is ACT
    my @roots; # binary value for each node index; roots as seen by Stephan Oepen, i.e. our children of the artificial root node
    foreach my $anode (@anodes)
    {
        my $ord = $anode->ord();
        my $tag = $anode->tag();
        my $form = $self->decode_characters($anode->form(), $tag);
        my $lemma = $self->get_lemma($anode);
        push(@conll, [$ord, $form, $lemma, $tag]);
        # Fill @matrix and @roots.
        $self->get_parents($anode, \@matrix, \@roots);
    }
    # Add dependency fields in the required format.
    my @ispred = $self->get_is_pred(\@matrix);
    for(my $i = 1; $i<=$#conll; $i++)
    {
        my @depfields;
        if($self->compact())
        {
            @depfields = $self->get_conll_dependencies_compact(\@matrix, $i);
        }
        else
        {
            @depfields = $self->get_conll_dependencies_wide(\@matrix, $i, \@ispred);
            unshift(@depfields, $roots[$i]);
        }
        push(@{$conll[$i]}, @depfields);
    }
    # Formatting by inserting additional spaces makes the format non-standard.
    # However, it is easy to adjust the CoNLL reader to split fields on "\s+", not just on "\t" (as long as all empty values are converted to '_').
    if($self->formatted())
    {
        $self->format_table(\@conll);
    }
    # Print CoNLL-like representation of the sentence.
    for(my $i = 1; $i<=$#conll; $i++)
    {
        print {$self->_file_handle()} (join("\t", @{$conll[$i]}), "\n");
    }
    # Every sentence must be terminated by a blank line.
    print {$self->_file_handle()} ("\n");
}



#------------------------------------------------------------------------------
# Finds a-node that lexically corresponds to the t-node and returns its ord.
#------------------------------------------------------------------------------
sub get_a_ord_for_t_node
{
    my $self = shift;
    my $tnode = shift;
    # If t-node is root, we will not find its lexically corresponding a-node.
    # We want the a-root even though the correspondence is no longer lexical.
    if($tnode->is_root())
    {
        return 0;
    }
    else
    {
        my $anode = $tnode->get_lex_anode();
        if(defined($anode))
        {
            return $anode->ord();
        }
        else
        {
            # This could happen if we accidentally called the function on a generated t-node.
            # All other t-nodes must have one lexical a-node and may have any number of auxiliary a-nodes.
            return undef;
        }
    }
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
    @tnodes = sort {$a->ord() <=> $b->ord()} (@{$anode->wild()->{tnodes}}) if(defined($anode->wild()->{tnodes}));
    if(scalar(@tnodes)>1)
    {
        $lemma = join('_', map {$self->decode_characters($_->t_lemma())} (@tnodes));
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
# Finds all relations of an a-node to its parents. The relations are
# projections of dependencies in the t-tree. An a-node may have zero, one or
# more parents. The relations are added to the matrix and the array of root
# flags is updated. We expect to get the links to matrix and roots from the
# caller.
#------------------------------------------------------------------------------
sub get_parents
{
    my $self = shift;
    my $anode = shift;
    my $matrix = shift;
    my $roots = shift;
    my $ord = $anode->ord();
    # Is there a lexically corresponding tnode?
    my $tn = $anode->wild()->{tnode};
    my @tnodes;
    @tnodes = sort {$a->ord() <=> $b->ord()} (@{$anode->wild()->{tnodes}}) if(defined($anode->wild()->{tnodes}));
    if(defined($tn))
    {
        # This is a content word and there is at least one lexically corresponding t-node.
        # Add parent relations for all corresponding t-nodes. (Some of them may collapse in the a-tree to a reflexive link.)
        foreach my $tnode (@tnodes)
        {
            my $functor = $NOT_SET;
            if(defined($tnode->functor()))
            {
                $functor = $tnode->functor();
            }
            if(defined($tnode->parent()))
            {
                $roots->[$ord] = $tnode->parent()->is_root() ? '+' : '-';
                # Effective parents are important around coordination or apposition:
                # - CoAp root (conjunction) has no effective parent.
                # - Effective parent of conjuncts is somewhere above the conjunction (its direct parent, unless there is another coordination involved).
                # - Effective parents of shared modifier are the conjuncts.
                my @eparents;
                unless($tnode->is_coap_root())
                {
                    @eparents = $tnode->get_eparents();
                }
                if(scalar(@eparents)>0)
                {
                    foreach my $ep (@eparents)
                    {
                        my $pord = $self->get_a_ord_for_t_node($ep);
                        if(defined($pord))
                        {
                            $matrix->[$ord][$pord] = $functor;
                        }
                    }
                }
                if($tnode->is_member())
                {
                    my $pord = $self->get_a_ord_for_t_node($tnode->parent());
                    my $mfunctor = $tnode->parent()->functor().'.member';
                    if(defined($pord))
                    {
                        $matrix->[$ord][$pord] = $mfunctor;
                    }
                }
            }
        }
    }
    else
    {
        # This is an auxiliary word. There is a t-node to which it belongs but they do not correspond lexically.
        $roots->[$ord] = '-';
    }
    return $matrix;
}



#------------------------------------------------------------------------------
# Formats a table (like that of CoNLL format) for better readability by adding
# spaces at the end of cell values. This is a deviation from the standard CoNLL
# format! CoNLL readers could be easily modified to handle this, though.
#------------------------------------------------------------------------------
sub format_table
{
    my $self = shift;
    my $table = shift;
    my @lengths;
    for(my $i = 0; $i<=$#{$table}; $i++)
    {
        for(my $j = 0; $j<=$#{$table->[$i]}; $j++)
        {
            my $l = length($table->[$i][$j]);
            if(!defined($lengths[$j]) || $lengths[$j]<$l)
            {
                $lengths[$j] = $l;
            }
        }
    }
    for(my $i = 0; $i<=$#{$table}; $i++)
    {
        for(my $j = 0; $j<=$#{$table->[$i]}; $j++)
        {
            my $l = length($table->[$i][$j]);
            my $filling = ' ' x ($lengths[$j]-$l);
            $table->[$i][$j] .= $filling;
        }
    }
}



#------------------------------------------------------------------------------
# Takes a matrix of graph relations: $matrix[$i][$j] = 'ACT' means that node $i
# depends on node $j and the label of the relation is 'ACT'. Also takes index
# of current dependent node. Returns CoNLL dependency fields for that node in
# the compact format, i.e. there are two fields, each can contain a comma-
# -separated list of values. The first field contains links to parents, the
# second field contains labels of relations.
#------------------------------------------------------------------------------
sub get_conll_dependencies_compact
{
    my $self = shift;
    my $matrix = shift;
    my $iline = shift;
    my @parents;
    my @labels;
    for(my $i = 0; $i<=$#{$matrix->[$iline]}; $i++)
    {
        if(defined($matrix->[$iline][$i]))
        {
            push(@parents, $i);
            push(@labels, $matrix->[$iline][$i]);
        }
    }
    my $parents = @parents ? join(',', @parents) : $NOT_SET;
    my $labels = @labels ? join(',', @labels) : $NOT_SET;
    return ($parents, $labels);
}



#------------------------------------------------------------------------------
# Takes a matrix of graph relations: $matrix[$i][$j] = 'ACT' means that node $i
# depends on node $j and the label of the relation is 'ACT'. Also takes index
# of current dependent node. Returns CoNLL dependency fields for that node in
# the wide format, i.e. there are variable number of fields, depending of the
# number of predicates in the sentence, each contains the label of relation if
# there is a relation.
#------------------------------------------------------------------------------
sub get_conll_dependencies_wide
{
    my $self = shift;
    my $matrix = shift;
    my $iline = shift;
    my $ispred = shift;
    my @labels;
    for(my $j = 1; $j<=$#{$ispred}; $j++)
    {
        if($ispred->[$j])
        {
            if(defined($matrix->[$iline][$j]))
            {
                push(@labels, $matrix->[$iline][$j]);
            }
            else
            {
                push(@labels, $NOT_SET);
            }
        }
    }
    my $this_is_pred = $ispred->[$iline] ? '+' : '-';
    return ($this_is_pred, @labels);
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



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::SDP2014

=head1 DESCRIPTION

Prints out all t-trees in the text format required for the SemEval shared task
on Semantic Dependency Parsing, 2014. The English part of PCEDT is used in the
shared task but the block should work for other t-trees as well. The format is
similar to CoNLL, i.e. one token/node per line, tab-separated values on the
line, sentences/trees terminated by a blank line.

The format is described here:
http://alt.qcri.org/semeval2014/task8/index.php?id=data-and-tools

Sample usage:

C<treex -Len Read::Treex from='!/net/data/pcedt2.0/data/00/wsj_00[012]*.treex.gz' Write::SDP2014 path=./trial-pcedt extension=.conll formatted=0 compact=0>

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=item C<formatted>

Binary value (0 or 1), 0 is default.
If set, additional spaces will be added to field values where necessary to make columns aligned.
It makes the CoNLL format a bit non-standard.
However, it is easy to adjust the CoNLL reader to split fields on "\s+", not just on "\t" (as long as all empty values are converted to '_').

=item C<compact>

Binary value (0 or 1), 0 is default.
Default format is derived from CoNLL 2009. It has large and variable number of columns, which is difficult for humans to read.
This parameter triggers a compact format resembling CoNLL 2006, with fixed number of columns;
however, C<HEAD> and C<DEPREL> columns may contain comma-separated lists of values.

=back

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
