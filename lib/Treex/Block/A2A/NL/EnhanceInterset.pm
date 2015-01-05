package Treex::Block::A2A::NL::EnhanceInterset;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # adjectives -- fix predicative vs. adverbial usage (marked always adverbial from Interset)
    if ( $anode->match_iset( 'pos' => 'adj', 'synpos' => 'pred' ) ) {
        if ( $anode->afun !~ /^(Pnom|Obj)$/ ) {
            $anode->set_iset( 'synpos' => 'adv' );
        }
    }

    return;
}

1;


__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::NL::EnhanceInterset

=head1 DESCRIPTION

Enhance Interset values based on current Interset tags, lemmas, and afuns.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
