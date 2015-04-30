package Treex::Block::T2T::CopyCorefFromAlignment;

use Moose;
use Treex::Core::Common;
use 5.010;    # operator //

use List::MoreUtils qw/any/;

use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    #my @antecs = $self->_get_coref_nodes($tnode);


    my @antecs = $tnode->get_coref_text_nodes();
    my $type = "text";
    if (!@antecs) {
        @antecs = $tnode->get_coref_gram_nodes();
        $type = "gram";
    }
    # nothing to do if no antecedent
    return if (!@antecs);
    
    my $align_filter = {rel_types => ['monolingual']};
    
    # get aligned antedents
    my @aligned_antecs = Treex::Tool::Align::Utils::aligned_transitively(\@antecs, [$align_filter]);
    while (@antecs && !@aligned_antecs && !any {$_->functor =~ /APPS|CONJ/} @antecs) {
        @antecs = map {$_->get_coref_nodes} @antecs;
        #print STDERR $tnode->id . "\n";
        #print STDERR join " ", map {$_ ? $_->id : "undef"} @antecs;
        #print STDERR "\n";
        @aligned_antecs = Treex::Tool::Align::Utils::aligned_transitively(\@antecs, [$align_filter]);
    }
    # nothing to do if no antecedent
    return if (!@antecs);
    # an apposition or CONJ coordination root has no counterpart -> find it for its children
    if (!@aligned_antecs) {
        my @apps_conj_antecs = grep {$_->functor =~ /APPS|CONJ/} @antecs;
        my @antec_children = map {$_->children} @apps_conj_antecs;
        @aligned_antecs = Treex::Tool::Align::Utils::aligned_transitively(\@antec_children, [$align_filter]);
    }

    # project all links for every anaphor's counterpart
    my @aligned_anaphs = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$align_filter]);
    foreach my $source ( @aligned_anaphs ) {
        if (!defined $source) {
            log_warn "A list of aligned anaphors contains an undefined value. Source anaphor: " . $tnode->id;
        }

        # remove a possibly inserted 'anaph' itself from the list of its antecedents
        @aligned_antecs = grep {$_ != $source} @aligned_antecs;
        if ($type eq "gram") {
            $source->add_coref_gram_nodes(@aligned_antecs);
        }
        else {
            $source->add_coref_text_nodes(@aligned_antecs);
        }
    }
}

1;

=head1 NAME

Treex::Block::T2T::CopyCorefFromAlignment

=head1 DESCRIPTION

This blocks projects coreference links from the current zone to a zone specified by monolingual alignment.
Thus, there is no need to specify a target zone explicitely.

If an antecedent has ho counterpart, it proceeds back in the coreference chain until any countepart of one
of the antecedents is found. The only exception is, if the antecedent is a apposition or CONJ coordination
root. Then, the counterparts of its children are pronounced the antecedent's counterpart.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
