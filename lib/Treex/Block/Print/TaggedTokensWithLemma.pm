package Treex::Block::Print::TaggedTokensWithLemma;
use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

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

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    my @nodes = $tree->get_descendants({'ordered' => 1});
    
	# 'flt' - form \t lemma \t tag
    if ($self->format eq 'flt') {
	    print(join('', map
	    {
	        $_->form()."\t".$_->lemma()."\t".$_->tag()."\n";
	    }
	    (@nodes)), "\n");    	
    }
	# 'ftl' - form \t tag \t lemma    
    elsif ($self->format eq 'ftl') {
	    print(join('', map
	    {
	        $_->form()."\t".$_->tag()."\t".$_->lemma()."\n";
	    }
	    (@nodes)), "\n");       	
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
Sentences are separated by an empty line.

=head2 PARAMETERS

=item C<format>

The C<format> parameter allows the data to be printed in different formats often suitable for feeding the Parts 
of Speech taggers. The C<format> paramter can take 2 possible values: (i) 'flt' - which is the default value and the prints
the data in 'form \t lemma \t tag' and (ii) 'ftl' - prints the data in 'form \t tag \t lemma'.      


=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
