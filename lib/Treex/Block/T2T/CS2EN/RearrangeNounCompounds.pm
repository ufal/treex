package Treex::Block::T2T::CS2EN::RearrangeNounCompounds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->formeme eq "n:attr" ) {
        my $par = $tnode->get_parent;

        if (defined $par->formeme
            and $par->formeme =~ /^n:(.+\+X|attr|obj[12]?)$/
            and not(
                $tnode->t_lemma =~ /[„“”\[\]]/
                or $par->t_lemma =~ /^(Facebook|Google|Windows([ _].*)?|Microsoft|GeForce)[ _]?$/
                or ( $par->t_lemma eq 'Internet'            and $tnode->t_lemma eq 'Explorer' )
                or ( $par->t_lemma eq 'IE'                  and $tnode->t_lemma eq 'Internet[ _]Explorer' )
                or ( $par->t_lemma =~ /^(IP|MAC)[ _]?$/i    and $tnode->t_lemma eq 'address' )
                or ( uc $par->t_lemma eq 'TIME'             and $tnode->t_lemma eq 'Capsule' )
                or ( $par->t_lemma =~ /^[kKMG]B$/           and $tnode->t_lemma =~ /^(SD|SDHC|RAM)$/ )
                or ( $par->t_lemma =~ /^(Open|Libre)[ _]?$/ and $tnode->t_lemma eq 'Office' )
                or ( uc $par->t_lemma eq 'POWER'            and $tnode->t_lemma eq 'Point' )
            )
            )
        {
            $par->shift_after_subtree( $tnode, { without_children => 1 } );
        }
    }
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2EN::RearrangeNounCompounds

=head1 DESCRIPTION

A block to swap or rearrange NP compounds, e.g. "účet GMail" -> "Gmail account".

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
