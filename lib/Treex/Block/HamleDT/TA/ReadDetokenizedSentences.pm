package Treex::Block::HamleDT::TA::ReadDetokenizedSentences;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



has 'from' =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'Path to the file with the sentences, one sentence per line.'
);

has 'sentences' =>
(
    is            => 'ro',
    isa           => 'ArrayRef',
    required      => 1,
    default       => sub {[]}
);



#------------------------------------------------------------------------------
# Reads the detokenized sentences. It reads them all at once. The assumption is
# that the document is not too large and that we can keep it in memory. This is
# definitely true for the first version of the Tamil Treebank.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    my $from = $self->from();
    my $sentences = $self->sentences();
    open(SENT, $from) or log_fatal("Cannot read $from: $!");
    binmode(SENT, ':utf8');
    while(<SENT>)
    {
        chomp();
        push(@{$sentences}, $_);
    }
    close(SENT);
}



#------------------------------------------------------------------------------
# Takes detokenized sentences one at a time, and stores them with the bundles.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $sentences = $self->sentences();
    my $next_sentence = shift(@{$sentences});
    if(defined($next_sentence))
    {
        $zone->set_sentence($next_sentence);
        # We want the detokenized sentence to appear as a comment in the CoNLL-U output.
        # This is a temporary measure before we manage to represent everything as fused words
        # and with the no_space_after attribute.
        my $wild = $zone->get_bundle()->wild();
        my $comment = $wild->{comment};
        if(defined($comment) && $comment ne '')
        {
            $comment .= "\n";
        }
        $comment .= 'full_sent '.$next_sentence;
        $wild->{comment} = $comment;
    }
    else
    {
        log_warn('Bad synchronization. There is no remaining detokenized sentence for this bundle.');
    }
}



1;

=over

=item Treex::Block::HamleDT::TA::ReadDetokenizedSentences

The Tamil Treebank 0.1 lacks information needed to reconstruct the original
pre-tokenization text. Besides punctuation separated from words, tokenization
occasionally also involves splitting words to smaller units (syntactic words).
Loganathan has written a script that reconstructs the original sentences and
provided the output in text files, one sentence per line.

This block reads Loganathan's reconstructed files, then takes the next sentence
for each bundle it processes, and stores the sentence in the bundle's C<sentence>
attribute. Hence it combines the detokenized sentences with the trees.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2015 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
