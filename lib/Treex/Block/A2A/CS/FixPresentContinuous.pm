package Treex::Block::A2A::CS::FixPresentContinuous;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    #    if ( $dep->lemma eq 'být' && $d->{tag} =~ /^VB/ && $g->{tag} =~ /^VB/ && $en_counterpart{$gov} && $en_counterpart{$gov}->form =~ /ing$/ ) {
    #    if ( $en_counterpart{$dep} && $en_counterpart{$dep}->lemma eq 'be' && $en_counterpart{$dep}->get_parent() && $en_counterpart{$dep}->get_parent()->form =~ /ing$/ ) {
    #    if ( $dep->lemma eq 'být' && $d->{tag} =~ /^V.......[^F]/
    #	&& $en_counterpart{$dep} && $en_counterpart{$dep}->lemma eq 'be'
    #	&& $en_counterpart{$gov} && $en_counterpart{$gov}->form =~ /ing$/
    #	&& $en_counterpart{$dep}->ord < $en_counterpart{$gov}->ord
    # ) {
    # TODO: I am occasionally getting: Use of uninitialized value in pattern match (m//) at /ha/work/people/rosa/tectomt/treex/lib/Treex/Block/A2A/CS/FixPresentContinuous.pm line 19.
    if ($dep->lemma eq 'být'
        && $d->{tag} =~ /^V[^f]......[^F]/
        && $g->{tag} =~ /^V/
        && $en_counterpart{$dep} && $en_counterpart{$dep}->lemma eq 'be' &&
        (
            (
                $en_counterpart{$dep}->get_parent()
                && $en_counterpart{$dep}->get_parent()->form =~ /ing$/
                && $en_counterpart{$dep}->ord
                < $en_counterpart{$dep}->get_parent()->ord
            )
            || (
                $en_counterpart{$gov}
                && $en_counterpart{$gov}->form =~ /ing$/
                && $en_counterpart{$dep}->ord < $en_counterpart{$gov}->ord
            )
        )
        )
    {

        #log1
        $self->logfix1( $dep, "PresentContinuous" );

        #set gov's tag to dep's tag (preserve negation)
        my $negation;
        if (substr( $g->{tag}, 10, 1 ) eq 'N'
            || substr( $d->{tag}, 10, 1 ) eq 'N'
            )
        {
            $negation = 'N';
        }
        else {
            $negation = 'A';
        }
        my $tag = $d->{tag};
        substr( $tag, 10, 1, $negation );
        $self->regenerate_node( $gov, $tag );

        #remove
        $self->remove_node( $dep, $en_hash );

        #log2
        $self->logfix2(undef);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixPresentContinuous

Fixing Present Continuous ("is working" translated as "je pracuje" and similar).

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
