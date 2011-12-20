package Treex::Block::Align::A::AlignSameSentence;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language'   => ( required => 1 );
has 'to_language' => ( is       => 'ro', isa => 'Treex::Type::LangCode', lazy_build => 1 );
has 'to_selector' => ( is       => 'ro', isa => 'Treex::Type::Selector', default => 'ref' );

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

sub _align_asymmetry {
    my ($self, $tst_list, $ref_list) = @_;

    foreach my $tst_node (@$tst_list) {
        foreach my $ref_node (@$ref_list) {
            $tst_node->add_aligned_node( $ref_node, 'monolingual');
        }
    }
}

sub _align_diff_tokenized {
    my ($self, $tst_node, $ref_node, $tst_rest, $ref_rest) = @_;

    my @tst_diff_toks = ($tst_node);
    my @ref_diff_toks = ($ref_node);

    my $tst_diff_len = length $tst_node->form;
    my $ref_diff_len = length $ref_node->form;

    $tst_node = shift @$tst_rest;
    $ref_node = shift @$ref_rest;
    
    while ($tst_node && $ref_node && ($tst_node->form ne $ref_node->form)) {
        if ($tst_diff_len > $ref_diff_len) {
            $ref_diff_len += length $ref_node->form;
            push @ref_diff_toks, $ref_node;
            $ref_node = shift @$ref_rest;
        } else {
            $tst_diff_len += length $tst_node->form;
            push @tst_diff_toks, $tst_node;
            $tst_node = shift @$tst_rest;
        }
    }

    if (!$tst_node && $ref_node) {
        push @ref_diff_toks, ($ref_node, @$ref_rest);
    }
    if (!$ref_node && $tst_node) {
        push @tst_diff_toks, ($tst_node, @$tst_rest);
    }

    $self->_align_asymmetry( \@tst_diff_toks, \@ref_diff_toks );
    if ($tst_node && $ref_node) {
        $tst_node->add_aligned_node( $ref_node, 'monolingual' );
    }
}

sub process_zone {

    my ( $self, $tst_zone ) = @_;
    my $ref_zone = $tst_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @tst_nodes = $tst_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_nodes = $ref_zone->get_atree->get_descendants( { ordered => 1 } );

    my $tst_i = 0;
    my $ref_i = 0;

    while (@tst_nodes && @ref_nodes) {
        my $tst_node = shift @tst_nodes;
        my $ref_node = shift @ref_nodes;
        
        if ($tst_node->form eq $ref_node->form) {
            $tst_node->add_aligned_node( $ref_node, 'monolingual' );
        }
        else {
            $self->_align_diff_tokenized( $tst_node, $ref_node, \@tst_nodes, \@ref_nodes );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::A::AlignSameSentence

=head1 DESCRIPTION

Alignment of two analytical parses of the same sentence (i.e. containing the same list of tokens).
A situation, when the sentences are tokenized in a different way, is fixed in a greedy way - it is
searched for a first identical word pair and the words in differently tokenized chunks are aligned
with each other. This can lead to quadratic time complexity (instead of linear) if the "same"
sentences are totally different.
However, in such situations L<Treex::Block::Align::A::MonolingualGreedy> might be better and faster.

=head1 PARAMETERS

=item C<language>

The current language. This parameter is required.

=item C<to_language>

The target (reference) language for the alignment. Defaults to current C<language> setting. 
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.

=item C<to_selector>

The target (reference) selector for the alignment. Defaults to current C<selector> setting.
The C<to_language> and C<to_selector> must differ from C<language> and C<selector>.


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
