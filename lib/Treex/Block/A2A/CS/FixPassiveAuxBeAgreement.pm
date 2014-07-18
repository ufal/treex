package Treex::Block::A2A::CS::FixPassiveAuxBeAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ($g->{tag} =~ /^Vs/
        && $dep->lemma eq 'být'
        && $gov->ord > $dep->ord
        && ( $g->{gen} . $g->{num} ne $d->{gen} . $d->{num} )
        )
    {
        $self->logfix1( $dep, "PassiveAuxBeAgreement" );
        if ( $d->{tag} =~ /^Vp/ ) {

            # past participle active (byl, byli...)
            # dependent's tag gets gender and number substituted
            # for governor's gender and number
            substr( $d->{tag}, 2, 2, $g->{gen} . $g->{num} );
        } else {

            # not past participle = present or future
            # (jsem, jste... / bude, budou...)
            # dependent's tag gets number substituted for governor's number
            substr( $d->{tag}, 3, 1, $g->{num} );
        }
        $self->regenerate_node( $dep, $d->{tag} );
        $self->logfix2($dep);
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPassiveAuxBeAgreement - Fixing agreement between
passive and auxiliary verb 'to be'.

=head1 DESCRIPTION

If passive participle and dependent auxiliary 'be' do not agree in gender
and/or number, the parent verb takes the categories from the child verb.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
