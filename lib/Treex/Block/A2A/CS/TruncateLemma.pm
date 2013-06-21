package Treex::Block::A2A::CS::TruncateLemma;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
extends 'Treex::Core::Block';

has delete_number => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'delete also the numbers distinguishing homonyms',
);

sub process_anode {
    my ( $self, $anode ) = @_;
    $anode->set_lemma(Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, $self->delete_number));
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CS::TruncateLemma - delete technical suffixes from lemmas

=head1 SYNOPSIS

 A2A::CS::TruncateLemma delete_number=1

=head1 DESCRIPTION

Czech morphological lemmas contain several useful types of information in technical suffixes.
For example,
I<Bonn_;G> (G means geographical named entity),
I<vazba-1_^(obviněného)> ("-1" is a number distinguishing homonyms, "^" starts a comment),
I<vazba-2_^(spojení)>.
This block deletes the technical suffixes,
so only the proper lemma (I<Bonn, vazba-1, vazba-2>) is left in the C<lemma> attribute.
When used with parameter C<delete_number=1>, the result is I<Bonn, vazba, vazba>.

Note then if the truncation is needed only for printing via Write::AttributeSentences, you can use

 Write::AttributeSentences layer=a attributes='CzechMLemmaTrunc(lemma)'
 
instead of

 A2A::CS::TruncateLemma delete_number=1 Write::AttributeSentences layer=a attributes=lemma

=head1 SEE ALSO

L<Treex::Tool::Lexicon::CS>

L<Treex::Block::Write::LayerAttributes::CzechMLemmaTrunc>

L<http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/m-layer/html/ch02s01.html>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
