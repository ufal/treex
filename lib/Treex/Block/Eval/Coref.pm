package Treex::Block::Eval::Coref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::CS::PronAnaphFilter;

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text all/] ),
    required    => 1,
    default     => 'all',
);

has 'anaphor_type' => (
    is          => 'ro',
    isa         => enum( [qw/pron all/] ),
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
    isa         => 'Maybe[Treex::Tool::Coreference::AnaphFilter]',
    builder     => '_build_anaph_cands_filter',
);

my $tp_count  = 0;
my $src_count = 0;
my $ref_count = 0;

my %same_as_ref;

sub BUILD {
    my ($self) = @_;

    $self->_anaph_cands_filter;
}

sub _build_anaph_cands_filter {
    my ($self) = @_;
    
    if ($self->anaphor_type eq 'pron') {
        return Treex::Tool::Coreference::CS::PronAnaphFilter->new();
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

sub process_tnode {
    my ( $self, $ref_node ) = @_;
    
    my $af = $self->_anaph_cands_filter;
    if (!defined $af || $af->is_candidate( $ref_node )) {

        my $src_node = $ref_node->src_tnode;

        my @ref_antec;
        my @src_antec;
        if ($self->type eq 'gram') {
            @ref_antec = $ref_node->get_coref_gram_nodes;
            @src_antec = $src_node->get_coref_gram_nodes;
        }
        elsif ($self->type eq 'text') {
            @ref_antec = $ref_node->get_coref_chain;
            @src_antec = $src_node->get_coref_text_nodes;
        }
        else {
            # TODO both types of coreference
            return log_fatal "Evaluation of both types of coreference not yet implemented";
        }

        my @ref_antec_in_src = map { $_->src_tnode } @ref_antec;

        foreach my $ref_ante (@ref_antec_in_src) {
            $tp_count += () = grep { $_ == $ref_ante } @src_antec;
        }
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
}

1;

=over

=item Treex::Block::Eval::Coref

Precision, recall and F-measure for coreference.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
