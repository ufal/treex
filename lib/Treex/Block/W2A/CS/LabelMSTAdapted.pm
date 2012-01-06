package Treex::Block::W2A::CS::LabelMSTAdapted;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Parser::MST::Czech;

has 'model' => ( is => 'rw', isa => 'Str' );

my $parser;

sub BUILD {
    my ($self) = @_;
    $parser = Parser::MST::Czech->new() if !$parser;
    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    my @words = map { $_->form } @a_nodes;
    my @tags  = map { $_->tag } @a_nodes;

    my ( $parents_rf, $afuns_rf ) = $parser->parse_sentence( \@words, \@tags );

    unshift @a_nodes, $a_root;

    foreach my $ord ( 1 .. $#a_nodes ) {
        my $afun       = shift @$afuns_rf;
        if ( $afun =~ s/_.+// ) {
            $a_nodes[$ord]->set_is_member(1);
        }
        $a_nodes[$ord]->set_afun($afun);
    }
}

1;

__END__
 
=over

=item Treex::Block::W2A::CS::LabelMSTAdapted 

Parses analytical trees using McDonald's MST parser adapted by Zdenek Zabokrtsky and Vaclav Novak.

Discards information about the determined tree structure and only sets the afuns.

=back

=cut

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by David Marecek, turned into an afun labeller by Rudolf Rosa

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
