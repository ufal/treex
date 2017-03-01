package Treex::Block::A2W::ES::ConcatenateTokens;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree();
    my $sentence = join ' ',
        map { $_->form || '' }
        $a_root->get_descendants( { ordered => 1 } );

    # Spanish contractions, e.g. "de_" + "el" = "del"
    $sentence =~ s/\b(de|a) el\b/$1l/g;    # del, al
    
    # "y" before words beginning with "i" or "hi" => "e"
    $sentence =~ s/ y (h?i)/ e $1/g;

    # "o" before words beginning with "o" or "ho" => "u"
    $sentence =~ s/ o (h?o)/ u $1/g;

    # TODO: detached clitic, e.g. "da" + "-se-" + "-lo" = "dá-se-lo"

    $sentence =~ s/ +/ /g;
    $sentence =~ s/ ([’”!,.?:;])/$1/g;
    $sentence =~ s/([‘“¿¡]) /$1/g;

    $sentence =~ s/ ?([\.,]) ?([’”"])/$1$2/g;    # spaces around punctuation

    $sentence =~ s/ -- / – /g;

    $sentence =~ s/_/ /g;                            # this shouldn't happen

    # no space (or even commas) inside parentheses
    $sentence =~ s/,?\(,? ?/\(/g;
    $sentence =~ s/ ?,? ?\)/\)/g;


    # (The whole sentence is in parenthesis).
    # (The whole sentence is in parenthesis.)
    if ( $sentence =~ /^\(/ ) {
        $sentence =~ s/\)\./.)/;
    }
    
    # HACKS:
    $sentence =~ s/`` ?/"/g;
    $sentence =~ s/ ?''/"/g;

    $zone->set_sentence($sentence);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::ES::ConcatenateTokens

=head1 DESCRIPTION

Creates a sentence as a concatenation of a-nodes, removing spacing where needed.

Handling Spanish contractions (e.g. "de" + "el" = "del").

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.eus>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
