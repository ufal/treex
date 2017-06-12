package Treex::Block::Discourse::EVALD::PrintData;
use Moose;
use Treex::Core::Common;
use Data::Printer;

use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::ML::Weka::Util;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Discourse::EVALD::Base';

has 'format' => ( is => 'ro', isa => 'Str', default => 'vw' );
has 'multiline' => ( is => 'ro', isa => 'Bool', default => 0 );

sub extract_labels {
    my ($self, $doc) = @_;

    my $class;
    my $filename = $doc->full_filename;
    $filename =~ s/^.*\///;
    if ($filename =~ /^([^_]+)_/) {
        $class = $1;
    }
    return if (!defined $class);

    my $all_classes = $self->_feat_extractor->all_classes;
    if ($self->multiline) {
        my @losses = map {$class eq $_ ? 0 : 1} @$all_classes;
        return \@losses;
    }
    # the returned class should be numeric to model it with linear regression => return the index
    else {
        my ($class_idx) = grep {$all_classes->[$_] eq $class} 0 .. $#$all_classes;
        return $class_idx;
    }
}

sub process_ttree {
    my ($self, $tnode) =@_;
    # this must be implemented even if empty
}

sub print_header {
    my ($self, $doc) = @_;
    if ($self->format eq 'weka') {
        my $weka_header = Treex::Tool::ML::Weka::Util::format_header($self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
        print {$self->_file_handle} $weka_header;
    }
    $self->_process_document($doc);
}

sub _process_document {
    my ($self, $doc) = @_;

    my $labels = $self->extract_labels($doc);

    my $feats = $self->_feat_extractor->extract_features($doc, $self->multiline);
    my $instance_str;
    if ($self->format eq 'vw') {
        $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_instance($feats, $labels);
    }
    elsif ($self->format eq 'weka') {
        $instance_str = Treex::Tool::ML::Weka::Util::format_instance($feats, $labels, $self->_feat_extractor->weka_featlist, $self->_feat_extractor->all_classes);
    }

    print {$self->_file_handle} $instance_str;
}


1;

=head1 NAME

Treex::Block::Discourse::EVALD::PrintData

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
