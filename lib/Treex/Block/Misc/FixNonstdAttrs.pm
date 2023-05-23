package Treex::Block::Misc::FixNonstdAttrs;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub _copy_nonstd_to_std {
    my ($self, $obj, $nonstd_name, $std_name) = @_;
    my $std_val = $obj->{$std_name};
    my $nonstd_val = $obj->{$nonstd_name};
    if (!defined $std_val && defined $nonstd_val) {
        $obj->{$std_name} = $nonstd_val;
    }
}

sub process_tnode {
    my ($self, $tnode) = @_;

    foreach my $parent_attr_name (qw/coref_text bridging/) {
        my $parent_attr_list = $tnode->get_attr($parent_attr_name);
        next if !$parent_attr_list;
        foreach my $item (@$parent_attr_list) {
            $self->_copy_nonstd_to_std($item, "target-node.rf", "target_node.rf");
            $self->_copy_nonstd_to_std($item, "informal-type", "type");
        }
    }
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::FixNonstdAttrs - copies values of the non-standard attributes to the attributes accessible by Treex API

=head1 DESCRIPTION

During the second stage of coreference and anaphora annotation in PDT, a schema with slightly changed non-standard names of attributes was used.
This block ensures that if a PDT file with these attributes defined are loaded, they are copied to their standard version accessible by Treex API.

It concerns the following attributes:

Non-standard name            Standard name
----------------------------------------------------------
coref_text/target-node.rf    coref_text/target_node.rf
coref_text/informal-type     coref_text/type
bridging/target-node.rf      bridging/target_node.rf
bridging/informal-type       bridging/type
