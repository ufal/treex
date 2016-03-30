package Treex::Block::Read::Syntagrus;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';
use File::Slurp;

sub next_document_text {
    my ($self) = @_;
    my $FH = $self->current_filehandle;
    if ( !$FH ) {
        $FH = $self->next_filehandle() or return;
        $self->from->_set_current_filehandle($FH);
    }
    if ( $self->is_one_doc_per_file ) {
        $self->from->_set_current_filehandle(undef);
        return read_file($FH);
    }
    
    my $text;
    my $sent_count = 0;

    LINE:
    while (<$FH>) {
        if ( $_ =~ m/<\/S>/ ) {
            $sent_count++;
            return $text if $sent_count == $self->lines_per_doc;
        }
        $text .= $_;
    }
    return $text;
}

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();

    my @parents;
    my @nodes;
    my $aroot;

    foreach my $line ( split /\n/, $text ) {

        # what to do with generated nodes
        # so far, they have their surface form '#Fantom'
        $line =~ s/(<W[^>]+)\/>/$1>#Fantom<\/W>/;
        if ( $line =~ /^<S\s.*>/ ) {
            my $bundle = $document->create_bundle();
            my $zone = $bundle->create_zone( $self->language, $self->selector );
            $aroot   = $zone->create_atree();
            @parents = (0);
            @nodes   = ($aroot);
        }
        elsif ( $line =~ /<\/S>/ ) {
            foreach my $i ( 1 .. $#nodes ) {
                $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
            }
            my $sentence = join('', map {$_->form().($_->no_space_after() ? '' : ' ')} ($aroot->get_descendants({'ordered' => 1})));
            $sentence =~ s/\s+$//;
            $aroot->get_zone()->set_sentence($sentence);
        }
        elsif ( $line =~ /^(.*)<W\s(.+)>(.+)<\/W>(.*)$/ ) {
            # There is usually a space between </W> and the line break, indicating a surface space between words.
            # Sometimes there is one or more punctuation symbols, with or without spaces.
            # Punctuation can appear also before <W>, without spaces.
            my $punct_before = $1;
            my $punct_after  = $4;
            my $word_form    = $3;
            my $attrs        = $2;
            my %attr;
            while ( $attrs =~ s/\s*([^=]+)=\"([^\"]+)\"// ) {
                $attr{$1} = $2;
            }
            my $pbnode;
            if($punct_before)
            {
                # There should be no spaces but just in case.
                $punct_before =~ s/\s//g;
                $pbnode = $self->create_punctuation_node($aroot, $punct_before, 1);
            }
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($word_form);
            $newnode->set_lemma( $attr{'LEMMA'} );
            $newnode->set_tag( $attr{'FEAT'} );
            # Derive conll/cpos, conll/pos and conll/feat from tag.
            $self->fill_conll_attributes( $newnode );
            $newnode->set_deprel( $attr{'LINK'} );
            $attr{'DOM'} = 0 if $attr{'DOM'} eq '_root';
            push @parents, $attr{'DOM'};
            push @nodes,   $newnode;
            # Attach all punctuation nodes to the current non-punctuation node.
            if($pbnode)
            {
                $pbnode->set_parent($newnode);
            }
            if(defined($punct_after))
            {
                if($punct_after !~ m/^\s/)
                {
                    $newnode->set_no_space_after(1);
                }
                $punct_after =~ s/^\s+//;
                if($punct_after ne '')
                {
                    my $finalspace;
                    $finalspace = 1 if($punct_after =~ m/\s$/);
                    $punct_after =~ s/\s+$//;
                    my @punctokens;
                    # If there are multiple space-delimited tokens, we must create separate nodes for them.
                    if($punct_after =~ m/\s\S/)
                    {
                        @punctokens = split(/\s+/, $punct_after);
                    }
                    else
                    {
                        $punctokens[0] = $punct_after;
                    }
                    for(my $i = 0; $i <= $#punctokens; $i++)
                    {
                        # Occasionally there are clusters of symbols like ", and .,
                        # Split them to individual characters (now marking that there is no space after).
                        if(length($punctokens[$i]) > 1 && $punctokens[$i] ne '...')
                        {
                            my @puncchars = split(//, $punctokens[$i]);
                            for(my $j = 0; $j <= $#puncchars; $j++)
                            {
                                my $pnode = $self->create_punctuation_node($aroot, $puncchars[$j], $j<$#puncchars || $i==$#punctokens && !$finalspace);
                                $pnode->set_parent($newnode);
                            }
                        }
                        else
                        {
                            my $pnode = $self->create_punctuation_node($aroot, $punctokens[$i], $i==$#punctokens && !$finalspace);
                            $pnode->set_parent($newnode);
                        }
                    }
                }
            }
            else
            {
                $newnode->set_no_space_after(1);
            }
        }
    }
    return $document;
}

#------------------------------------------------------------------------------
# Creates a new node for a punctuation symbol at the end of the sentence. The
# new node will be attached to the root.
#------------------------------------------------------------------------------
sub create_punctuation_node
{
    my $self = shift;
    my $root = shift;
    my $symbol = shift;
    my $no_space_after = shift;
    my $pnode = $root->create_child();
    # Assume that all nodes are added at the end of the sentence.
    $pnode->shift_after_subtree($root);
    $pnode->set_form($symbol);
    $pnode->set_lemma($symbol);
    $pnode->set_tag('PUNCT');
    $pnode->iset()->set_pos('punc');
    $pnode->set_no_space_after(1) if($no_space_after);
    $pnode->set_deprel('punct');
    $self->fill_conll_attributes($pnode);
    return $pnode;
}

#------------------------------------------------------------------------------
# Fills the CoNLL attributes CPOS, POS and FEAT, based on the value of tag.
# Copies the deprel attribute to the CoNLL attribute DEPREL.
# Some subsequent blocks may need these attributes.
#------------------------------------------------------------------------------
sub fill_conll_attributes
{
    my $self = shift;
    my $node = shift;
    my $tag = $node->tag();
    if (!defined($tag) || $tag =~ m/^\s*$/)
    {
        my $id = $node->id();
        my $form = $node->form() // ''; # / syntax highlighting hack
        log_warn("Undefined tag of node id='$id' form='$form'");
        return;
    }
    # Example tag: 'S ЕД МУЖ ИМ ОД'
    my @features = split(/\s+/, $tag);
    my $pos = shift(@features);
    my $feat = @features ? join('|', @features) : '_';
    $node->set_conll_cpos($pos);
    $node->set_conll_pos($pos);
    $node->set_conll_feat($feat);
    $node->set_conll_deprel($node->deprel());
}

1;

__END__

=head1 NAME

Treex::Block::Read::Syntagrus

=head1 DESCRIPTION

Document reader for SynTagRus dependency treebank.

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

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

David Mareček
Dan Zeman

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
