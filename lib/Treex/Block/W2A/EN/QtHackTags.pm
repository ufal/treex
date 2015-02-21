package Treex::Block::W2A::EN::QtHackTags;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    if ( ($anode->lemma // '') eq 'select'
        && $anode->tag !~ /^VB/
    ) {
        $anode->set_tag('VB');
    }

    return ;
}


1;

=head1 NAME 

Treex::Block::W2A::EN::QtHackTags

=head1 DESCRIPTION

Some hacks useful for QTLeap; aka domain adaptation o:-)

"select" gets often tagged as adjectives, as in "select OK", so we set it to VB

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

