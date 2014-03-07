package Treex::Block::SemevalABSA::BaseRule;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub mark_node {
    my ( $self, $node, $str ) = @_;
    if ( ! $node ) {
        log_warn "$node is undef";
        return 0;
    }

    my @stopwords = qw/ everyone everybody everything anything anyone anybody thing /;
    my @function_word_tags = ( 'PRP', 'PRP$', 'WP', 'WP$', 'DT', 'PDT', 'IN', 'CC', 'WDT' );
    my @avoided_afuns = ( 'Aux' );

    if ( grep { $node->tag eq $_ } @function_word_tags ) {
        log_info "Tag in the stop-list, not marking node: " . $node->form;
        return 0;
    }

    if ( grep { lc( $node->form ) eq lc( $_ ) } @stopwords ) {
        log_info "Form in the stop-list, not marking node: " . $node->form;
        return 0;
    }

    if ( grep { $node->afun =~ m/^$_/ } @avoided_afuns ) {
        log_info "Afun in the stop-list, not marking node: " . $node->form;
        return 0;
    }

    # my @subtree = $node->get_descendants( { ordered => 1, add_self => 1 } );
    my @subtree = $node->get_children( { ordered => 1, add_self => 1 } );
    my @avoidparents = grep { $self->is_subjective( $_ ) } @subtree;
    @subtree = grep { ! $self->is_subjective( $_ ) } @subtree;
    my $clause = $node->clause_number;
    @subtree = grep { $_->clause_number == $clause } @subtree;
    for my $avoid ( @avoidparents ) {
        @subtree = grep { ! $_->is_descendant_of( $avoid ) } @subtree;
    }

    while ( @subtree && grep { $subtree[0]->tag eq $_ } @function_word_tags ) {
        log_info "shifting initial function word: " . $subtree[0]->form;
        shift @subtree;
    }

    while ( @subtree && grep { $subtree[0]->afun =~ m/^$_/ } @function_word_tags ) {
        log_info "shifting initial function word (afun): " . $subtree[0]->form;
        shift @subtree;
    }

    for my $subnode (@subtree) {
        log_info "Marking node " . $node->form;
        if ($subnode->wild->{absa_rules}) {
            $subnode->wild->{absa_rules} .= " $str";
        } else {
            $subnode->wild->{absa_rules} = $str;
        }
    }

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

sub switch_polarity {
    my ( $self, $polarity ) = @_;
    if ( $polarity eq '+' ) {
        return '-';
    } elsif ( $polarity eq '-') {
        return '+';
    } else {
        return $polarity;
    }
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
            log_warn "Invalid polarity value: " . $val;
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
    my $clause = $node->clause_number;
    my @out = grep { $_->clause_number == $clause } $node->get_descendants;
    return @out;
}

sub find_predicate {
    my ( $self, $node ) = @_;

    my $parent = $node;
    my $clause = $node->clause_number;

    while ($parent->tag =~ m/^VB/) {
        if ($parent->clause_number != $clause) {
            log_warn "Escaped current clause, predicate not found for node: " . $node->id;
            return undef;
        }
        $parent = $parent->get_parent;
        if ($parent->is_root) {
            log_warn "Root node reached, predicate not found for node: " . $node->id;
            return undef;
        }
    }

    return $parent;
}

1;
