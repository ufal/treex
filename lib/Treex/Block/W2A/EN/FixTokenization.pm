package Treex::Block::W2A::EN::FixTokenization;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %MERGE_FOR = (
    'a . m .' => 'a. m.',
    'p . m .' => 'p. m.',
    'U . S .' => 'U. S.',
    'e . g .' => 'e. g.',
    'i . e .' => 'i. e.',
    'Mrs .'   => 'Mrs.',
    'Mr .'    => 'Mr.',
    'Ms .'    => 'Ms.',
    'Dr .'    => 'Dr.',
    'km / h'  => 'km/h',
    'm / s'   => 'm/s',
);

#TODO (MP): rewrite this block

sub process_atree {
    my ( $self, $atree ) = @_;

    my @nodes      = $atree->get_children();
    my @forms      = map { $_->form } @nodes;
    my $max_length = 3;
    push @forms, map {'dummy'} ( 1 .. $max_length );

    TOKEN:
    foreach my $i ( 0 .. $#nodes - 1 ) {

        # No more needed with SEnglishW_to_SEnglishM::Tokenization
        # "10 th" -> "10th" (one token is better for parser and transfer)
        #if ( $forms[ $i + 1 ] =~ /^(st|nd|rd|th)$/ && $forms[$i] =~ /^\d+$/ ) {
        #    ##warn "merging $forms[$i]th\n";
        #    $nodes[$i]->set_form($forms[$i] . 'th' );
        #    $nodes[$i]->set_attr( 'gloss', 'merged' );
        #    $nodes[ $i + 1 ]->remove();
        #    $i += 1;
        #    next TOKEN;
        #}

        LENGTH:
        foreach my $length ( reverse( 1 .. $max_length ) ) {
            my $string = join ' ', @forms[ $i .. $i + $length ];
            my $merged = $MERGE_FOR{$string};

            next LENGTH if !defined $merged;

            #warn "merging $merged\n";
            $nodes[$i]->set_form($merged);
            $nodes[$i]->set_attr( 'gloss', 'merged' );
            $nodes[$i]->set_no_space_after( $nodes[ $i + $length ]->no_space_after );

            foreach my $node ( @nodes[ $i + 1 .. $i + $length ] ) {
                $node->remove();
            }
            $i += $length;
        }
    }
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::FixTokenization - fix some issues in output of tokenizer

=head1 DESCRIPTION

Some abbreviations (with periods) are merged into one token.
For example I<"e. g."> is in Penn Treebank one token (with tag FW).
Using only L<Treex::Block::W2A::EN::Tokenize>
we get four tokens: I<e . g .> which may be distributed by the parser
into different clauses. And this is hard to fix afterwards.

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_atree

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

