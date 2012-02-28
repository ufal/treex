package Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if ($en_counterpart{$dep}
        && $en_counterpart{$dep}->afun eq 'Sb'
        && $g->{tag} =~ /^V[sp]/ && $d->{tag} =~ /^[NP]/
        && $dep->form !~ /^[Tt]o/
        && ( $g->{gen} . $g->{num} ne $self->gn2pp( $d->{gen} . $d->{num} ) )
        )
    {
        my $new_gn = $self->gn2pp( $d->{gen} . $d->{num} );
        $g->{tag} =~ s/^(..)../$1$new_gn/;

        $self->logfix1( $dep, "SubjectPastParticipleAgreement" );
        $self->regenerate_node( $gov, $g->{tag} );
        $self->logfix2($dep);
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement - Fixing agreement
between subject and past participle.

=head1 DESCRIPTION

Past participle (Vs or Vp) gets gender and number from subject.

=head1 AUTHORS

David Marecek <marecek@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
