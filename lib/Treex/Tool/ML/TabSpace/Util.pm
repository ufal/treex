package Treex::Tool::ML::TabSpace::Util;

use Moose;

my $SHARED_LABEL = "__SHARED__";

# parses a complete file passed in as a filehandle
# if the file contains newlines, it is supposed to be in multiline format
sub parse {
    my ($fh) = @_;

    my @instances = ();
    my @bundles = ();

    while (my $line = <$fh>) {
        my @line_inst = parse_line($line, {split_key_val => 1});
        if (!defined $line_inst[0]) {
            push @bundles, \@instances;
            @instances = ();
            next;
        }
        push @instances, \@line_inst;
    }
    if (!@instances) {
        push @bundles, \@instances;
    }

    if (@bundles > 1) {
        my @final_bundles = map {_transform_bundle($_)} @bundles;
        return @final_bundles;
    }
    return @{$bundles[0]};
}

# parses one line
sub parse_line {
    my ($line, $args) = @_;
    chomp $line;

    return if ($line =~ /^\s*$/);

    my ($label, $feats) = split /\t/, $line;
    my @feat_list = split / /, $feats;
    if ($args->{split_key_val}) {
        @feat_list = map {[split /=/, $_]} @feat_list;
    }

    return (\@feat_list, $label);
}

sub format_line {
    my ($feats, $label) = @_;

    my $line = $label . "\t";
    my @feat_str = map {
        ref($_) eq 'ARRAY' ?
            $_->[0] ."=". $_->[1] :
            $_;
    } @$feats;
    $line .= join " ", @feat_str;
    $line .= "\n";
    return $line;
}


# removes labels and transforms to a desired structure if it's in a multiline format
sub _transform_bundle {
    my ($bundle) = @_;

    my $shared_feats;
    my @cand_feats = ();
    foreach my $inst (@$bundle) {
        if ($inst->[1] eq $SHARED_LABEL) {
            $shared_feats = _array_to_hash($inst->[0]);
        }
        else {
            push @cand_feats, _array_to_hash($inst->[0]);
        }
    }
    return [\@cand_feats, $shared_feats];
}

sub _array_to_hash {
    my ($array_feats) = @_;
    my %hash_feats = map {$_->[0] => $_->[1]} @$array_feats;
    return \%hash_feats;
}

1;
