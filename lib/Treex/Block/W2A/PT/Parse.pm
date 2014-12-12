package Treex::Block::W2A::PT::Parse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::LXParser;

has _parser => ( isa => 'Treex::Tool::Parser::LXParser', is => 'ro',
    required => 1, builder => '_build_parser', lazy=>1 );

has lxsuite_host => ( isa => 'Str', is => 'ro', required => 1);
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 1);
has lxsuite_key  => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_mode => ( isa => 'Str', is => 'ro', required => 0,
                      default => 'conll.pos:parser:conll.lx');

sub BUILD {
    my ($self, $arg_ref) = @_;
    $self->_parser;  # this forces $self->_build_parser()
}

sub _build_parser {
    my $self = shift;
    return Treex::Tool::Parser::LXParser->new({
        lxsuite_key => $self->lxsuite_key,
        lxsuite_host => $self->lxsuite_host,
        lxsuite_port => $self->lxsuite_port,
        lxsuite_mode => $self->lxsuite_mode
    });
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # get factors
    my @forms  = map { $_->form } @a_nodes;
    my @lemmas = map { $_->lemma || '_' } @a_nodes;
    my @pos    = map { $_->conll_pos || '_' } @a_nodes;
    my @cpos   = map { $_->conll_cpos || '_' } @a_nodes;
    my @feats  = map { $_->conll_feat || '_' } @a_nodes;

    # parse sentence
    my ( $parents_rf, $deprel_rf ) = $self->_parser->parse_sentence( \@forms, \@lemmas, \@cpos, \@pos, \@feats );

    # build a-tree
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        my $parent = shift @$parents_rf;

        $a_node->set_conll_deprel($deprel);
        if ($parent) {
            $a_node->set_parent($a_nodes[ $parent - 1 ]);
        } else {
            push @roots, $a_node;
        }
    }
    return @roots;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::PT::Parse

=head1 DESCRIPTION

Uses LXParser to parse a sentence into LX Dependencies.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
