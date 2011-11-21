package Treex::Tool::Coreference::ValueTransformer;

use Moose;
use Treex::Core::Common;


has '_char_mapping' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[Str]',
    builder     => '_build_char_mappping',
);

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

sub special_chars_off {
    my ($self, $value) = @_;

    my $mapping = $self->_char_mapping;

    foreach my $from (keys %{$mapping}) {
		my $to = $mapping->{$from};
        $value = $self->replace_empty( $value );
        if ($value ne "") {
		    $value =~ s/$from/$to/g;
        }
	}
	return $value;
}

sub replace_empty {
    my ($self, $value) = @_;
    if ((!defined $value) || ($value =~ /^\s*$/)) {
        return "";
    }
    $value =~ s/\s+/_/g;
    return $value;
}

1;
