package Treex::Block::Coref::PrintData;
use Moose;
use Treex::Core::Common;
use List::Util;

use Treex::Tool::Align::Utils;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Coref::SupervisedBase';

has 'labeled' => ( is => 'ro', isa => 'Bool', default => 1);

sub BUILD {
    my ($self) = @_;
    $self->_feature_extractor;
    $self->_ante_cands_selector;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;
    # initialize global features
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_filtered_tnode {
    my ( $self, $tnode ) = @_;

    return if ( $tnode->is_root );
    
    my $acs = $self->_ante_cands_selector;
    my $fe = $self->_feature_extractor;

    my @cands = $acs->get_candidates($tnode);
    my $losses = $self->labeled ? is_text_coref($tnode, @cands) : undef;

    if (!$self->labeled || $losses) {
        my ($feats, $comments) = $self->get_features_comments($tnode, \@cands);
        my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);

        print {$self->_file_handle} $instance_str;
    }
}

sub is_text_coref {
    my ($anaph, @cands) = @_;
    
    my @antecs = $anaph->get_coref_chain;
    #push @antecs, map { $_->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $_->children : () } @antecs;

    # if no antecedent, insert itself and if anaphor as candidate is on, it will be marked positive
    if (!@antecs) {
        push @antecs, $anaph;
    }

    my %antes_hash = map {$_->id => $_} @antecs;

    my @losses = map {defined $antes_hash{$_->id} ? 0 : 1} @cands;
    if (none {$_ == 0} @losses) {
        log_info "[Coref::PrintData]\tan antecedent exists but there is none among the candidates: " . $anaph->get_address;
        return;
    }
    return \@losses;
}


1;

=head1 NAME

Treex::Block::Coref::PrintData

=head1 DESCRIPTION

A basic block of a train table printer for coreference resolution.

=head1 SYNOPSIS

    treex -L$lang -Ssrc
        Read::Treex from=sample.streex
        Coref::RemoveLinks type=all language=$lang
        Coref::ProjectLinks selector=ref to_language=$lang to_selector=src
        Coref::PrintData language=$lang

C<Coref::PrintData> should be substituted by its subclass.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
