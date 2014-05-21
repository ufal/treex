package Treex::Block::Eval::SentencesWithIncompleteMorphology;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has _statistics => ( is => 'ro', default => sub { {} } );



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $stat = $self->_statistics();
    $stat->{n_sentences}++;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        my $tag = $node->tag();
        if(!defined($lemma) || !defined($tag) || $lemma eq '' || $tag eq '')
        {
            # This sentence is bad.
            $stat->{n_bad_sentences}++;
            last;
        }
    }
}



sub process_end
{
    my $self = shift;
    my $stat = $self->_statistics();
    my $n = defined($stat->{n_sentences}) ? $stat->{n_sentences} : 0;
    my $nb = defined($stat->{n_bad_sentences}) ? $stat->{n_bad_sentences} : 0;
    print("$n sentences\n");
    print("$nb bad sentences (contain at least one node with empty lemma or tag)\n");
}



1;

=over

=item Treex::Block::Eval::SentencesWithIncompleteMorphology

Counts sentences (a-trees) that contain at least one non-root node with undefined
or empty lemma or tag.

This is a debugging block created because of the Prague Arabic Dependency Treebank 1.5.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
