package Treex::Block::Write::LayerAttributes::Order;
use Moose;
use Treex::Core::Common;
use Scalar::Util qw(looks_like_number);

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );


sub modify_single {

    my ( $self, $ord1, $ord2 ) = @_;

    return undef if ( !List::MoreUtils::all { defined($_) && looks_like_number($_) } ( $ord1, $ord2 ) );

    if ( $ord1 < $ord2 ){
        return 'before';
    }
    elsif ( $ord1 == $ord2 ){
        return 'same';
    }
    else {
        return 'after';
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::Order

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::Order->new(); 

    print $modif->modify_all( $node1->ord, $node2->ord ); # prints 'before' (if node1 goes before node2), 'same' or 'after'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes two numeric arguments 
and returns their order -- this is useful if you need to tell which of the two nodes comes first in the sentecne.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
