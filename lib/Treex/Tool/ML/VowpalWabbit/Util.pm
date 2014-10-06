package Treex::Tool::ML::VowpalWabbit::Util;

use Moose;
use Treex::Core::Common;
use List::Util qw/min/;

my $SHARED_LABEL = "shared";
my $FEAT_VAL_DELIM = "=";
my $SELF_LABEL = "__SELF__";

sub _add_default_args {
    my ($args) = @_;
    if (!defined $args->{parse_feats}) {
        $args->{parse_feats} = 'single';
    }
    if (!defined $args->{items}) {
        $args->{items} = ['feats', 'label', 'tag', 'comment'];
    }
}

sub _parse_line {
    my ($fh, $args) = @_;
    
    my $line = <$fh>;
    return if (!defined $line);
    
    chomp $line;
    return undef if ($line =~ /^\s*$/);

    my ($data, $comment) = split /\t/, $line;
    my ($label_str, $feat_str) = split /\|/, $data;
    my ($label, $tag) = split / /, $label_str;
    $label = undef if ($label eq "");

    my $feats = $feat_str;
    if ($args->{parse_feats} ne "no") {
        my @feat_list = split / /, $feats;
        # remove a possible namespace id
        shift @feat_list;
        if ($args->{parse_feats} eq "pair") {
            @feat_list = map {[split /$FEAT_VAL_DELIM/, $_, 2]} @feat_list;
        }
        $feats = \@feat_list;
    }

    return ($feats, $label, $tag, $comment);
}

# parses one instance in a singleline format
sub parse_singleline {
    my ($fh, $args) = @_;
    _add_default_args($args);
    my ($feats, $label, $tag, $comment) = _parse_line($fh, $args);
    
    my %items = (
        feats => $feats,
        label => $label,
        tag => $tag,
        comment => $comment
    );
    return map {$items{$_}} @{$args->{items}}
}

# parses one instance (bundle) in a multiline format
sub parse_multiline {
    my ($fh, $args) = @_;
    _add_default_args($args);

    my $shared_feats;
    my @cand_feats = ();
    my @losses = ();
    my $shared_tag;
    my @cand_tags = ();
    my $shared_comment;
    my @cand_comments = ();
    while (my ($feats, $label, $tag, $comment) = _parse_line($fh, $args)) {
        last if (!defined $feats);
        if ($label eq $SHARED_LABEL) {
            $shared_feats = $feats;
            $shared_tag = $tag;
            $shared_comment = $comment;
            next;
        }
        push @cand_feats, $feats;
        push @cand_tags, $tag;
        push @cand_comments, $comment;
        next if (!defined $label);
        # label = loss
        my ($pos, $loss) = split /:/, $label;
        next if (!defined $loss);
        push @losses, $loss;
    }
    return if (!@cand_feats);
    
    my %items = (
        feats => [ \@cand_feats, $shared_feats ],
        label => (@losses ? \@losses : undef),
        tag => [ \@cand_tags, $shared_tag ],
        comment => [ \@cand_comments, $shared_comment ]
    );
    return map {$items{$_}} @{$args->{items}}
}

sub format_multiline {
    my ($feats, $losses, $comments) = @_;

    my ($cands_feats, $shared_feats) = @$feats;
    my ($cand_comments, $shared_comment) = defined $comments ? @$comments : ([], undef);

    my $instance_str = "";

    if (defined $shared_feats) {
        $instance_str .= format_singleline($shared_feats, $SHARED_LABEL, undef, $shared_comment);
    }

    my $tag = "";
    if (defined $losses) {
        my $min_loss = min @$losses;
        my @min_loss_idx = grep {$losses->[$_] == $min_loss} 0 .. $#$losses;
        $tag = join ",", (map {$_ + 1} @min_loss_idx);
       
        #my ($self_cand_idx) = grep {
        #    my $feat = $cands_feats->[$_][0];
        #    if (ref($feat) eq 'ARRAY') {
        #        $feat->[0] eq $SELF_LABEL;
        #    }
        #    else {
        #        $feat eq $SELF_LABEL.$FEAT_VAL_DELIM."1";
        #    }
        #} 0 .. $#$cands_feats;
        my $self_cand_idx = 0;
        $tag .= '-' . ($self_cand_idx+1) if (defined $self_cand_idx);
    }
    
    my $i = 0;
    foreach my $cand_feats (@$cands_feats) {
        my $label = $i+1;
        if (defined $losses) {
            $label .= ":" . $losses->[$i];
        }
        $instance_str .= format_singleline($cand_feats, $label, $tag, $cand_comments->[$i]);
        $i++;
    }
    $instance_str .= "\n";
    return $instance_str;
}

sub format_singleline {
    my ($feats, $label, $tag, $comment) = @_;

    my $feat_str;
    if (!ref($feats)) {
        $feat_str = $feats;
    }
    else {
        my @feats_items = map {
            ref($_) eq 'ARRAY' ?
                $_->[0] .$FEAT_VAL_DELIM. $_->[1] :
                $_;
        } @$feats;
        $feat_str = "default ";
        $feat_str .= join " ", (map {feat_perl_to_vw($_)} @feats_items);
    }
    my $line = sprintf "%s %s|%s\t%s\n",
        defined $label ? $label : "",
        defined $tag ? $tag : "",
        $feat_str,
        defined $comment ? $comment : "";

    return $line;
}

#sub _x_to_str {
#    my ($x) = @_;
#    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
#    $x_str = join ' ', feats_perl_to_vw(@$x);
#    return $x_str;
#}
#
#
#################### METHODS TO BE REMOVED ####################
#
#sub instance_to_vw_str {
#    my ($x, $y, $y_str) = @_;
#
#    my $instance_str = _x_to_str($x);
#
#    if (defined $y_str) {
#        $instance_str = "$y $y_str| $instance_str";
#    }
#    elsif (defined $y) {
#        $instance_str = "$y | $instance_str";
#    }
#    else {
#        $instance_str = "| $instance_str";
#    }
#    
#    return $instance_str;
#}
#
#sub _x_to_str {
#    my ($x) = @_;
#    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
#    $x_str = join ' ', feats_perl_to_vw(@$x);
#    return $x_str;
#}
#
#sub _feats_to_str {
#    my ($feats) = @_;
#
#    my $feats_str = "";
#    if (ref($feats_str) eq 'ARRAY') {
#        my $val_hash = all {ref($_) eq 'HASH'} values %$feats_str;
#        if ($val_hash) {
#            my %str_hash = map {$_ => _x_to_str($feats_str->{$_})} keys %$feats_str;
#            return \%str_hash;
#        }
#        else {
#            return _x_to_str($feats_str);
#        }
#    }
#}
#
#sub instance_to_multiline {
#    my ($x, $y, $all_labels, $is_test, $y_str) = @_;
#
#    my $instance = _feats_to_str($x);
#    my $instance_str = "";
#
#    # shared
#    my $shared_str;
#    if (ref($instance) eq 'HASH') {
#        if (defined $instance->{shared}) {
#            $shared_str = $instance->{shared};
#        }
#    }
#    else {
#       $shared_str = $instance;
#    }
#    $instance_str = "shared |s " . $instance_str . "\n" if (defined $shared_str);
#
#    if (!defined $all_labels && (ref($instance) eq 'HASH')) {
#        $all_labels = [ keys %$instance ];
#    }
#    my %label_idx = map {$all_labels->[$_] => $_} 1 .. scalar @$all_labels;
#    
#    foreach my $label (@$all_labels) {
#        $y_str = defined $y_str ? $y_str : "";
#        
#        my $feat_str = $label;
#        if (ref($instance) eq 'HASH') {
#            $feat_str = $instance->{$label};
#        }
#
#        if ($is_test) {
#            $instance_str .= sprintf "%d %s|t %s\n", $label_idx{$label}, $y_str, $feat_str;
#        }
#        else {
#            my $loss = $label eq $y ? 0 : 1;
#            $instance_str .= sprintf "%d:%d %s|t %s\n", $label_idx{$label}, $loss, $y_str, $feat_str;
#        }
#    }
#    $instance_str .= "\n";
#    return $instance_str;
#}

sub feat_perl_to_vw {
    my ($feat) = @_;
    # ":" and "|" is a special char in VW
    $feat =~ s/:/__COL__/g;
    $feat =~ s/\|/__PIPE__/g;
    $feat =~ s/\t/__TAB__/g;
    $feat =~ s/ /__SPACE__/g;
    #utf8::encode($feat);
    return $feat;
}

sub feats_vw_to_perl {
    my (@feats) = @_;
    my @feats_no_ns = map {$_ =~ s/^[^^]*\^(.*)$/$1/; $_} @feats;
    foreach my $feat (@feats_no_ns) {
        utf8::decode($feat);
        $feat =~ s/__PIPE__/|/g;
        $feat =~ s/__COL__/:/g;
        $feat =~ s/__TAB__/\t/g;
        $feat =~ s/__SPACE__/ /g;
    }
    return @feats_no_ns;
}

sub split_to_classes {
    my ($array, $k) = @_;
    
    if (@$array % $k != 0) {
        log_fatal "Length of the array must be a multiple of the number of classes.";
    }

    my $feat_num = scalar @$array / $k;
    
    my $classed_array = {};
    for (my $i = 1; $i <= $k; $i++) {
        $classed_array->{$i} = [ @$array[$feat_num*($i-1) .. $feat_num*$i-1] ];
    }
    return $classed_array;
}

sub parse_csoaa_ldf {
}

1;

__END__

=head1 NAME

Treex::Tool::ML::VowpalWabbit::Util

=head1 SYNOPSIS

 use Treex::Tool::ML::VowpalWabbit::Util;
 
 while ( my ($instance, $tag, $comment) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN, {split_key_val => 1}) ) {
     my ($feats, $losses) = @$instance;
     my $format_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comment);
     print $format_str . "\n";
 }
 
=head1 DESCRIPTION

Parser and formatter for data tables formatted in the style accepted by the Vowpal Wabbit ML tool.
It can handle both singleline (e.g. for the OAA method) and multiline format (for the CSOAA_LDF method).
In fact, not all options for this format are supported (e.g. namespaces, multiple costed labels on a single line).
On the other hand, the tables may be extended by an additional tab-separated column containing comments.

=head1 FUNCTIONS

=head2 @instance_items = parse_singleline($fh, $args)

It parses every single line in a data table coming from a file handle C<$fh> independently.
This can be used also for parsing into the multiline format, if we do not mind not processing the entire instance at once.
A parsed instance, which is a list of several items, is returned. A content of the list depends
on a value of the C<items> argument defined by the C<$args> parameter.

=head3 Arguments

The possible arguments that can be specified in the C<$args> hashref are:

=over
=item * items

A list of items that will be returned by the parser. One can choose from the following items:
C<feats>, C<label>, C<tag> and C<comment>. A default value is C<['feats', 'label', 'tag', 'comment']>

=item * parse_feats

It defines an extent to which features are parsed. Possible values: 
C<no> (feature list is left as a single string),
C<single> (individual features are separated by the space char as a delimiter, but no structure is looked for within them), 
C<pair> (every feature is separated into a key and a value by the C<=> char as a delimiter)
The value C<single> is default.

=back

=head2 parse_multiline

It parses a data table into multiline instances. These are separated by an empty line.

=head2 format_singleline

Formatter for singleline instances.

=head2 format_multiline

Formatter for multiline instances.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-14 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
