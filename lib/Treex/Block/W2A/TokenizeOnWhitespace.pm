package Treex::Block::W2A::TokenizeOnWhitespace;
use Moose;
use Treex::Moose;
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

    foreach my $i ( ( 0 .. $#tokens ) ) {
        my $token = $tokens[$i];

        # delete the token from the begining of the sentence
        $sentence =~ s/^\Q$token\E//;

        # if there are no spaces left, the parameter no_space_after will be set to 1
        my $no_space_after = $sentence =~ /^\s/ ? 0 : 1;

        # delete this spaces
        $sentence =~ s/^\s+//;

        # create new a-node
        my $new_a_node = $a_root->create_child(
            form           => $token,
            no_space_after => $no_space_after,
            ord            => $i + 1,
        );
    }
    return 1;
}

1;

__END__

=over

=item Treex::Block::W2A::TokenizeOnWhitespace

Each sentence is split into a sequence of tokens.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class tokenizes only on whitespaces,
but it can be used as an ancestor for more apropriate tokenization
by overriding the method C<tokenize_sentence>.

=back

=cut

# Copyright 2011 David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
