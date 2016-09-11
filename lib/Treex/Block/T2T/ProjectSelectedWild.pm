package Treex::Block::T2T::ProjectSelectedWild;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tst_tnode) = @_;
    my $src_tnode = $tst_tnode->src_tnode;

    if (defined $src_tnode->wild->{check_comma_after}) {
        $tst_tnode->wild->{check_comma_after} = $src_tnode->wild->{check_comma_after};
    }
}

1;

