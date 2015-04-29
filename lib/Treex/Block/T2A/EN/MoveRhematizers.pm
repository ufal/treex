package Treex::Block::T2A::EN::MoveRhematizers;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # skip anything containing prepositions/conjunctions (only handle one-word rhematizers)
    return if ( $tnode->formeme =~ /\+/ );

    # skip anything that does not look like a rhematizer
    return if ( ( $tnode->functor // '' ) ne 'RHEM' and ( $tnode->t_lemma !~ /^(even|and|also|perhaps)$/ ) );
    return if ( !$tnode->is_leaf );

    # skip anything not hanging under a noun
    my $anode = $tnode->get_lex_anode() or return;

    my $tparent = $tnode->get_parent;
    return if ( $tparent->formeme !~ /^n/ );

    my ($first_aparent) = grep { $_->lemma ne 'of' or $tnode->t_lemma !~ /^(almost|only)$/ } $tparent->get_anodes( { ordered => 1 } );

    # move the rhematizer before the noun's subtree
    $anode->shift_before_subtree($first_aparent);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::MoveRhematizers - shift rhematizers before articles and prepositions

=head1 DESCRIPTION

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
