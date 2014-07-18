package Treex::Block::A2A::CS::FixPrepositionNounAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    #  && $dep->afun =~ /^(Atr)$/ && $d->{tag} =~ /^N/
    if ($gov->afun eq 'AuxP'
        && $g->{tag} =~ /^R/
        && $d->{tag} =~ /^[NA]/
        && $g->{case} ne $d->{case}
        )
    {

        if ( $gov->ord < $dep->ord ) {

            # preposition is before noun, that is good

            #    if ( $gov->afun eq 'AuxP' && $g->{tag} =~ /^R/ && $g->{case} ne $d->{case} ) {
            my $doCorrect;

            #if there is an EN counterpart for $dep but its eparent is not a preposition,
            #it means that the CS tree is probably incorrect
            #and the $gov prep does not belong to this $dep at all
            if ( $self->en($dep) ) {
                my ( $enDep, $enGov, $enD, $enG ) =
                    $self->get_pair( $self->en($dep) );
                if ( $enGov and $enDep and $enGov->afun eq 'AuxP' ) {
                    $doCorrect = 1;    #en counterpart's parent is also a prep
                }
                else {
                    $doCorrect = 0;    #en counterpart's parent is not a prep
                }
            }
            else {
                $doCorrect = 1;        #no en counterpart
            }
            if ($doCorrect) {

                #my $case = $g->{case};
                #$d->{tag} =~ s/^(....)./$1$case/;
                #$d->{tag} = $self->try_switch_num($dep, $d->{tag});

                $self->logfix1( $dep, "PrepositionNounAgreement" );
                my $case = $self->get_node_tag_cat($gov, 'case');
                $self->set_node_tag_cat($dep, 'case', $case);
                $self->regenerate_node($dep);
                $self->logfix2($dep);
            }    #else do not correct
        }
        else {

            # preposition is AFTER the noun -> rehang
            log_warn "TODO: The noun is hanging "
                . "under an incorrect preposition!";
        }
    }

    return;
}

1;

=pod

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CS::FixPrepositionNounAgreement

=head1 DESCRIPTION

Fixing agreement between preposition and noun.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.

