package Treex::Block::A2W::CapitalizeSentStart;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;
    
    my $first_word = first {$_->form !~ /^[[:punct:]„«‹“¿¡]*$/} $a_root->get_children( { ordered => 1 } );
    return if !$first_word || !defined $first_word->form || lc($first_word->form) ne ($first_word->form);
    $first_word->set_form(ucfirst $first_word->form);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2W::CapitalizeSentStart

=head1 DESCRIPTION

Capitalize the first letter of the first (non-punctuation) token in the sentence.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
