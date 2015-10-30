package Treex::Block::A2T::EN::FixAdjNattrN;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ( $troot->get_descendants ) {
        my $parent = $tnode->get_parent;
        if (( $tnode->formeme || "" ) =~ /^adj:/
                and (($parent->formeme || "") =~ /^n:attr/ )
                and $tnode->precedes($parent)) {
            while (($parent->formeme || "") =~ /^n:attr/ and
                   ($parent->get_parent->formeme || "") =~ /^n:/ and
                    $tnode->precedes($parent)) {
                $parent = $parent->get_parent;
            }
            $tnode->set_parent($parent);
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::FixAdjNattrN

=head1 DESCRIPTION

    Change dependency like:
        Adj -> NAttr1 -> N2

    Into a flatter tree:
        Adj -> N2
        NNAttr1 -> N2


=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
