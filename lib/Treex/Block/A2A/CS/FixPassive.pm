package Treex::Block::A2A::CS::FixPassive;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if ($g->{tag} =~ /^V[^s]/
        && ! ( grep { $_->form =~ /^s[ei]$/ } $gov->get_children )
        && ( grep { $_->lemma eq "být" && $_->afun eq "AuxV" } $gov->get_children )
        && $en_counterpart{$gov}
        && $en_counterpart{$gov}->tag =~ /^VB[ND]/
        && grep { $_->lemma eq "be" && $_->afun eq "AuxV" } $en_counterpart{$gov}->get_children
        )
    {
        $self->logfix1( $gov, "Passive" );
        # subpos: s
        my $gn = $self->gn2pp( $g->{gen} . $g->{num} );
        my $newtag = 'Vs' . $gn . '---XX-' . $g->{neg} . 'P---';
        $self->regenerate_node( $gov, $newtag );
        $self->logfix2($gov);
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPassive

=head1 DESCRIPTION

English passive's Czech counterpart should be passive if it has AuxV být (be)
among its children.

TODO: maybe check whether the original subject/object roles have been kept

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
