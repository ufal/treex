package Treex::Block::Eval::Wc;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _stat => ( is => 'ro', default => sub { {} } );

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $stat = $self->_stat();
    my $file = $root->get_document()->full_filename();
    # Remember the number of tokens in each file.
    $stat->{files}{$file}++;
    $stat->{n_sentences}++;
    my @nodes = $root->get_descendants({'add_self' => 0});
    $stat->{n_tokens} += scalar(@nodes);
}

sub process_end
{
    my $self = shift;
    my $stat = $self->_stat();
    my $n_documents = scalar(keys(%{$stat->{files}}));
    printf("%7d documents\n", $n_documents);
    printf("%7d sentences\n", $stat->{n_sentences});
    printf("%7d tokens (including NULL, if applicable)\n", $stat->{n_tokens});
}

1;

=head1 NAME

Treex::Block::Eval::Wc

=head1 DESCRIPTION

Somewhat inspired by the Unix C<wc> command, this block reports the basic statistics about a corpus:
the number of documents, sentences and tokens (non-root nodes).

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
