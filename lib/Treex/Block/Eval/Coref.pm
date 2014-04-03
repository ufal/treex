package Treex::Block::Eval::Coref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::CS::PronAnaphFilter;
use Treex::Tool::Coreference::EN::PronAnaphFilter;
use Treex::Tool::Coreference::CS::RelPronAnaphFilter;

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text all/] ),
    required    => 1,
    default     => 'all',
);

has 'anaphor_type' => (
    is          => 'ro',
    isa         => enum( [qw/pron rel all/] ),
    required    => 1,
    default     => 'all',
);

has 'just_counts' => (
    is          => 'ro',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

has '_anaph_cands_filter' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Maybe[Treex::Tool::Coreference::NodeFilter]',
    builder     => '_build_anaph_cands_filter',
    lazy        => 1,
);

my $tp_count  = 0;
my $src_count = 0;
my $ref_count = 0;

my %same_as_ref;
    
    # DEBUG
    my $IS_GEN = 0;
    my $REF_MISS = 0;
    my $GEN_MISS = 0;
    my $GEN_OTHER = 0;
    my $GEN_OK = 0;

sub BUILD {
    my ($self) = @_;

    $self->_anaph_cands_filter;
}

sub _build_anaph_cands_filter {
    my ($self) = @_;
    
    if ($self->anaphor_type eq 'pron') {
        if ($self->language eq 'cs') {
            return Treex::Tool::Coreference::CS::PronAnaphFilter->new();
        }
        elsif ($self->language eq 'en') {
            return Treex::Tool::Coreference::EN::PronAnaphFilter->new();
        }
        else {
            return log_fatal "language " . $self->language . " is not supported";
        }
    }
    elsif ($self->anaphor_type eq 'rel') {
        if ($self->language eq 'cs') {
            return Treex::Tool::Coreference::CS::RelPronAnaphFilter->new();
        }
    }
    return undef;
}

sub _count_fscore {
    my ( $eq, $src, $ref ) = @_;

    my $prec = $src != 0 ? $eq / $src : 0;
    my $reca = $ref != 0 ? $eq / $ref : 0;
    my $fsco = ( $prec + $reca ) != 0 ? 2 * $prec * $reca / ( $prec + $reca ) : 0;

    return ( $prec, $reca, $fsco );
}

sub _get_corresponding_node {
    my ($self, $ref_node) = @_;

    my $src_node = $ref_node->src_tnode;
    if (!defined $src_node) {
        my ($aligned, $types) = $ref_node->get_aligned_nodes;
        $src_node = $aligned->[0];
        if (@$aligned > 1) {
            print STDERR "MORE THAN ONE ALIGNED NODE: ". $ref_node->id. " -> " .(join ", ", (map {$_->id} @$aligned)). "\n";
        }
    }
    return $src_node;
}

sub process_tnode {
    my ( $self, $ref_node ) = @_;
    
    my $af = $self->_anaph_cands_filter;
    if (!defined $af || $af->is_candidate( $ref_node )) {
        
        my $src_node = $self->_get_corresponding_node( $ref_node );
        
#        print STDERR "SOMTU\n";
        
        $IS_GEN += $ref_node->is_generated ? 1 : 0;
        $REF_MISS += !defined $src_node ? 1 : 0;
        #if (!defined $src_node) {
        #    print STDERR "ID: " . $ref_node->id . ", " . $ref_node->get_bundle->get_position . "\n";
        #}

        my @ref_antec;
        my @src_antec;
        if ($self->type eq 'gram') {
            @ref_antec = $ref_node->get_coref_gram_nodes;
            @src_antec = $src_node ? $src_node->get_coref_gram_nodes : ();
        }
        elsif ($self->type eq 'text') {
            @ref_antec = $ref_node->get_coref_chain;
            @src_antec = (defined $src_node) ? $src_node->get_coref_text_nodes : ();
        }
        else {
            # TODO both types of coreference
            return log_fatal "Evaluation of both types of coreference not yet implemented";
        }
        $GEN_MISS += ($ref_node->is_generated && (@ref_antec > 0) && !defined $src_node) ? 1 : 0;

        my @ref_antec_in_src = map { $self->_get_corresponding_node( $_ ) } @ref_antec;

        my $tp_node_count = 0;
        foreach my $ref_ante (@ref_antec_in_src) {
            next if (!defined $ref_ante);
            my @agree = grep { $_ == $ref_ante } @src_antec;
            $tp_node_count += scalar @agree;
            if (scalar @agree > 0) {
                $GEN_OK += (defined $src_node && $ref_node->is_generated) ? 1 : 0;
            } else {
                $GEN_OTHER += (defined $src_node && $ref_node->is_generated) ? 1 : 0;
            }
        }
        $tp_count += $tp_node_count;
        $src_count += scalar @src_antec;
        if ($self->type eq 'text') {
            my @direct_antec = $ref_node->get_coref_text_nodes;
            $ref_count += (@direct_antec > 0) ? 1 : 0;
        }
        else {
            $ref_count += scalar @ref_antec;
        }
    }

        
# DEBUG
#    if (@ref_antec > 0) {
#        print "TRUE ANAPH: " . $src_node->id . "; ";
#        print "TRUE ANTE: " . (join ", ", (map {$_->id} @ref_antec_in_src)) . "; ";
#    }
#    if (@src_antec > 0) {
#        print "PRED ANAPH: " . $src_node->id . "; ";
#        print "PRED ANTE: " . (join ", ", (map {$_->id} @src_antec)) . "; ";
#    }
#    if ((@ref_antec > 0) || (@src_antec > 0)) {
#        print "\n";
#    }
}

sub process_end {
    my ($self) = shift;

    my ( $prec, $reca, $fsco ) =
        _count_fscore( $tp_count, $src_count, $ref_count );

    if ($self->just_counts) {
        print join "\t", ($tp_count, $src_count, $ref_count);
        print "\n";
    }
    else {
        printf "P: %.2f%% (%d / %d)\t", $prec * 100, $tp_count, $src_count;
        printf "R: %.2f%% (%d / %d)\t", $reca * 100, $tp_count, $ref_count;
        printf "F: %.2f%%\n",           $fsco * 100;
    }
# DEBUG
    print STDERR "IS_GEN: $IS_GEN, REF_MISS: $REF_MISS, GEN_MISS: $GEN_MISS, GEN_OTHER: $GEN_OTHER, GEN_OK: $GEN_OK\n";
}

1;

=over

=item Treex::Block::Eval::Coref

Precision, recall and F-measure for coreference.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
