package Treex::Block::A2A::CS::FixNounNounAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

# do not use as is because in most cases it worsens the sentence
# (even though often it is due to incorrect parse tree)

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    # 'by' preposition being a head of an inflected word

    if (
        $d->{tag} =~ /^N/
        && $g->{tag} =~ /^N/
        && $dep->ord < $gov->ord
        )
    {

        # assuming the case of the parent is correct
        # now find the correct case for this situation
        my $original_case = $d->{case};
        my $case          = $g->{case};

        if ( $case != $original_case ) {

            $d->{tag} =~ s/^(....)./$1$case/;

            $self->logfix1( $dep, "NounNounAgreement (case $case)" );
            $self->regenerate_node( $dep, $d->{tag} );
            $self->logfix2($dep);
        }

    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixNounNounAgreement

=head1 DESCRIPTION

A noun preceding a noun which is its parent should agree with it in case.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.
