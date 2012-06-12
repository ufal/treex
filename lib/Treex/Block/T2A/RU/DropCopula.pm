package Treex::Block::T2A::RU::DropCopula;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    
    if ($t_node->t_lemma eq 'быть' && $t_node->gram_tense eq 'sim'){
        my $a_node = $t_node->get_lex_anode() or return;
        $a_node->set_lemma('');
    }

    return;
}


1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::T2A::RU::DropCopula - delete verb "to be"

=head1 DESCRIPTION

Russian copula verb (быть = to be) in present tense is dropped.
E.g. "He is an idiot" -> "он дурак".

The current implementation just sets the m/lemma to an empty string.

# Copyright 2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
