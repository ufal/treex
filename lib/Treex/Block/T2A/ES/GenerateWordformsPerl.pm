package Treex::Block::T2A::ES::GenerateWordformsPerl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::Generation::ES;

has generator => ( is => 'rw' );


sub process_anode {
    my ( $self, $anode ) = @_;
    return if defined $anode->form;
    $anode->set_form($self->generator->best_form_of_lemma($anode->lemma, $anode->iset));
    return;
}

sub BUILD {
    my ( $self, $argsref ) = @_;
	$self->set_generator(Treex::Tool::Lexicon::Generation::ES->new($argsref));
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::GenerateWordformsPerl - simple pure-Perl implementation

=head1 DESCRIPTION

just a draft of Spanish verbal conjugation

(placeholder for T2A::PT::GenerateWordforms which uses Flect)


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
