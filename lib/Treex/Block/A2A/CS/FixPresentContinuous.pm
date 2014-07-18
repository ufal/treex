package Treex::Block::A2A::CS::FixPresentContinuous;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    #    if ( $dep->lemma eq 'být' && $d->{tag} =~ /^VB/ && $g->{tag} =~ /^VB/ && $self->en($gov) && $self->en($gov)->form =~ /ing$/ ) {
    #    if ( $self->en($dep) && $self->en($dep)->lemma eq 'be' && $self->en($dep)->get_parent() && $self->en($dep)->get_parent()->form =~ /ing$/ ) {
    #    if ( $dep->lemma eq 'být' && $d->{tag} =~ /^V.......[^F]/
    #	&& $self->en($dep) && $self->en($dep)->lemma eq 'be'
    #	&& $self->en($gov) && $self->en($gov)->form =~ /ing$/
    #	&& $self->en($dep)->ord < $self->en($gov)->ord
    # ) {
    if ($dep->lemma eq 'být'    # but can also be 'on-1_^(oni/ono)'
        && $d->{tag} =~ /^V[^f]......[^F]/    # but can also be PP...
        && $g->{tag} =~ /^V/
        && $self->en($dep)
        && $self->en($dep)->lemma
        && $self->en($dep)->lemma eq 'be'     # TODO: is this condition necessary?
        &&
        (
            (
                $self->en($dep)->get_parent()
                && $self->en($dep)->get_parent()->form
                && $self->en($dep)->get_parent()->form =~ /ing$/
                && $self->en($dep)->ord
                < $self->en($dep)->get_parent()->ord
            )
            || (
                $self->en($gov)
                && $self->en($gov)->form
                && $self->en($gov)->form =~ /ing$/
                && $self->en($dep)->ord < $self->en($gov)->ord
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
        $self->remove_node($dep);

        #log2
        $self->logfix2(undef);
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPresentContinuous

=head1 DESCRIPTION

Fixing Present Continuous ("is working" translated as "je pracuje" and similar).

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.
