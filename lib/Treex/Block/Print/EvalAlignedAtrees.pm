package Treex::Block::Print::EvalAlignedAtrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has report_errors => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print addresses of errors (max one node per sentence)',
);

my %wrong_sentences;
my $all_nodes = 0;
my $err_nodes = 0;

sub process_anode {
    my ( $self, $node, $bundleNo ) = @_;
    $all_nodes++;
    my ($n) = $node->get_directed_aligned_nodes;
    log_fatal 'Node ' . $node->get_address . ' has no aligned nodes' if !$n;
    my ($a) = @$n;
    return if $node->get_parent->is_root && $a->get_parent->is_root;
    return $self->report_error( $node, $bundleNo ) if $node->get_parent->is_root || $a->get_parent->is_root;

    my ($pn) = $node->get_parent->get_directed_aligned_nodes;
    return $self->report_error( $node, $bundleNo ) if !$pn;
    my ($pa) = @$pn;
    return $self->report_error( $node, $bundleNo ) if $a->parent != $pa;
    return;
}

after process_document => sub {
    my ( $self, $document ) = @_;
    my $err_sentences = keys %wrong_sentences;
    my $all_sentences = $document->get_bundles();
    my $score         = 1 - ( $err_nodes / $all_nodes );
    my $docname       = $document->full_filename();
    say { $self->_file_handle } "file=$docname"
        . " err_sentences=$err_sentences all_sentences=$all_sentences"
        . " err_nodes=$err_nodes all_nodes=$all_nodes UAS=$score";

    # clear the statistics
    %wrong_sentences = ();
    ( $err_nodes, $all_nodes ) = ( 0, 0 );
};

sub report_error {
    my ( $self, $node, $bundleNo ) = @_;
    $err_nodes++;
    return if $wrong_sentences{$bundleNo};
    say { $self->_file_handle } $node->get_address if $self->report_errors;
    $wrong_sentences{$bundleNo} = 1;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::EvalAlignedAtrees - print UAS etc.


=head1 DESCRIPTION

Prints statistics needed to compute unlabeled attachment score (UAS)
of aligned dependency trees.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
