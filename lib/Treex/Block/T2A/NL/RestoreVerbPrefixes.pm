package Treex::Block::T2A::NL::RestoreVerbPrefixes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {

    my ( $self, $anode ) = @_;

    return if ( !$anode->wild->{verbal_prefix} );    
    $anode->set_form($anode->wild->{verbal_prefix} . $anode->form);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::RestoreVerbPrefixes

=head1 DESCRIPTION

Verbal separable prefixes are restored after morphology generation.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
