package Treex::Block::SemevalABSA::BaseRule;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub mark_node {
    my ( $self, $node, $str ) = @_;
    $node->wild->{absa_rules} = join(" ", $str, $node->wild->{absa_rules});

    return 1;
}

sub is_aspect_candidate {
    my ( $self, $node ) = @_;
    return defined($node->wild->{absa_rules}) && length($node->wild->{absa_rules}) > 0;
}

sub is_subjective {
    my ( $self, $node ) = @_;
    return defined $node->{wild}->{absa_is_subjective};
}

sub get_polarity {
    my ( $self, $node ) = @_;
    if ( ! $node->{wild}->{absa_polarity} ) {
        log_fatal "Node not marked with polarity: " . $node->get_attr('id');
    }
    return $node->{wild}->{absa_polarity};
}

sub get_alayer_mapper {
    my ( $self, $ttree ) = @_;
    my $doc = $ttree->get_document;
    my %links;
    my @nodes = $ttree->get_descendants;
    for my $node (@nodes) {
        my $linkedid = $node->get_attr("a/lex.rf");
        if ( $linkedid ) {
            my $linkednode = $doc->get_node_by_id( $linkedid );
            $links{$node->get_attr('id')} = $linkednode;
        }
    }

    return sub {
        my ( $node ) = @_;
        return $links{$node->get_attr('id')};
    }
}

sub get_aspect_candidate_polarities {
    my ( $self, $node ) = @_;

    log_fatal "Not an aspect candidate" if ! $self->is_aspect_candidate( $node );

    my @polarities;
    my @rules = split / /, $node->wild->{absa_rules};
    for my $rule (@rules) {
        if ($rule =~ m/(\+|\-|0|conflict)$/) {
            push @polarities, $1;
        }    
    }

    return @polarities;
}

sub combine_polarities {
    my ( $self, @values ) = @_;

    return 0 if ! @values;

    my ($neut, $pos, $neg, $con) = qw/ 0 0 0 0 /;
    for my $val (@values) {
        if ($val eq '+') {
            $pos++;
        } elsif ($val eq '-') {
            $neg++;
        } elsif ($val eq '0') {
            $neut++;
        } elsif ($val eq 'conflict') {
            $con++;
        } else {
            log_fatal "Invalid polarity value: " . $val;
        }
    }

    if ($con || ($pos && $neg)) {
        return 'conflict';
    } elsif ($pos) {
        return '+';
    } elsif ($neg) {
        return '-';
    } else {
        return '0';
    }
}

sub get_clause_descendants {
    my ( $self, $node ) = @_;
    my $clause = $node->get_clause_number;
    my @out = grep { $_->get_clause_number == $clause } $node->get_descendants;
    return @out;
}

sub find_predicate {
    my ( $self, $node ) = @_;

    my $parent = $node;
    my $clause = $node->get_clause_number;

    while ($parent->functor ne 'PRED') {
        if ($parent->is_root) {
            log_warn "Root node reached, predicate not found for node: " . $node->get_attr('id');
            return undef;
        } elsif ($parent->get_clause_number != $clause) {
            log_warn "Escaped current clause, predicate not found for node: " . $node->get_attr('id');
            return undef;
        }
        $parent = $parent->get_parent;
    }

    return $parent;
}

1;
