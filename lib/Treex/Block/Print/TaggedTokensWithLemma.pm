package Treex::Block::Print::TaggedTokensWithLemma;
use Treex::Core::Common;
use Moose;
extends 'Treex::Block::Write::BaseTextWriter';

has 'attrribute' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has 'format' => (
	is => 'rw',
	isa => 'Str',
	default => 'flt'
);

has 'factor' => (
    is => 'rw',
    isa => 'Bool',
    default => 1
);

has 'pos_attribute' => (
	is => 'ro',
	isa => 'Str',
	default => 'tag'
);

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    my @nodes = $tree->get_descendants({'ordered' => 1});
    # Prepare the output sequence for the sentence.
    my @tokens;
    foreach my $node (@nodes)
    {
        my $complex_tag = q();
        map {$complex_tag .= $node->get_attr($_);} split (/\+/, $self->pos_attribute());
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        # factor 1 ... form|lemma|tag, sentence on one line
        # factor 0 ... form\tlemma\ttag, token on one line, sentences delimited by blank line
        # flt ... form lemma tag
        # ftl ... form tag lemma
        if($self->factor())
        {
            # Escape characters that are dangerous for the factored output format.
            foreach my $x ($form, $lemma, $complex_tag)
            {
                $x =~ s/&/&amp;/g;
                $x =~ s/\|/&pipe;/g;
                $x =~ s/</&lt;/g;
                $x =~ s/>/&gt;/g;
            }
            if($self->format() eq 'flt')
            {
                push(@tokens, "$form|$lemma|$complex_tag");
            }
            elsif($self->format() eq 'ftl')
            {
                push(@tokens, "$form|$complex_tag|$lemma");
            }
        }
        else
        {
            if($self->format() eq 'flt')
            {
                push(@tokens, "$form\t$lemma\t$complex_tag");
            }
            elsif($self->format() eq 'ftl')
            {
                push(@tokens, "$form\t$complex_tag\t$lemma");
            }
        }
    }
    if($self->factor())
    {
        print {$self->_file_handle()} (join(' ', @tokens), "\n");
    }
    else
    {
        print {$self->_file_handle()} (join("\n", @tokens), "\n\n");
    }
    return;
}

1;

__END__


=encoding utf-8

=head1 NAME

Print::TaggedTokensWithLemma – ported from TectoMT block Print::Tagged_tokens_with_lemma LANGUAGE=xx

=head1 DESCRIPTION

Print triples of token, its lemma and morphological tag from a-tree.

Two main output formats are supported.
C<factor 1> (default): one sentence per line, tokens separated by whitespace, factors separated by vertical bar.
C<factor 0>: one token per line, factors separated by tabs, sentences separated by blank line.

=head2 PARAMETERS

=item C<format>

The C<format> parameter allows the data to be printed in different formats often suitable for feeding the Parts
of Speech taggers. The C<format> paramter can take 2 possible values: (i) 'flt' - which is the default value and the prints
the data in 'form \t lemma \t tag' and (ii) 'ftl' - prints the data in 'form \t tag \t lemma'.

=item C<pos_attribute>
Allows the user to combine various tags into a single complex tag. For example, one may want to combine I<coarse grained> and I<fine grained>
POS into a single tag, in that case, specifying C<pos_attribute> as 'conll/cpos+conll/pos' would concatenate them into a single tag. The default value
is 'tag'.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
