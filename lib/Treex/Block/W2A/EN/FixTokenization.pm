package Treex::Block::W2A::EN::FixTokenization;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

my %MERGE_FOR = (
    'a . m .' => 'a. m.',
    'p . m .' => 'p. m.',
    'U . S .' => 'U. S.',
    'e . g .' => 'e. g.',
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
        #    $nodes[ $i + 1 ]->disconnect();
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
            foreach my $node ( @nodes[ $i + 1 .. $i + $length ] ) {
                $node->disconnect();
            }
            $i += $length;
        }
    }
    return 1;
}

1;

__END__

=over

=item Treex::Block::W2A::EN::FixTokenization

Some abbreviations (with periods) are merged into one token.
For example I<"e. g."> is in Penn Treebank one token (with tag FW).
Using only L<SEnglishW_to_SEnglishM::Penn_style_tokenization>
we get four tokens: I<e . g .> which may be distributed by the parser
into different clauses. And this is hard to fix afterwards.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
