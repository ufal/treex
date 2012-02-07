package Treex::Block::Print::Debug;
use Moose;
use Treex::Core::Common;

use Data::Dumper;

extends 'Treex::Core::Block';

has 'with_traces' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    required => 1,
);

sub process_bundle {
    my ($self, $bundle, $bundle_no) = @_;
    
    my $ref_zone = $bundle->get_zone($self->language, 'ref');
    my $feats_ref_for_id = $self->prepare_features_ref($ref_zone);
    my $ref_sentence = $self->prepare_sentence($ref_zone, $feats_ref_for_id);

    my $tst_zone = $bundle->get_zone($self->language, 'src');
    my $feats_tst_for_id = $self->prepare_features_tst($tst_zone);
    my $tst_sentence = $self->prepare_sentence($tst_zone, $feats_tst_for_id);

    my $doc_name = $bundle->get_document->full_filename;
    $doc_name =~ s{^.*/}{};

    print "ID\t" . $bundle->id . " ($doc_name##$bundle_no)\n";
    print "REF\t$ref_sentence\n";
    print "TST\t$tst_sentence\n";
    print "\n";
}

sub prepare_features_ref {
    my ($self, $nodes) = @_;
    return log_fatal "method prepare_features_ref must be overriden in " . ref($self);
}
sub prepare_features_tst {
    my ($self, $nodes) = @_;
    return log_fatal "method prepare_features_tst must be overriden in " . ref($self);
}

# returns a hash of generated t-nodes indexed by an ord number of the a-node
# to directly precede given generated node in an output sentence
sub _gener_nodes_by_aord {
    my ($self, $t_nodes) = @_;

    my $gener_by_aord = {};

    my $last_aord = -1;
    foreach my $t_node (@$t_nodes) {
        # is_generated == no link to a-layer 
        if ((!defined $t_node->get_lex_anode) && ($t_node->get_aux_anodes == 0)) {
            push @{$gener_by_aord->{$last_aord}}, $t_node;
        } 
        # print a generated node just after all a-nodes corresponding to preceding t-nodes have been printed
        else {
            my ($last) = reverse $t_node->get_anodes({ordered => 1});
            $last_aord = $last->ord;
        }
    }
    return $gener_by_aord;
}

sub _form_token {
    my ($self, $word, $feat) = @_;
    return defined $feat ? "$word/$feat" : $word;
}

sub prepare_sentence {
    my ($self, $zone, $feats_for_id) = @_;

    my @t_nodes = $zone->get_ttree->get_descendants({ordered => 1});
    
    # traces are enabled
    my $gener_by_aord;
    if ($self->with_traces) {
        $gener_by_aord = $self->_gener_nodes_by_aord(\@t_nodes);
    }

    my @tokens = ();

    # print generated nodes that precede all a-nodes (if traces are enabled)
    if (defined $gener_by_aord) {
        foreach my $t_node (@{$gener_by_aord->{-1}}) {
            push @tokens, $self->_form_token($t_node->lemma, $feats_for_id->{$t_node->id});
        }
    }

    my @a_nodes = $zone->get_atree->get_descendants({ordered => 1});
    foreach my $a_node (@a_nodes) {
        my $ord = $a_node->ord;
        # print a-nodes
        push @tokens, $self->_form_token($a_node->form, $feats_for_id->{$a_node->id});
        # print generated nodes (if traces are enabled)
        if (defined $gener_by_aord && defined $gener_by_aord->{$ord}) {
            foreach my $t_node (@{$gener_by_aord->{$ord}}) {
                push @tokens, $self->_form_token($t_node->t_lemma, $feats_for_id->{$t_node->id});
            }
        }
    }
    return (join " ", @tokens);
}

1;

=head1 NAME 

Treex::Block::Print::Debug

=head1 DESCRIPTION

A base class for debugging resolution tasks. It prints out the sentence
(with generated t-nodes as traces) with observed feature concatenated to 
words (after "/"). For each sentence it prints out the gold standard (REF)
as well as the system (TST) result.

=head1 PARAMETERS

=over

=item with_traces

If enabled, it prints out also the nodes generated on the t-layer.
Disabled by default.

=back

=head1 AUTHORS

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
