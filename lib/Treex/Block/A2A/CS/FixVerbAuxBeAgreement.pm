package Treex::Block::A2A::CS::FixVerbAuxBeAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( $dep->afun eq 'AuxV' && $g->{tag} =~ /^Vf/ ) {
        my $subject;
        foreach my $child ( $gov->get_children() ) {
            $subject = $child if $child->afun eq 'Sb';
        }

        if ( !$subject ) {
            return;
        }

        $self->logfix1( $dep, "VerbAuxBeAgreement" );

        if ( $d->{tag} =~ /^Vp/ ) {

            # past participle active (byl, byli...)
            # dependent's tag gets gender and number substituted
            # for subject's gender and number
            my $sub_gen_num = substr( $subject->tag, 2, 2 );
            substr( $d->{tag}, 2, 2, $sub_gen_num );
        } else {

            # probably VB
            # AuxV's tag gets number substituted for subject's number
            my $sub_num = substr( $subject->tag, 3, 1 );
            substr( $d->{tag}, 3, 1, $sub_num );
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

Treex::Block::A2A::CS::FixVerbAuxBeAgreement - Fixing agreement between verb
and auxiliary 'to be'.

=head1 DESCRIPTION






=head1 AUTHORS

David Marecek <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
