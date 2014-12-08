package Treex::Block::T2A::NL::AddFormalSubject;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode() or return;

    return if ( $tnode->formeme !~ /v:.*fin/ );
    return if ( any { $_->formeme =~ /n:subj/ } $tnode->get_echildren() );

    # existential there
    if ( $tnode->t_lemma eq 'zijn' ) {

        my $aer = $anode->create_child(
            {
                lemma         => 'er',
                form          => 'er',
                afun          => 'Adv',
            }
        );
        $aer->shift_before_node($anode);
        $tnode->add_aux_anodes($aer);
    }

    # TODO passive? or should it be on the t-layer somehow as well ?
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddFormalSubject

=head1 DESCRIPTION

Adds a formal subject "er" in sentences with existential "zijn".

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
