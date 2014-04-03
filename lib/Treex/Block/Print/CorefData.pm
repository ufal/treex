package Treex::Block::Print::CorefData;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::ValueTransformer;
use Treex::Tool::ML::TabSpace::Util;
use List::Util;

extends 'Treex::Block::Write::BaseTextWriter';

#has 'unsupervised' => (
#    is          => 'ro',
#    required    => 1,
#    isa         => 'Bool',
#    default     => 0,
#);
#
#has 'format' => (
#    is          => 'ro',
#    required    => 1,
#    isa         => enum([qw/percep unsup/]),
#    default     => 'percep',
#);
#
#has 'y_feat_name' => (
#    is          => 'ro',
#    required    => 1,
#    isa         => 'Str',
#    default     => 'class',
#);
#
#has 'feature_sep' => (
#    is          => 'ro',
#    required    => 1,
#    isa         => 'Str',
#    default     => ' ',
#);
#
has 'anaphor_as_candidate' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Bool',
    default     => 1,
    documentation => 'joint anaphoricity determination and antecedent selection',
);

#has '_feature_transformer' => (
#    is          => 'ro',
#    required    => 1,
#    isa         => 'Treex::Tool::Coreference::ValueTransformer',
#    default     => sub{ Treex::Tool::Coreference::ValueTransformer->new },
#);
#
has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
# TODO this should be a role, not a concrete class
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefFeatures',
    builder     => '_build_feature_extractor',
);

has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    lazy        => 1,
    builder     => '_build_ante_cands_selector',
);

has '_anaph_cands_filter' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::NodeFilter',
    builder     => '_build_anaph_cands_filter',
);

sub BUILD {
    my ($self) = @_;
    $self->_ante_cands_selector;
}

sub _build_feature_extractor {
    my ($self) = @_;
    return log_fatal "method _build_feature_extractor must be overriden in " . ref($self);
}
sub _build_ante_cands_selector {
    my ($self) = @_;
    return log_fatal "method _build_ante_cands_selector must be overriden in " . ref($self);
}
sub _build_anaph_cands_filter {
    my ($self) = @_;
    return log_fatal "method _build_anaph_cands_filter must be overriden in " . ref($self);
}

#sub _create_instance_string {
#    my ($self, $instance, $names, $y_value) = @_;
#    
#    my $line = "";
#
#    # DEBUG
#    #$line .= $instance->{cand_id} . $self->feature_sep;
#
#
#    if (defined $y_value) {
#        if ($self->format ne 'unsup') {
#            $line .= $self->y_feat_name . '=';
#        }
#        $line .= $y_value . $self->feature_sep;
#    }
#    #my $line = $self->y_feat_name . '=' . $y_value . $self->feature_sep;
#
#    #use Data::Dumper;
#    #print STDERR Dumper($names);
#    #print STDERR Dumper($instance);
#
#    #my @cols = ();
#    #foreach my $name (@$names) {
#    #    my $col = "";
#    #    if ($name =~ /^[br]_/) {
#    #        if ($self->format ne 'unsup') {
#    #            $col .= "r_$name=";
#    #        }
#    #        $col .= $self->_feature_transformer->replace_empty( $instance->{$name} );
#    #    }
#    #    else {
#    #        if ($self->format ne 'unsup') {
#    #            $col .= "c_$name=";
#    #        }
#    #        $col .= $self->_feature_transformer->special_chars_off( $instance->{$name} )
#    #    }
#    #}
#
#    my @cols = map {
#        if ($_ =~ /_id$/) {
#            (($self->format ne 'unsup') ? "$_=" : "") . $instance->{$_};
#        } else {
#            $_=~ /^[br]_/ 
#                ? (($self->format ne 'unsup') ? "r_$_=" : "") 
#                    . $self->_feature_transformer->replace_empty( $instance->{$_} )
#                : (($self->format ne 'unsup') ? "c_$_=" : "") 
#                    . $self->_feature_transformer->special_chars_off( $instance->{$_} )
#        }
#    } @{$names};
#    $line .= join $self->feature_sep, @cols;
#    return $line;
#}

#sub _sort_instances {
#    my ($self, $instances, $cand_list) = @_;
#
#    my @sorted = map {$instances->{$_->id}} @{$cand_list};
#    return \@sorted;
#}
#
#sub _print_bundle {
#    my ($self, $anaph_id, @lines) = @_;
#
#    print "\n";
#    print '#' . $anaph_id . "\n";
#    print join "\n", @lines;
#    print "\n";
#}
#
#sub _create_lines_unsup_format {
#    my ($self, $anaph, $cands) = @_;
#
#    my $fe = $self->_feature_extractor;
#    my $insts = $fe->create_instances( $anaph, $cands );
#
#    my @lines = ();
#    push @lines,
#        $self->_create_instance_string( $insts->{'anaph'}, $fe->anaph_feature_names );
#    my $cand_insts = $self->_sort_instances( $insts->{'cands'}, $cands );
#    push @lines,
#        map {$self->_create_instance_string( $_, $fe->nonanaph_feature_names )} @$cand_insts;
#    return @lines;
#}
#
#sub _create_lines_percep_format {
#    my ($self, $anaph, $cands, $y_value, $ords) = @_;
#
#    my $fe = $self->_feature_extractor;
#    my $insts = $fe->create_instances( $anaph, $cands, $ords );
#
#    my @lines = ();
#    my $cand_insts = $self->_sort_instances( $insts, $cands );
#    push @lines,
#        map {$self->_create_instance_string( $_, $fe->feature_names, $y_value )} @$cand_insts;
#    return @lines;
#}
#
#sub _create_lines_reranker_format {
#    my ($self, $anaph, $cands, $y_value, $ords) = @_;
#
#    my $fe = $self->_feature_extractor;
#    my $insts = $fe->create_instances( $anaph, $cands, $ords );
#
#    my @lines = ();
#    my $cand_insts = $self->_sort_instances( $insts, $cands );
#    foreach my $cand_inst ( @$cand_insts ) {
#        my @fe_names = @{$fe->feature_names};
#        foreach my $name ( keys %{$cand_inst} ) {
#            if ( not grep { $_ eq $name } @fe_names ) {
#                push @fe_names, $name;
#            }
#        }
#        push @lines, $self->_create_instance_string( $cand_inst, \@fe_names, $y_value );
#    }
#    
#    return @lines;
#}

sub is_text_coref {
    my ($anaph, @cands) = @_;
    
    my @antecs = $anaph->get_coref_chain;
    push @antecs, map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $_->children : () } @antecs;

    # if no antecedent, insert itself and if anaphor as candidate is on, it will be marked positive
    if (!@antecs) {
        push @antecs, $anaph;
    }

    my %antes_hash = map {$_->id => $_} @antecs;

    my @relat_idx = grep {defined $antes_hash{$cands[$_]->id}} 0 .. $#cands;
    return @relat_idx;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    # If we identify anaphors seperately
    #my @antes = $t_node->get_coref_text_nodes;
    #if ( (@antes > 0) && $self->_anaph_cands_filter->is_candidate( $t_node ) ) {
    
    if ( $self->_anaph_cands_filter->is_candidate( $t_node ) ) {
            
        my $acs = $self->_ante_cands_selector;
        my $fe = $self->_feature_extractor;

#        if ($self->unsupervised) {
#            my $cands = $acs->get_candidates( $t_node );
#
#            if (@$cands > 0) {
#                my @lines = ();
#                if ($self->format eq 'unsup') {
#                    @lines = $self->_create_lines_unsup_format( $t_node, $cands );
#                }
#                else {
#                    @lines = $self->_create_lines_reranker_format( $t_node, $cands );
##                     @lines = $self->_create_lines_percep_format( $t_node, $cands );
#                }
#                $self->_print_bundle( $t_node->id, @lines );
#            }
#        }
#        else {

        my @cands = $acs->get_candidates($t_node);
        my @coref_idx = is_text_coref($t_node, @cands);

        if (@coref_idx) {
            my $feats = $self->_feature_extractor->create_instances($t_node, \@cands);
            my $instance_str = Treex::Tool::ML::TabSpace::Util::format_multiline($feats, \@coref_idx);

            print {$self->_file_handle} $instance_str;
        }

#            # retrieve positive and negatve antecedent candidates separated from
#            # each other
#            #my ($pos_cands, $neg_cands, $pos_ords, $neg_ords) 
#            #    = $acs->get_pos_neg_candidates( $t_node );
#                
#            if ( @{$pos_cands} > 0 and defined $pos_cands->[0] ) {
#                my @defined_neg_cands = grep { defined $_ } @{$neg_cands};
#                my @pos_lines = $self->_create_lines_reranker_format( $t_node, $pos_cands, 1, $pos_ords );
#                my @neg_lines = $self->_create_lines_reranker_format( $t_node, \@defined_neg_cands, 0, $neg_ords );
##                 my @neg_lines = $self->_create_lines_reranker_format( $t_node, $neg_cands, 0, $neg_ords );
#    #             my @pos_lines = $self->_create_lines_percep_format( $t_node, $pos_cands, 1, $pos_ords );
#    #             my @neg_lines = $self->_create_lines_percep_format( $t_node, $neg_cands, 0, $neg_ords );
#
#    # TODO negative instances appeared to be of 0 size, why?
#                if (@pos_lines > 0) {
#                    $self->_print_bundle( $t_node->id, (@pos_lines, @neg_lines) );
#                }
#            }

#        }
    }
}

1;
