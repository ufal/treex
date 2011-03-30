package Treex::Block::W2A::ParseMalt;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has _parser     => ( is => 'rw' );

use Parser::Malt::MaltParser;

sub BUILD {
    my ($self) = @_;
    $self->_set_parser(Parser::Malt::MaltParser->new($self->language));
    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants({ordered => 1});

    # Parse the sentence (collect indices refering to parents)
    my @forms  = map { $_->form } @a_nodes;
    my @tags   = map { $_->tag } @a_nodes;
    my @lemmas = map { $_->lemma } @a_nodes;

    my ( $parent_indices, $afuns ) = $self->_parser->parse( \@forms, \@lemmas, \@tags );
    if ( not $parent_indices ) {
        log_warn "Malt parser cannot parse sentence '" . ( join " ", @forms ) . "', flat a-tree is used instead";
    }
    else {
        unshift @a_nodes, $a_root;
        foreach my $i ( 1 .. $#a_nodes ) {

            # set parent
            my $parent = $a_nodes[ $$parent_indices[ $i - 1 ] || 0 ];
            $a_nodes[$i]->set_parent($parent);

            # set afun/conll_deprel
            my $afun = $$afuns[ $i - 1 ];
            log_fatal 'Node ' . $a_nodes[$i]->id . " got no afun/conll_deprel." if !defined $afun;

            if ( $self->language eq 'cs') {
                $afun =~ s/ROOT/Pred/;    # TODO: Is this needed? And why?
                if ( $afun =~ /^(.+)_M$/ ) {
                    $afun = $1;
                    $a_nodes[$i]->set_is_member(1);
                }
                $a_nodes[$i]->set_afun($afun);
            }
            else {
                $a_nodes[$i]->set_conll_deprel($afun);
            }
        }
    }
    return;
}


1;

__END__

=pod

=over

=item Treex::Block::W2A::ParseMalt

Parse analytical trees using MaltParser.

=back

=cut

# Copyright 2009-2011 David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
