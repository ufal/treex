package Treex::Block::T2A::CS::AddSentFinalPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSentFinalPunct';

has '+open_punct' => ( default => '[‚„\']' );

has '+close_punct' => ( default => '[‘“\']' );

override 'postprocess' => sub {
    my ( $self, $a_punct ) = @_;

    #!!! dirty traversing of the pyramid at the lowest level
    # in order to distinguish full sentences from titles and imperatives
    # TODO: source language dependent code in synthesis!!!
    my $en_zone = $a_punct->get_bundle->get_zone( 'en', 'src' );

    if ($en_zone && $en_zone->sentence){
        if ($en_zone->sentence =~ /!$/ ) {
            $a_punct->set_form('!');
        }
        if ($a_punct->form eq '.' && $en_zone->sentence !~ /\./){
            $a_punct->remove();
        }
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::AddSentFinalPunct

=head1 DESCRIPTION

Add a-nodes corresponding to sentence-final punctuation mark.

Note: Contains hacks specific to EN-CS translation!
Note: final punctuation of direct speech is not handled yet!

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
