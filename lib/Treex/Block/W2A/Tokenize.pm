package Treex::Block::W2A::Tokenize;
use utf8;
use Moose;
use Treex::Moose;;
extends 'Treex::Core::Block';

sub tokenize_sentence {
    my ($self, $sentence) = @_;

    # first off, add a space to the beginning and end of each line, to reduce necessary number of regexps.
    $sentence =~ s/$/ /;
    $sentence =~ s/^/ /;
    
    # the following characters (double-characters) are separated everywhere
    $sentence =~ s/(;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|—|„|‚)/ $1 /g;

    # short hyphen is separated if it is followed or preceeded by non-alphanuneric character and is not a part of --
    $sentence =~ s/([^\-\w])\-([^\-])/$1 - $2/g;
    $sentence =~ s/([^\-])\-([^\-\w])/$1 - $2/g;
    
    # apostroph is separated if it is followed or preceeded by non-alphanumeric character, is not part of '', and is not followed by a digit (e.g. '60).
    $sentence =~ s/([^\'’\w])([\'’])([^\'’\d])/$1 $2 $3/g;
    $sentence =~ s/([^\'’])([\'’])([^\'’\w])/$1 $2 $3/g;

    # dot, comma, slash, and colon are separated if they do not connect two numbers
    $sentence =~ s/(\D|^)([\.,:\/])/$1 $2 /g;
    $sentence =~ s/([\.,:\/])(\D|$)/ $1 $2/g;

    # three dots belong together
    $sentence =~ s/\.\s*\.\s*\./.../g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^ *//g;
    $sentence =~ s/ *$//g;

    return $sentence;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    # create a-tree
    my $a_root = $zone->create_tree('A');

    # get the source sentence and tokenize
    my $sentence = $zone->sentence;
    $sentence =~ s/^\s+//;
    log_fatal("No sentence to tokenize!") if !defined $sentence;
    my @tokens = split ( /\s/, $self->tokenize_sentence($sentence) );

    foreach my $i ( ( 0 .. $#tokens ) ) {
        my $token = $tokens[$i];
        
        # delete the token from the begining of the sentence
        $sentence =~ s/^\Q$token\E//;
        # if there are no spaces left, the parameter no_space_after will be set to 1
        my $no_space_after = $sentence =~ /^\s/ ? 0 : 1;
        # delete this spaces
        $sentence =~ s/^\s+//;

        # create new a-node
        my $new_a_node = $a_root->create_child;
        $new_a_node->set_attr( 'form', $token );
        $new_a_node->set_attr( 'no_space_after', $no_space_after );
        $new_a_node->set_attr( 'ord', $i + 1 );
    }
    return 1;
}

1;

__END__

=over

=item Treex::Block::W2A::Tokenize

Each sentence is split into a sequence of tokens using a series of regepxs.
Analytical tree is build and attributes C<no_space_after> are filled.

=back

=cut

# Copyright 2010-2011 David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
