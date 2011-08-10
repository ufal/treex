package Treex::Block::Print::TagStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _tagset => ( is => 'ro', default => sub { {} } );
has _tagex  => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self   = shift;
    my $anode  = shift;
    my $tagset = $self->_tagset();
    my $tagex  = $self->_tagex();
    my @tag;
    push( @tag, $anode->conll_cpos() ) if ( defined( $anode->conll_cpos() ) );
    push( @tag, $anode->conll_pos() )  if ( defined( $anode->conll_pos() ) );
    push( @tag, $anode->conll_feat() ) if ( defined( $anode->conll_feat() ) );
    push( @tag, $anode->tag() )        if ( defined( $anode->tag() ) );
    push( @tag, '' ) unless (@tag);
    my $tag = join( "\t", @tag );
    $tagset->{$tag}++;

    # Remember the position of the first example of every tag.
    if ( !exists( $tagex->{$tag} ) )
    {
        my $file            = $anode->get_document()->full_filename();
        my $sentence_number = $anode->get_bundle()->get_position() + 1;
        my $form            = $anode->form();
        $tagex->{$tag} = "$file#$sentence_number:$form";
    }
}

sub DEMOLISH
{
    my $self     = shift;
    my $tagset   = $self->_tagset();
    my $tagex    = $self->_tagex();
    my $n_types  = 0;
    my $n_tokens = 0;
    foreach my $tag ( sort( keys( %{$tagset} ) ) )
    {
        my $freq    = $tagset->{$tag};
        my $example = $tagex->{$tag};
        print { $self->_file_handle() } ("$tag\t$freq\t$example\n");
        $n_types++;
        $n_tokens += $freq;
    }
    print { $self->_file_handle() } ("TOTAL $n_types TAG TYPES FOR $n_tokens TOKENS\n");
}

1;

=head1 NAME

Treex::Block::Print::TagStats

=head1 DESCRIPTION

Lists all encountered C<conll/cpos,pos,feat> and C<tag>s with frequencies.

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
