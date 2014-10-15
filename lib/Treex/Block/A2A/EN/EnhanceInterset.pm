package Treex::Block::A2A::EN::EnhanceInterset;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    
    # fill in definiteness for determiners
    if ($anode->match_iset('adjtype' => 'det')){
        if ($anode->lemma eq 'the'){
            $anode->iset->set_definiteness('def');
        }
        elsif ($anode->lemma eq 'a'){
            $anode->iset->set_definiteness('ind');
        }
    }
    return;
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::EN::EnhanceInterset

=head1 DESCRIPTION

Enhance Interset values based on current Interset tags and lemmas.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
