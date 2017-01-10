package Treex::Block::Write::Negations;

use Moose;
use Treex::Core::Common;
use List::MoreUtils "uniq";
extends 'Treex::Block::Write::BaseTextWriter';

has only_negated => ( is => 'rw', isa => 'Bool', default => 0 );

has print_ttree => ( is => 'rw', isa => 'Bool', default => 0 );

has print_sentence => ( is => 'rw', isa => 'Bool', default => 0 );

has print_id => ( is => 'rw', isa => 'Bool', default => 0 );

# cs = cue / scope
sub anode_substr {
    my ($anode, $negation_id, $cs) = @_;

    my $start = $anode->wild->{negation}->{$negation_id}->{$cs . '_from'};
    if (defined $start) {
        my $length = $anode->wild->{negation}->{$negation_id}->{$cs . '_to'} - $start + 1;
        my $form = $anode->form;
        my $string = substr $form, $start, $length;
        if ($start > 0) {
            $string = "-$string";
        }
        if ($start + $length < length($form)) {
            $string = "$string-";
        }
        return $string;
    } else {
        return $anode->form;
    }
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $aroot = $zone->get_atree();
    my $negation_ids = $aroot->wild->{negation}->{negation_ids};
    if ((!defined $negation_ids || @$negation_ids == 0) && $self->only_negated) {
        return;
    }
    
    print { $self->_file_handle } "\n";

    if ($self->print_id) {
        print { $self->_file_handle }
            $zone->get_document->full_filename, ".t.gz##", ($zone->get_bundle->get_position + 1), "\n";
    }

    if ($self->print_sentence) {
        print { $self->_file_handle } $zone->sentence, "\n";
    }

    if ($self->print_ttree) {
        my $troot = $zone->get_ttree();
        my @tnodes = $troot->get_descendants({ordered => 1});
        foreach my $tnode (@tnodes) {
            my @signature = grep { defined $_ } ($tnode->t_lemma, $tnode->functor, $tnode->tfa);
            print { $self->_file_handle } join '/', @signature;
            my @anodes = $tnode->get_anodes({ordered => 1});
            if (@anodes) {
                print { $self->_file_handle } " (";
                my @aforms;
                foreach my $anode (@anodes) {
                    push @aforms, $anode->form;
                }
                print { $self->_file_handle } join ' ', @aforms;
                print { $self->_file_handle } ")";
            }
            print { $self->_file_handle } " ";
        }
        print { $self->_file_handle } "\n";
    }
    my @descendants = $aroot->get_descendants({ordered => 1});
    foreach my $negation_id (@$negation_ids) {
        my @cue_nodes = grep { $_->wild->{negation}->{$negation_id}->{cue} } @descendants;
        my $cue = join ' ', map { anode_substr($_, $negation_id, 'cue') } @cue_nodes;

        my @scope_nodes = grep { $_->wild->{negation}->{$negation_id}->{scope} } @descendants;
        my $scope = join ' ', map { anode_substr($_, $negation_id, 'scope') } @scope_nodes;

        print { $self->_file_handle } "  CUE: $cue SCOPE: $scope\n";
    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::Negations

=head1 DESCRIPTION

Prints out sentences together with their negation cues and their scopes.

=head1 AUTHOR

Rudolf Rosa

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
