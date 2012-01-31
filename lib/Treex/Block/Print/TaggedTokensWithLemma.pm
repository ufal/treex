package Treex::Block::Print::TaggedTokensWithLemma;
use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

has 'attrribute' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    my @nodes = $tree->get_descendants({'ordered' => 1});
    print(join('', map
    {
        $_->form()."\t".$_->lemma()."\t".$_->tag()."\n";
    }
    (@nodes)), "\n");
    return;
}

1;

__END__


=encoding utf-8

=head1 NAME

Print::Tagged_tokens_with_lemma – ported from TectoMT block Print::Tagged_tokens_with_lemma LANGUAGE=xx

=head1 DESCRIPTION

Print triples of token, its lemma and morphological tag from a-tree.
Sentences are separated by an empty line.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
