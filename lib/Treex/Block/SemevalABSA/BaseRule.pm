package Treex::Block::SemevalABSA::BaseRule;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub mark_node {
    my ( $node, $str ) = @_;
    $node->wild->{absa_rules} = join(" ", $str, $node->wild->{absa_rules});

    return 1;
}

sub is_aspect {
    my ( $node ) = @_;
    return defined $node->{wild}->{absa_is_aspect};
}

sub is_subjective {
    my ( $node ) = @_;
    return defined $node->{wild}->{absa_is_subjective};
}

sub get_polarity {
    my ( $node ) = @_;
    if ( ! $node->{wild}->{absa_polarity} ) {
        log_fatal "Node not marked with polarity: " . $node->get_attr('id');
    }
    return $node->{wild}->{absa_polarity};
}

sub get_alayer_mapper {
    my ( $ttree ) = @_;
    my $doc = $ttree->get_document;
    my %links;
    my @nodes = $ttree->get_descendants;
    for my $node (@nodes) {
        my $linkednode = $doc->get_node_by_id( $tnode->get_attr("a/lex.rf") );
        $links{$node->get_attr('id')} = $linkednode;
    }

    return sub {
        my ( $node ) = @_;
        return $links{$node->get_attr('id')};
    }
}

1;
