package Treex::Block::W2A::TokenizeOnWhitespace;

use strict;
use warnings;
use Moose;
use utf8;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub tokenize_sentence {
    my ( $self, $sentence ) = @_;
    return $sentence;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    # create a-tree
    my $a_root = $zone->create_atree();

    # get the source sentence and tokenize
    my $sentence = $zone->sentence;
    $sentence =~ s/^\s+//;
    log_fatal("No sentence to tokenize!") if !defined $sentence;
    my @tokens = split( /\s/, $self->tokenize_sentence($sentence) );

    # Create a-nodes and detect the no_space_after attribute.
    foreach my $i ( ( 0 .. $#tokens ) ) {
        my $token = $tokens[$i];

        # By default, there is a space after each token.
        my $no_space_after = 0;

        # Delete the token from the begining of the sentence.
        if ($sentence =~ s/^\Q$token\E//){
            # This is the expected case. The sentence starts with the $token.
            # If it is followed by a space, delete the space and set no_space_after=1.
            $no_space_after = 1 if length($sentence) && $sentence !~ s/^\s+//;
        } elsif ($i < $#tokens) {
            # The token (returned from tokenization) does not match the start of sentence.
            # E.g. '. . . word' is tokenized as  '... word'.
            # Let's delete the start of sentence anyway,
            # using a non-greedy regex and the expected next token returned from the tokenization.
            my $next_token = $tokens[$i+1];
            my ($first, $rest) = ($sentence =~ /^(.*?)(\Q$next_token\E.*)$/);
            $no_space_after = 1 if $first !~ /\s$/;
            $sentence = $rest;
        }

        # create new a-node
        $a_root->create_child(
            form           => $token,
            no_space_after => $no_space_after,
            ord            => $i + 1,
        );
    }
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TokenizeOnWhitespace - Base tokenizer, splits on whitespaces, fills no_space_after

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class tokenizes only on whitespaces,
but it can be used as an ancestor for more apropriate tokenization
by overriding the method C<tokenize_sentence>.

=head1 METHODS

=over 4

=item tokenize_sentence()

this method can be overridden in more advanced tokenizers

=item process_zone()

this method does all work of this tokenizer

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
