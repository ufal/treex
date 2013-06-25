####################################
# This block is not ready to use!  #
####################################
# TODO: It does not fill links from n-nodes to a-nodes.
# TODO: It seems to have lower accuracy than the original 2008 version
# SCzechM_to_SCzechN::SVM_ne_recognizer ($TMT_ROOT/libs/blocks/SCzechM_to_SCzechN/SVM_ne_recognizer.pm)
package Treex::Block::A2N::CS::SvmNer;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Algorithm::SVM;
use Algorithm::SVM::DataSet;
use NER::SVM_Czech::CzechNamedEntitiesCommon;

my ($svm, $twoword_svm,  $threeword_svm);

# load the models
sub BUILD {
    $svm = Algorithm::SVM->new( Model => $SVM_MODEL_DIR.$ONEWORD_MODEL_FILENAME );
    $twoword_svm = Algorithm::SVM->new( Model => $SVM_MODEL_DIR.$TWOWORD_MODEL_FILENAME );
    $threeword_svm = Algorithm::SVM->new( Model => $SVM_MODEL_DIR.$THREEWORD_MODEL_FILENAME );
}

# Global data structures
our %entities = ();             # already existing named entities, nasty global variable
our $MRF_DELIM = '.';

# Simple rule based classifier
# Used after SVM to post-edit classification for oneword NE
sub _rule_classifier($) {
    my $lemma = shift;
    if ( $lemma =~ /_;G/ ) {
        return "g_";
    }
    if ( $lemma =~ /_;Y/ ) {
        return "pf";
    }
    if ( $lemma =~ /_;S/ ) {
        return "ps";
    }
    if ( $lemma =~ /_;E/ ) {
        return "pc";
    }
    return "x";
}

# Creates new node in SCzechN tree connected to n_root
# with given classification
# Third parameter is an array of SCzechM tree nodes,
# whose m.rf's correspond to named entity.
sub _create_n_node($$@) {
    my ( $n_root, $classification, @m_nodes ) = @_;
    return if @m_nodes == 0;    # empty entity

    # Check if this entity already exists
    my @m_ids = sort map{ $_->id } @m_nodes;
    my $m_ids_label = join $MRF_DELIM, @m_ids;
    return if exists $entities{$m_ids_label} && $entities{$m_ids_label}->get_attr('ne_type') eq $classification;

    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr( 'ne_type', $classification );

    # Set m.rf's
    $n_node->set_deref_attr('m.rf', \@m_nodes);

    # Set normalized name
    my $normalized_name;
    foreach my $m_node (@m_nodes) {
        my $act_normalized_name = $m_node->lemma;
        $act_normalized_name =~ s/[-_].*//;
        $normalized_name .= " " . $act_normalized_name;
    }
    $normalized_name =~ s/^ //;
    $n_node->set_attr( 'normalized_name', $normalized_name );

    # Remember this named entity
    $entities{$m_ids_label} = $n_node;

    # print STDERR ( "Named entity \"$classification\" found: " . $n_node->get_attr('normalized_name') . "\n" );
    return $n_node;
}

sub _create_n_container($$$$) {
    my ( $n_root, $classification, $m_nodes_ref, $m_ids_ref ) = @_;
    return if @{$m_ids_ref} == 0 || @{$m_nodes_ref} == 0; # empty container

    # Check if this container already exists
    my $m_ids_label = join $MRF_DELIM, sort @{$m_ids_ref};
    return if exists $entities{$m_ids_label} && $entities{$m_ids_label}->get_attr('ne_type') eq $classification;

    # Get corresponding n-nodes
    my @n_nodes = map $entities{$_}, @{$m_ids_ref};

    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr('ne_type', $classification);

    # Set m.rf's
    $n_node->set_deref_attr('m.rf', $m_nodes_ref );

    # Set normalized name
    my $normalized_name;
    foreach my $n(@n_nodes) {
        $normalized_name .= " ". $n->get_attr('normalized_name') if $n->get_attr('normalized_name');
    }
    $n_node->set_attr('normalized_name', $normalized_name);

    # Remember this container
    $entities{$m_ids_label} = $n_node;

#    print STDERR ( "Named entity container \"$classification\" found: ". $n_node->get_attr('normalized_name')."\n");
    return $n_node;
}

# Reads already existing named entities in SCzechN tree into memory
# to prevent overwriting them
# Adding a function prototype to suppress warning
sub _read_named_entities($);
sub _read_named_entities($) {
    my ($n_node) = @_;
    return if not $n_node;

    # leaf
    if (! $n_node->get_children) {
        my $m_nodes_ref = $n_node->get_deref_attr('m.rf');
        if ($m_nodes_ref) {
            my @m_ids = sort map $_->id, @{$m_nodes_ref};
            $entities{join $MRF_DELIM, @m_ids} = $n_node if $n_node->get_attr("ne_type");
            return @m_ids;
        }
    }

    # internal node
    my @m_ids = sort map(_read_named_entities($_), $n_node->get_children);
    $entities{join '.', @m_ids} = $n_node if $n_node->get_attr('ne_type');
    return @m_ids;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    %entities = (); # no need to remember entities across sentences
    my $n_root = $zone;
    my @m_nodes = $zone->get_atree->get_descendants({ordered=>1});

    if ($zone->has_ntree) {
        $n_root = $zone->get_ntree;
        _read_named_entities($n_root);
    }
    else {
        $n_root = $zone->create_ntree;
    }

    # Iterate through a-nodes
  MNODE:
    for ( my $i = 0; $i <= $#m_nodes; $i++ ) {
        my ( $pprev_m_node, $prev_m_node, $m_node, $next_m_node, $nnext_m_node ) =
            ( $m_nodes[ $i - 2 ], $m_nodes[ $i - 1 ], $m_nodes[$i], $m_nodes[ $i + 1 ], $m_nodes[ $i + 2 ] );

        ### Threeword named entities ###

        if ( $i >= 2 ) {

            # Extract classification features for threeword entities
            my %threeword_args;
            $threeword_args{'first_form'} = $pprev_m_node->form();
            $threeword_args{'first_lemma'} = $pprev_m_node->lemma();
            $threeword_args{'first_tag'} = $pprev_m_node->tag();

            $threeword_args{'second_form'} = $prev_m_node->form;
            $threeword_args{'second_lemma'} = $prev_m_node->lemma;
            $threeword_args{'second_tag'} = $prev_m_node->tag;

            $threeword_args{'third_form'} = $m_node->form;
            $threeword_args{'third_lemma'} = $m_node->lemma;
            $threeword_args{'third_tag'} = $m_node->tag;

            my @threeword_features = extract_threeword_features(%threeword_args);

            # Classify threeword entity using SVM classifier
            my $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@threeword_features );
            my $classification = int2str( $threeword_svm->predict($data) );

            # Save threeword named entity to CzechN three
            if ($classification ne 'x') {
                my $n_node = _create_n_node( $n_root, $classification, $pprev_m_node, $prev_m_node, $m_node);
                if ( $classification eq 'gu' ) {
                    $i += 2;
                    next MNODE;
                }
            }
        }

        ### Twoword named entities ###

        if ( $i >= 1 ) { # only makes sense when we have already two nodes

            # Extract classification features for twoword entities
            my %twoword_args;

            $twoword_args{'prev_form'}      = defined $pprev_m_node ? $pprev_m_node->form : $FALLBACK_LEMMA;
            $twoword_args{'prev_lemma'}     = defined $pprev_m_node ? $pprev_m_node->lemma : $FALLBACK_LEMMA;
            $twoword_args{'prev_tag'}       = defined $pprev_m_node ? $pprev_m_node->tag : $FALLBACK_TAG;

            $twoword_args{'first_form'}     = $prev_m_node->form;
            $twoword_args{'first_lemma'}    = $prev_m_node->lemma;
            $twoword_args{'first_tag'}      = $prev_m_node->tag;

            $twoword_args{'second_form'}    = $m_node->form;
            $twoword_args{'second_lemma'}   = $m_node->lemma;
            $twoword_args{'second_tag'}     = $m_node->tag;

            $twoword_args{'next_lemma'}     = defined $next_m_node ? $next_m_node->lemma : $FALLBACK_LEMMA;

            my @twoword_features = extract_twoword_features(%twoword_args);

            # Classify twoword entity using SVM classifier
            my $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@twoword_features );
            my $classification = int2str( $twoword_svm->predict($data) );

            # Save twoword named entity to CzechN tree
            if ($classification ne 'x') { # twoword entity found
                _create_n_node( $n_root, $classification, $prev_m_node, $m_node);
                if ( $classification eq 'gu' ) {
                    $i += 1;
                    next MNODE;
                }
            }
        }

        ### Oneword named entitites

        # Extract features for oneword entities
        my %args;
        $args{'act_form'}   = $m_node->form;
        $args{'act_lemma'}  = $m_node->lemma;
        $args{'act_tag'}    = $m_node->tag;
        $args{'prev_lemma'} = defined $prev_m_node ? $prev_m_node->lemma : $FALLBACK_LEMMA;
        $args{'prev_tag'} = defined $prev_m_node ? $prev_m_node->tag : $FALLBACK_TAG;
        $args{'pprev_tag'} = defined $pprev_m_node ? $pprev_m_node->tag : $FALLBACK_TAG;
        $args{'next_lemma'} = defined $next_m_node ? $next_m_node->lemma : $FALLBACK_LEMMA;
        my @features = extract_oneword_features(%args);

        # Classify oneword entity using SVM classifier
        my $data =  Algorithm::SVM::DataSet->new( Label => 0, Data => \@features );
        my $classification = int2str( $svm->predict($data) );

        # Post classification using simple rule based classifier
        if ( $classification eq 'x' ) {
            $classification = _rule_classifier($m_node);
        }

        # Save oneword named entity to CzechN tree
        if ( $classification ne 'x' ) {
            _create_n_node( $n_root, $classification, $m_node );
        }
    }                           #MNODE

    # Second iteration - recognize containers
    for my $i (0..$#m_nodes) {

        # Threeword containers
        if ($i > 1) {
            my ($ppid, $pid, $id) = ( $m_nodes[$i - 2]->id, $m_nodes[$i-1]->id, $m_nodes[$i]->id );

            # pf-pm-ps => P
            if (   exists $entities{$ppid} && $entities{$ppid}->get_attr('ne_type') eq 'pf'
                       && exists $entities{$pid} && $entities{$pid}->get_attr('ne_type') eq 'pm'
                           && exists $entities{$id} && $entities{$id}->get_attr('ne_type') eq 'ps'
                       ) {
                _create_n_container( $n_root, 'P',
                                     [$m_nodes[$i-2], $m_nodes[$i-1], $m_nodes[$i]],
                                     [$ppid, $pid, $i] );
            }

            # td-tm => T
            if (   exists $entities{$ppid.$MRF_DELIM.$pid} && $entities{$ppid.$MRF_DELIM.$pid}->get_attr('ne_type') eq 'td'
                       && exists $entities{$id} && $entities{$id}->get_attr('ne_type') eq 'tm'
                   ) {
                _create_n_container( $n_root, 'T',
                                     [$m_nodes[$i-2], $m_nodes[$i-1], $m_nodes[$i]],
                                     [$ppid.$MRF_DELIM.$pid, $id] );
            }
        }

        # Twoword containers
        if ($i > 0) {
            my ($pid, $id) = ( $m_nodes[$i-1]->id, $m_nodes[$i]->id );

            # pf-ps => P
            if (   exists $entities{$pid} && $entities{$pid}->get_attr('ne_type') eq 'pf'
                       && exists $entities{$id} && $entities{$id}->get_attr('ne_type') eq 'ps'
                   ) {
                _create_n_container( $n_root, 'P', [$m_nodes[$i-1], $m_nodes[$i]], [$pid, $id] );
            }
        }
    }

    return;
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::A2N::CS::SvmNer - SVM-based recognizer of named entities in Czech

=head1 DESCRIPTION

Create an n-tree (or use the existing one) and add children corresponding
to Czech named entities found in the sentence, using SVM recognizer.

=head1 AUTHOR

Jana Kravalova <kravalova@ufal.mff.cuni.cz>
Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


