############################################################################
# SPOILER ALERT:                                                           #
# This is a solution of Treex::Block::Tutorial::PrintDefiniteDescriptions  #
############################################################################

package Treex::Block::Tutorial::Solution::PrintDefiniteDescriptions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    if ( lc($anode->form) eq 'the' ) {

        my $parent = $anode->get_parent;

        my @def_descr_tokens = (
            $anode,
            ( grep { $anode->precedes($_) and $_->precedes($parent) }
                  $parent->get_descendants
              ),
            $parent
        );

        print join " ",map {$_->form} @def_descr_tokens;
        print "\n";
    }

    return;
}


1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::Solution::PrintDefiniteDescriptions

=head1 DESCRIPTION

Definite descriptions are one of the most common constructs in English.
This block approximates definite description in analytical trees as
sequences of tokens starting from "the" and ending with the determiner's
governing node.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
