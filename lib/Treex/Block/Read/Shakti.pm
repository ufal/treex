package Treex::Block::Read::Shakti;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

# I am not using XML::Parser because it is more sensitive to syntax errors and the Shakti Standard Format is not valid XML.
use HTML::Parser;
# use strict should not complain about these variables.
# They will be declared local so that they are visible for callback functions within HTML::Parser.
use vars qw($self $state);

#------------------------------------------------------------------------------
# Handles opening SGML tag. It is not a method of this block because it does
# not take $self as the first parameter. Nevertheless it assumes that $self is
# accessible in the current namespace. It also accesses hashref $state.
#------------------------------------------------------------------------------
sub start_hook
{
    my $element = shift;
    my $attr = shift; # reference to hash
    if($element eq 'document')
    {
        $state->{current_document} = $self->new_document();
        $state->{current_document}->set_description($attr->{id});
        $state->{current_dzone} = $state->{current_document}->create_zone($self->language(), $self->selector());
        $state->{current_document_text} = '';
    }
    # HTML::Parser lowercases all element names before processing. Shakti spells "Sentence".
    elsif($element eq 'sentence')
    {
        $state->{current_bundle} = $state->{current_document}->create_bundle();
        $state->{current_bzone} = $state->{current_bundle}->create_zone($self->language(), $self->selector());
        $state->{reading_sentence} = 1;
        $state->{sentence} = '';
        $state->{fss} = [];
    }
    # The <fs> tags appear inside the <Sentence> element, mixed with text.
    # There are only start tags, no end tags (not even the XML start+end <tag/>). Their attributes matter.
    elsif($element eq 'fs')
    {
        push(@{$state->{fss}}, $attr);
    }
}

#------------------------------------------------------------------------------
# Handles closing SGML tag. It is not a method of this block because it does
# not take $self as the first parameter. Nevertheless it assumes that $self is
# accessible in the current namespace. It also accesses hashref $state.
#------------------------------------------------------------------------------
sub end_hook
{
    my $element = shift;
    if($element eq 'document')
    {
        $state->{current_dzone}->set_text($state->{current_document_text});
        delete($state->{current_document_text});
        delete($state->{current_dzone});
        # Do not delete the reference to the current_document. This block will
        # have to return the document. Keep the reference to the last (and
        # hopefully the only) <document> read.
    }
    # HTML::Parser lowercases all element names before processing. Shakti spells "Sentence".
    elsif($element eq 'sentence')
    {
        process_shakti_sentence();
        delete($state->{current_bzone});
        delete($state->{current_bundle});
        $state->{reading_sentence} = 0;
        delete($state->{sentence});
        delete($state->{fss});
    }
}

#------------------------------------------------------------------------------
# Handles text. It is not a method of this block because it does not take $self
# as the first parameter. Nevertheless it assumes that $self is accessible in
# the current namespace. It also accesses hashref $state.
#------------------------------------------------------------------------------
sub text_hook
{
    my $text = shift;
    if($state->{reading_sentence})
    {
        $state->{sentence} .= $text;
    }
}

#------------------------------------------------------------------------------
# Processes contents of the <Sentence> element. There is no internal XML
# structure although there are <fs ...> "tags" thrown in the text.
#------------------------------------------------------------------------------
sub process_shakti_sentence
{
    my $ss = $state->{sentence}; # $state should have been declared local.
    my $zone = $state->{current_bzone};
    my @lines = split(/\n/, $ss);
    my @chunks;
    my @tokens;
    my $ord = 0;
    foreach my $line (@lines)
    {
        if($line =~ m/^(\d+)\t\(\(\t(\w+)\t/)
        {
            # New chunk starts here.
            $ord++;
            my $chunk_id = $1;
            my $chunk_tag = $2;
            if(!@{$state->{fss}})
            {
                log_warn('Missing <fs> for chunk. Something went wrong.');
            }
            my $fs = shift(@{$state->{fss}});
            push(@chunks, {'id' => $chunk_id, 'ord' => $ord, 'tag' => $chunk_tag, 'fs' => $fs});
        }
        elsif($line =~ m/^(\d+)\.(\d+)\t(\S+)\t(\w+)\t/)
        {
            # Token in chunk.
            $ord++;
            my $chunk_id = $1;
            my $token_id = $2;
            my $form = $3;
            my $tag = $4;
            if(!@{$state->{fss}})
            {
                log_warn('Missing <fs> for token. Something went wrong.');
            }
            my $fs = shift(@{$state->{fss}});
            if(@chunks)
            {
                my $current_chunk = $chunks[$#chunks];
                if($chunk_id != $current_chunk->{id})
                {
                    log_warn("Chunk id mismatch: token $chunk_id.$token_id found in chunk $current_chunk->{id}");
                }
                push(@{$current_chunk->{tokens}}, {'id' => $token_id, 'ord' => $ord, 'form' => $form, 'tag' => $tag, 'fs' => $fs});
            }
            push(@tokens, $form);
        }
        elsif($line =~ m/^\t\)\)/)
        {
            # Current chunk ends here.
        }
        else
        {
            log_warn("Unrecognized line format: '$line'");
        }
    }
    my $sentence = join(' ', @tokens);
    $zone->set_sentence($sentence);
    $state->{current_document_text} .= "$sentence\n";
    # Create a-tree of chunks.
    my $root = $zone->create_atree();
    my %node_for_chunk;
    foreach my $chunk (@chunks)
    {
        my $node = $root->create_child();
        $node->_set_ord($chunk->{ord});
        $node->set_form($chunk->{fs}->{name});
        $node->set_lemma('CHUNK');
        $node->set_tag($chunk->{tag});
        $node->set_conll_cpos($chunk->{tag});
        $node->set_conll_pos($chunk->{tag});
        if(defined($chunk->{fs}->{drel}) && $chunk->{fs}->{drel} =~ m/^(\w+):(\w+)$/)
        {
            $node->set_conll_deprel($1);
            $node->wild()->{parent_name} = $2;
        }
        else
        {
            $node->set_conll_deprel('ROOT');
            $node->wild()->{stype} = $chunk->{fs}->{stype};
            $node->wild()->{voicetype} = $chunk->{fs}->{voicetype};
        }
        $node_for_chunk{$chunk->{fs}->{name}} = $node;
        # Create nodes for tokens inside the chunk.
        foreach my $token (@{$chunk->{tokens}})
        {
            my $toknode = $node->create_child();
            $toknode->_set_ord($token->{ord});
            $toknode->set_form($token->{form});
            $toknode->set_tag($token->{tag});
            $toknode->set_conll_cpos($token->{tag});
            $toknode->set_conll_pos($token->{tag});
            $toknode->set_conll_feat($token->{fs}->{af});
            $toknode->set_conll_deprel('CHUNK');
        }
    }
    # All chunks have nodes now and we can find the nodes via chunk names. Link the dependencies.
    foreach my $chunk (@chunks)
    {
        my $ccnode = $node_for_chunk{$chunk->{fs}->{name}};
        if(!defined($ccnode))
        {
            # This should never happen. The above code should have created a node for every chunk.
            log_fatal('Missing node for chunk');
        }
        next if($ccnode->conll_deprel() eq 'ROOT');
        my $wild = $ccnode->wild();
        my $pcname = $wild->{parent_name};
        my $pcnode = $node_for_chunk{$pcname};
        if(!defined($pcnode))
        {
            # This could happen if there is an error in the input data.
            log_warn("Unknown parent chunk $pcname");
        }
        else
        {
            $ccnode->set_parent($pcnode);
        }
        # The wild attribute parent_name is no longer needed and should nod be saved in the Treex file.
        delete($wild->{parent_name});
    }
    return $root;
}

#------------------------------------------------------------------------------
# Reads next file and creates corresponding Treex data structures.
#------------------------------------------------------------------------------
sub next_document
{
    local $self = shift; # local so that the callback functions within HTML::Parser see it.
    # Read Shakti source from the next file.
    my $shakti = $self->next_document_text();
    return if(!defined($shakti));
    my $parser = HTML::Parser->new
    (
        api_version => 3,
        start_h => [\&start_hook, 'tagname, attr'],
        end_h   => [\&end_hook,   'tagname'],
        text_h  => [\&text_hook,  'dtext']
    );
    local $state;
    $parser->parse($shakti);
    return $state->{current_document};
}

1;

__END__

=head1 NAME

Treex::Block::Read::Shakti

=head1 DESCRIPTION

Document reader for the Shakti Standard Format (SSF).
Corpora from IIIT Hyderabad are saved and distributed in this SGML/XML-based format.
Main feature: sentences are chunked, there are dependencies between chunks, not tokens.
This block creates a-tree nodes for both chunks and tokens; tokens are children of their chunks.
One may later want to collapse chunks and have only nodes for tokens. That would require at least figuring out chunk heads.
Lemmas (if present at all) are hidden somewhere in the conll_feat attribute. Their exact format may vary across corpora
so we do not attempt to identify them and move them to the lemma attribute.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
