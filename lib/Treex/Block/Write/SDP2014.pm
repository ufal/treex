package Treex::Block::Write::SDP2014;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value
Readonly my $NO_NUMBER => -1;     # CoNLL-ST format: undefined integer value
Readonly my $FILL      => "_";    # CoNLL-ST format: "fill predicate"
Readonly my $TAG_FEATS => {
    "SubPOS" => 1,
    "Gen"    => 2,
    "Num"    => 3,
    "Cas"    => 4,
    "PGe"    => 5,
    "PNu"    => 6,
    "Per"    => 7,
    "Ten"    => 8,
    "Gra"    => 9,
    "Neg"    => 10,
    "Voi"    => 11,
    "Var"    => 14
};    # tag positions and their meanings
Readonly my $TAG_NOT_SET => "-";    # tagset: undefined value

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
            $anode->set_wild('tnode', $tnode);
        }
    }
    my @anodes = $aroot->get_descendants({ordered => 1});
    foreach my $anode (@anodes)
    {
        my $ord = $anode->ord();
        my $form = $anode->form();
        my $lemma = $anode->lemma();
        my $tag = $anode->tag();
        print {$this->_file_handle} ("$ord\t$form\t$lemma\t$tag");
        # Is there a lexically corresponding tnode?
        my $tnode = $anode->get_wild('tnode');
        if(defined($tnode))
        {
            # This is a content word and there is a lexically corresponding t-node.
            print("\tt-node");
        }
        else
        {
            # This is an auxiliary word. There is a t-node to which it belongs but they do not correspond lexically.
            print("\ta-node");
        }
        # Terminate the line.
        print {$this->_file_handle} ("\n");
    }
    # Every sentence must be terminated by a blank line.
    print {$this->_file_handle} ("\n");
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
