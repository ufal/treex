package Treex::Block::W2A::EN::ParseMalt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has _parser     => ( is       => 'rw' );
has model       => ( isa => 'Str', is => 'rw', default => 'en.mco' );

use Treex::Tools::Parser::Malt;

sub BUILD {
    my ($self) = @_;
    $self->_set_parser( Treex::Tools::Parser::Malt->new( { model => $self->model } ) );
    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # get factors
    my @forms    = map { $_->form } @a_nodes;
    my @lemmas   = map { $_->lemma } @a_nodes;
    my @subpos   = map { $_->tag } @a_nodes;
    my @pos      = map { substr($_, 0, 2) } @subpos;
    my @features = map { '_' } @subpos;

    # parse sentence
    my ( $parent_indices, $deprels ) = $self->_parser->parse( \@forms, \@lemmas, \@pos, \@subpos, \@features );
    if ( not $parent_indices ) {
        log_warn "Malt parser cannot parse sentence '" . ( join " ", @forms ) . "', flat a-tree is used instead";
    }
    else {
        unshift @a_nodes, $a_root;
        foreach my $i ( 1 .. $#a_nodes ) {

            # set parent
            my $parent = $a_nodes[ $$parent_indices[ $i - 1 ] || 0 ];
            $a_nodes[$i]->set_parent($parent);

            # set conll_deprel
            my $deprel = $$deprels[ $i - 1 ];
            log_fatal 'Node ' . $a_nodes[$i]->id . " has no conll_deprel." if !defined $deprel;

            $a_nodes[$i]->set_conll_deprel($deprel);
        }
    }
    return;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::EN::ParseMalt

Parse analytical trees using MaltParser.

=back

=cut

# Copyright 2009-2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
