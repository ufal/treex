package Treex::Block::A2W::EN::ConcatenateTokens;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree();
    my $sentence = join ' ',
        grep { !/#[A-Z]/ and !/^\-[A-Z]{3}\-$/ }
        map { $_->form || '' }
        $a_root->get_descendants( { ordered => 1 } );

    $sentence =~ s/ +/ /g;
    $sentence =~ s/ ([!,.?:;])/$1/g;
    $sentence =~ s/(["”’])\./\.$1/g;
    $sentence =~ s/ ([’”])/$1/g;
    $sentence =~ s/([‘“]) /$1/g;

    $sentence =~ s/ ?([\.,]) ?([’”"])/$1$2/g;    # spaces around punctuation

    $sentence =~ s/ -- / – /g;

    $sentence =~ s/_/ /g;                            # this shouldn't happen

    # parentheses
    $sentence =~ s/,?\(,? ?/\(/g;
    $sentence =~ s/ ?,? ?\)/\)/g;

    # (The whole sentence is in parenthesis).
    # (The whole sentence is in parenthesis.)
    if ( $sentence =~ /^\(/ ) {
        $sentence =~ s/\)\./.)/;
    }
    
    # English clitics
    $sentence =~ s/(\p{Alpha}+) (\'(ll|ve|re|[dsm])|n\'t)/$1$2/g;
    $sentence =~ s/can not/cannot/g;

    $zone->set_sentence($sentence);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::ConcatenateTokens

=head1 DESCRIPTION

Creates a sentence as a concatenation of a-nodes, removing spacing where needed.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
