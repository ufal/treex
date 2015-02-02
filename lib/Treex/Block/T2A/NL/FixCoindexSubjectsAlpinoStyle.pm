package Treex::Block::T2A::NL::FixCoindexSubjectsAlpinoStyle;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

with 'Treex::Block::T2A::NL::CoindexNodes';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # we look for a infinitive verb that hangs under another, finite verb
    return if ( $tnode->formeme !~ /^v(:obj)?:(te\+)?inf$/ );
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    return if ( !$tparent or $tparent->formeme !~ /^v:.*fin$/ );

    # there must not already be a subject under the infinitive verb
    my ($tsubj) = grep { $_->formeme eq 'n:subj' } $tnode->get_echildren( { or_topological => 1 } );
    return if ($tsubj);

    # but the finite verb must have a subject
    my ($tpar_subj) = grep { $_->formeme eq 'n:subj' } $tparent->get_echildren( { or_topological => 1 } );
    return if ( !$tpar_subj );

    # now create the coindexed subject node
    my ($apar_subj) = $tpar_subj->get_lex_anode() or return;
    my ($averb)     = $tnode->get_lex_anode()     or return;

    my $acoindex = $self->add_coindex_node( $averb, $apar_subj, 'Sb' );

    # shift the coindex node to the beginning of the main verb's subtree
    # (we can do this only now since the subtree has just been moved from the 1st auxiliary)
    $acoindex->shift_before_subtree($averb);

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::FixCoindexSubjectsAlpinoStyle

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
