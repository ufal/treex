package Treex::Tool::ML::Weka::Util;
use Moose;
use Treex::Core::Common;
use Data::Printer;

sub format_instance {
    my ($feats, $losses, $feat_types, $all_classes) = @_;

    my ($cands_feats, $shared_feats) = @$feats;
    my $label;
    if (defined $losses) {
        my $true_idx = $losses;
        if (ref($losses) eq "ARRAY") {
            ($true_idx) = grep {!$losses->[$_]} 0 .. $#$losses;
        }
        $label = $all_classes->[$true_idx];
    }

    return format_singleline($shared_feats, $label);
}

sub format_singleline {
    my ($feats, $label) = @_;
    my @no_ns = grep {$_->[0] !~ /^\|/} @$feats;
    my $str = sprintf "%s, %s\n",
        (join ", ", map {$_->[1] // $_->[2]} @no_ns),
        $label // "?";
    return $str; 
}

sub format_header {
    my ($feat_types, $all_classes) = @_;
    
    my $header = '@RELATION Evald' . "\n\n";
    $header .= join "\n", map {my $name = $_->[0]; $name =~ s/^[^\^]*\^//; '@ATTRIBUTE '.$name.'  '.$_->[1]} @$feat_types;
    $header .= "\n";
    $header .= sprintf '@ATTRIBUTE class {%s}', join(", ", @$all_classes);
    $header .= "\n";
    $header .= "\n" . '@DATA' . "\n";
    return $header;
}

1;
__END__

=encoding utf-8


=head1 NAME

Treex::Tool::ML::Weka::Util

=head1 DESCRIPTION

Utils for Weka learner.

=head1 METHODS

=head2 format_instance
Format data instances for Weka learner.

=head1 AUTHOR

Michal Novák <mnoval@ufal.mff.cuni.cz>
Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016-17 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


