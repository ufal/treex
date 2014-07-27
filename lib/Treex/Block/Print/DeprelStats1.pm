package Treex::Block::Print::DeprelStats1;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has attribute  => ( is => 'rw', default => 'conll/deprel' );
has _deprelset => ( is => 'ro', default => sub { {} } );
has _deprelex  => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self      = shift;
    my $anode     = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    #my $deprel    = $anode->conll_deprel();
    my $deprel    = $anode->get_attr($self->attribute());
    $deprel = '' if ( !defined($deprel) );
    $deprelset->{$deprel}++;
    # Remember example words and their frequencies for every tag.
    my $form = $anode->form();
    $deprelex->{$deprel}{$form}++;
    # Print addresses of examples we are looking for.
    # You can redirect STDOUT to > filelist, then run "ttred -l filelist" and browse the examples.
    if($deprel eq 'lot' && $anode->parent()->conll_pos() !~ m/^(JNT)$/)
    {
        print($anode->get_address(), "\n");
    }
}

sub process_end
{
    my $self      = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    my $n_types   = 0;
    my $n_tokens  = 0;
    foreach my $tag ( keys( %{$deprelset} ) )
    {
        $n_types++;
        $n_tokens += $deprelset->{$tag};
    }
    foreach my $tag ( sort( keys( %{$deprelset} ) ) )
    {
        my $freq    = $deprelset->{$tag};
        my $relfreq = $n_tokens ? $freq/$n_tokens : 0;
        my @examples = sort {my $v = $deprelex->{$tag}{$b} <=> $deprelex->{$tag}{$a}; if(!$v) {$v = $a cmp $b}; $v;} (keys(%{$deprelex->{$tag}}));
        splice(@examples, 10) if(scalar(@examples)>=10);
        my $examples = join(', ', @examples);
        printf { $self->_file_handle() } ("$tag\t$freq\t%.5f\t$examples\n", $relfreq);
    }
    print { $self->_file_handle() } ("TOTAL $n_types TAG TYPES FOR $n_tokens TOKENS\n");
}

1;

=head1 NAME

Treex::Block::Print::DeprelStats1

=head1 DESCRIPTION

Lists all encountered C<conll/deprel> tags.

Unlike the original DeprelStats, this version writes addresses of all nodes with their C<conll/deprel> value.
The user can use it to create a file list for Tred and browse the examples:

echo > deprels.np.fl
treex -Lhu Read::Treex from='...' Print::DeprelStats1 | grep -P '^NP\t' | cut -f2 > deprels.np.fl
ttred -l deprels.np.fl

Besides, on the end of the run the block also outputs the list of the most frequent words
that appeared with each of the labels.

The optional C<attribute> parameter can be used to collect afuns instead of conll deprels.
In fact, the parameter makes this a pretty general block to collect value frequencies
from any attribute of a-nodes.

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
