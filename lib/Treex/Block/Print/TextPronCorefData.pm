package Treex::Block::Print::TextPronCorefData;

use Moose;
use Treex::Core::Common;

# TODO this is weird, they should rather have a common ancestor class or role
extends 'Treex::Block::A2T::CS::MarkTextPronCoref';

has 'y_feat_name' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 'class',
);

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

has 'feature_sep' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => ' ',
);

has '_char_mapping' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[Str]',
    builder     => '_build_char_mappping',
);

sub BUILD {
    my ($self) = @_;

    $self->feature_names;
}

sub _build_feature_names {
    my ($self) = @_;

    # TODO fill feature names
    my $names = $self->_feature_extractor->feature_names;
    return $names;
}
    
sub _build_char_mappping {
    my ($self) = @_;

    return {
        "\#"    => "spec_hash",
        "\\|"   => "spec_pipe",
        "\\-"   => "undef",
        '\\"'   => "spec_quot",
        "\\+"   => "spec_plus",
        "\\*"   => "spec_aster",
        "\\,"   => "spec_comma",
        "\\."   => "spec_dot",
        "\\!"   => "spec_exmark",
        "\\:"   => "spec_ddot",
        "\\;"   => "spec_semicol",
        "\\="   => "spec_eq",
        "\\?"   => "spec_qmark",
        "\\^"   => "spec_head",
        "\\~"   => "spec_tilda",
        "\\}"   => "spec_rbrace",
        "\\{"   => "spec_lbrace",
        "\\("   => "spec_lpar",
        "\\)"   => "spec_rpar",
        "\\["   => "spec_lpar",
        "\\]"   => "spec_rpar",
        "\\&"   => "spec_amper",
        "\\'"   => "spec_aph",
        "\\`"   => "spec_aph2",
        "\\\""  => "spec_quot",
        "\\%"   => "spec_percnt",
        "\\\\"  => "spec_backslash",
        "\\\/"  => "spec_slash",
        "\\#"   => "spec_cross",
        "\\\$"  => "spec_dollar",
        "\\@"   => "spec_at",
    };
}

sub _special_chars_off {
    my ($self, $value) = @_;

    my $mapping = $self->_char_mapping;

    foreach my $from (keys %{$mapping}) {
		my $to = $mapping->{$from};
        $value = $self->_replace_empty( $value );
        if ($value ne "empty") {
		    $value =~ s/$from/$to/g;
        }
	}
	return $value;
}

sub _replace_empty {
    my ($self, $value) = @_;
    if ((!defined $value) || ($value =~ /^\s*$/)) {
        return "empty";
    }
    return $value;
}

sub _create_instances_strings {
    my ($self, $instances, $y_value) = @_;
    
    my @lines;
    foreach my $instance (@{$instances}) {
        my $line = $self->y_feat_name . '=' . $y_value . $self->feature_sep;
        my @cols = map {$_=~ /^[br]_/ 
                ? "r_$_=" . $self->_replace_empty( $instance->{$_} )
                : "c_$_=" . $self->_special_chars_off( $instance->{$_} )
            } @{$self->feature_names};
        $line .= join $self->feature_sep, @cols;
        push @lines, $line;
    }

    return @lines;
}

sub _sort_instances {
    my ($self, $instances, $cand_list) = @_;

    my @sorted = map {$instances->{$_->id}} @{$cand_list};
    return \@sorted;
}

sub print_bundle {
    my ($self, $anaph, $pos_instances, $neg_instances) = @_;
    
    my @pos_lines = $self->_create_instances_strings($pos_instances, 1);
    my @neg_lines = $self->_create_instances_strings($neg_instances, 0);
    
    print "\n";
    print '#' . $anaph->id . "\n";
    print join "\n", ( @pos_lines, @neg_lines );
    print "\n";
}

override 'process_tnode' => sub {
    my ( $self, $t_node ) = @_;

    return if ( $t_node->is_root );

    my @antes = $t_node->get_coref_text_nodes;

    if ( (@antes > 0) && $self->_is_anaphoric($t_node) ) {

        # retrieve positive and negatve antecedent candidates separated from
        # each other
        my $acs = $self->_ante_cands_selector;
        my ($pos_cands, $neg_cands, $pos_ords, $neg_ords) 
            = $acs->get_pos_neg_candidates( $t_node );

        # instances is a reference to a hash in the form { id => instance }
        my $pos_instances 
            = $self->_create_instances( $t_node, $pos_cands, $pos_ords );
        my $neg_instances 
            = $self->_create_instances( $t_node, $neg_cands, $neg_ords );

        my $pos_inst_list = 
            $self->_sort_instances( $pos_instances, $pos_cands);
        my $neg_inst_list = 
            $self->_sort_instances( $neg_instances, $neg_cands);
        
# TODO negative instances appeared to be of 0 size, why?
        if (@{$pos_inst_list} > 0) {
            $self->print_bundle($t_node, $pos_inst_list, $neg_inst_list);
        }
    }
};

1;
