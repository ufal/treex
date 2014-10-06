package Treex::Tool::ML::TabSpace::Util;

use Moose;
use Data::Dumper;

my $SHARED_LABEL = "__SHARED__";
my $REMOVE_UNDEFS = 1;
my $UNDEF_VALUE = "__UNDEF__";
my $FEAT_VAL_DELIM = "=";

# parses one instance in singleline format
sub parse_singleline {
    my ($fh, $args) = @_;
    my $line = <$fh>;
    return if (!defined $line);
    
    chomp $line;
    return [] if ($line =~ /^\s*$/);

    my ($label, $feats) = split /\t/, $line;
    my @feat_list = split / /, $feats;
    if ($args->{split_key_val}) {
        @feat_list = map {[split /$FEAT_VAL_DELIM/, $_]} @feat_list;
    }

    return [\@feat_list, $label];
}

# parses one instance (bundle) in multiline format
sub parse_multiline {
    my ($fh, $args) = @_;

    my ($shared_feats, $shared_label);
    my @cand_feats = ();
    my @losses = ();
    while (my $inst = parse_singleline($fh, $args)) {
        last if (!@$inst);
        my ($feats, $label) = @$inst;
        if ($label eq $SHARED_LABEL) {
            $shared_feats = $feats;
            next;
        }
        push @cand_feats, $feats;
        next if ($label eq "");
        # label = loss
        push @losses, $label;
    }
    return if (!@cand_feats);
    my $all_feats = [ \@cand_feats, $shared_feats ];
    return [ $all_feats, @losses ? \@losses : undef ];
}

sub format_singleline {
    my ($feats, $label) = @_;

    my $line = ($label // "") . "\t";
    my @feat_str = map {
        if (ref($_) eq 'ARRAY') {
            if (!$REMOVE_UNDEFS || defined $_->[1]) {
                $_->[0] .$FEAT_VAL_DELIM. ($_->[1] // $UNDEF_VALUE);
            }
        }
        else {
            $_;
        }
    } @$feats;
    $line .= join " ", @feat_str;
    $line .= "\n";
    return $line;
}

sub format_multiline {
    my ($feats, $losses) = @_;

    my ($cands_feats, $shared_feats) = @$feats;

    my $instance_str = "";
    if (defined $shared_feats) {
        $instance_str .= format_singleline($shared_feats, $SHARED_LABEL);
    }

    my $i = 0;
    foreach my $cand_feats (@$cands_feats) {
        my $loss = undef;
        if (defined $losses) {
            $loss = $losses->[$i];
        }
        $instance_str .= format_singleline($cand_feats, $loss);
        $i++;
    }
    $instance_str .= "\n";
    return $instance_str;
}

#    while ()
#
#    my @instances = ();
#    my @bundles = ();
#
#    while (my $line = <$fh>) {
#        my @line_inst = parse_line($line, $args);
#        if (!defined $line_inst[0]) {
#            push @bundles, \@instances;
#            @instances = ();
#            next;
#        }
#        push @instances, \@line_inst;
#    }
#    if (!@instances) {
#        push @bundles, \@instances;
#    }
#
#    if (@bundles > 1) {
#        my @final_bundles = map {_transform_bundle($_)} @bundles;
#        return @final_bundles;
#    }
#    return @{$bundles[0]};
#}



# removes labels and transforms to a desired structure if it's in a multiline format
#sub _transform_bundle {
#    my ($bundle) = @_;
#
#    my $shared_feats;
#    my @cand_feats = ();
#    foreach my $inst (@$bundle) {
#        if ($inst->[1] eq $SHARED_LABEL) {
#            $shared_feats = _array_to_hash($inst->[0]);
#        }
#        else {
#            push @cand_feats, _array_to_hash($inst->[0]);
#        }
#    }
#    return [\@cand_feats, $shared_feats];
#}
#
#sub _array_to_hash {
#    my ($array_feats) = @_;
#    my %hash_feats = map {$_->[0] => $_->[1]} @$array_feats;
#    return \%hash_feats;
#}

1;
