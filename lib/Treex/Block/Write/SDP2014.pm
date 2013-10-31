package Treex::Block::Write::SDP2014;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value
Readonly my $NO_NUMBER => -1;     # CoNLL-ST format: undefined integer value

has '+language' => ( required => 1 );
has '+extension' => ( default => '.conll' );



#------------------------------------------------------------------------------
# We will output tectogrammatical annotation but we want the output to include
# all input tokens, including those that are hidden on the tectogrammatical
# layer.
#------------------------------------------------------------------------------
sub process_zone
{
    my $this = shift;
    my $zone = shift;
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    my @tnodes = $troot->get_descendants({ordered => 1});
    foreach my $tnode (@tnodes)
    {
        my $anode = $tnode->get_lex_anode();
        if(defined($anode))
        {
            $anode->wild()->{tnode} = $tnode;
        }
    }
    my @anodes = $aroot->get_descendants({ordered => 1});
    foreach my $anode (@anodes)
    {
        my $ord = $anode->ord();
        my $form = $anode->form();
        my $lemma = $anode->lemma();
        my $tag = $anode->tag();
        # Is there a lexically corresponding tnode?
        my $tnode = $anode->wild()->{tnode};
        my $type;
        my $parent_id = $NOT_SET;
        my $functor = $NOT_SET;
        if(defined($tnode))
        {
            # This is a content word and there is a lexically corresponding t-node.
            $lemma = $tnode->t_lemma();
            $type = 't';
            my $aparent = $self->get_a_parent_for_t_node($tnode);
            if(defined($aparent))
            {
                $parent_id = $aparent->ord();
                    ###!!! Kvůli koordinacím musíme dohledat také efektivní rodiče. Nejdřív musíme mít jistotu, že existuje alespoň nějaký rodič, jinak get_eparents hodí varování.
                    ###!!! A pozor, na tektogramatické rovině je mnohem více funktorů, které signalizují koordinaci. Např. CONJ nebo DISJ - zahrnují totiž druh koordinace.
                    ###!!! my @effective_parents = $node->get_eparents($arg_ref?)
            }
            if(defined($tnode->functor()))
            {
                $functor = $tnode->functor();
            }
        }
        else
        {
            # This is an auxiliary word. There is a t-node to which it belongs but they do not correspond lexically.
            $type = 'a';
        }
        print {$this->_file_handle} ("$ord\t$form\t$lemma\t$tag\t$type\t$parent_id\t$functor");
        # Terminate the line.
        print {$this->_file_handle} ("\n");
    }
    # Every sentence must be terminated by a blank line.
    print {$this->_file_handle} ("\n");
}



#------------------------------------------------------------------------------
# Finds a-node that lexically corresponds to the t-parent of a t-node.
#------------------------------------------------------------------------------
sub get_a_parent_for_t_node
{
    my $self = shift;
    my $tnode = shift;
    my $aparent;
    # If there is no t-parent, the result is undefined.
    if($tnode->is_root())
    {
        return undef;
    }
    # If parent is t-root, we will not find its lexically corresponding a-node. But we want a-root.
    # Even though the correspondence is no longer lexical.
    if($tnode->parent()->is_root())
    {
        $aparent = $tnode->get_lex_anode()->get_root();
    }
    else
    {
        $aparent = $tnode->parent()->get_lex_anode();
    }
    return $aparent;
}



1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::SDP2014

=head1 DESCRIPTION

Prints out all t-trees in the text format required for the SemEval shared task
on Semantic Dependency Parsing, 2014. The format is similar to CoNLL, i.e. one
token/node per line, tab-separated values on the line, sentences/trees
terminated by a blank line.

=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
