package Treex::Block::Write::LayerAttributes::NegationCueAndScope;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has max_number_of_negs => ( is => 'rw', isa => 'Num', default => 6 );

has instead_undef => ( is => 'ro', isa => 'Str', default => '_');

has '+return_values_names' => ( lazy => 1, builder => '_build_return_values_names' );

sub _build_return_values_names {
    my ($self) = @_;
    
    my @result = ();
    for (my $i = 1; $i <= $self->max_number_of_negs; $i++) {
        push @result, "cue$i";
        push @result, "scope$i";
    }

    return \@result;
}

# cs = cue / scope
sub anode_substr {
    my ($anode, $negation_id, $cs) = @_;

    my $start = $anode->wild->{negation}->{$negation_id}->{$cs . '_from'};
    my $end   = $anode->wild->{negation}->{$negation_id}->{$cs . '_to'};
    if (defined $start && defined $end) {
        my $length = $end - $start + 1;
        return substr($anode->form, $start, $length);
    } else {
        return $anode->form;
    }
}

sub modify_single {

    my ( $self, $anode ) = @_;

    my @result = ();
    my $negation_ids = $anode->get_root()->wild->{negation}->{negation_ids};
    if (defined $negation_ids) {
        foreach my $negation_id (@$negation_ids) {
            # CUE
            my $cue = "_";
            if ($anode->wild->{negation}->{$negation_id}->{cue}) {
                $cue = anode_substr($anode, $negation_id, 'cue');
            }
            push @result, $cue;

            # SCOPE
            my $scope = "_";
            if ($anode->wild->{negation}->{$negation_id}->{scope}) {
                $scope = anode_substr($anode, $negation_id, 'scope');
            }
            push @result, $scope;
        }
    }
    
    my $diff = 2*$self->max_number_of_negs - scalar(@result);
    if ($diff > 0) {
        # pad with underscores
        push @result, ($self->instead_undef) x $diff;
    } elsif ($diff < 0) {
        log_warn "Sentence has " . (scalar(@result)/2) . " negations, but max is " . $self->max_number_of_negs . "!";
        splice @result, 2*$self->max_number_of_negs;
    }
    # else OK

    return @result;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::NegationCueAndScope

=head1 SYNOPSIS

 treex -Lcs Read::PDT T2T::CS2CS::MarkNegationCueAndScope 
 Write::AttributeSentences attributes='form,NegationCueAndScope(node)' separator='\n' attr_sep='\t' sent_sep='\n\n' layer=a

=head1 DESCRIPTION

Given a node, prints the parts of its from that are part of negation cues and scopes, as marked by L<Treex::Block::T2T::CS2CS::MarkeNegationCueAndScope>.

The format follows the definition by Federico Fancellu <F.Fancellu@sms.ed.ac.uk> -- form, cue1, scope1, cue2, scope2, cue3, scope3... E.g.:

 I       _   _     _  _     _ _
 am      _   am    _  _     _ _
 not     not _     _  _     _ _
 happy   _   happy _  _     _ _
 ,       _   _     _  _     _ _
 I       _   _     _  _     _ _
 am      _   _     _  _     _ _
 unhappy _   _     un happy _ _
 .       _   _     _  _     _ _

The maximum number of negations per sentence that can be written out is specified by C<max_number_of_negs>; the default is C<6>
(AFAIK the max number of negations found in a PDT sentence is 5).
Surplus negations are not written out, and a warning is printed.
If there are less negations than the maximum, the surplus slots for cues and fields are filled with the C<instead_undef> string; the default is C<_>.
Thus, exactly C<2*max_number_of_negs> fields are always generated.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
