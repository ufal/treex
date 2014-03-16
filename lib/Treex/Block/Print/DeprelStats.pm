package Treex::Block::Print::DeprelStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has attribute  => ( is => 'rw', default => 'conll_deprel' );
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

    # Remember the position of the first example of every tag.
    if ( !exists( $deprelex->{$deprel} ) )
    {
        my $file            = $anode->get_document()->full_filename();
        my $sentence_number = $anode->get_bundle()->get_position() + 1;
        my $form            = $anode->form();
        $deprelex->{$deprel} = "$file#$sentence_number:$form";
    }
}

sub process_end
{
    my $self      = shift;
    my $deprelset = $self->_deprelset();
    my $deprelex  = $self->_deprelex();
    my $n_types   = 0;
    my $n_tokens  = 0;
    foreach my $tag ( sort( keys( %{$deprelset} ) ) )
    {
        my $freq    = $deprelset->{$tag};
        my $example = $deprelex->{$tag};
        print { $self->_file_handle() } ("$tag\t$freq\t$example\n");
        $n_types++;
        $n_tokens += $freq;
    }
    print { $self->_file_handle() } ("TOTAL $n_types TAG TYPES FOR $n_tokens TOKENS\n");
}

1;

=head1 NAME

Treex::Block::Print::DeprelStats

=head1 DESCRIPTION

Lists all encountered C<conll/deprel> tags with frequencies.

The optional C<attribute> parameter can be used to collect afuns instead of conll deprels.
In fact, the parameter makes this a pretty general block to collect value frequencies
from any attribute of a-nodes.

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
