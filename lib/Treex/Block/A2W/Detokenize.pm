package Treex::Block::A2W::Detokenize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has remove_final_space => ( is => 'ro', isa => 'Bool', default => 0 );

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree;
    my $sentence = "";
    foreach my $a_node ( $a_root->get_descendants( { ordered => 1 } ) ) {
        $sentence .= $a_node->form;
        $sentence .= " " if !$a_node->no_space_after;
    }
    if ($self->remove_final_space) {
        $sentence =~ s/ $//;
    }
    $zone->set_sentence($sentence);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2W::Detokenize

=head1 DESCRIPTION

Creates the target sentence string from analytical tree. It uses
no_space_afters attribute for (not)inserting spaces between tokens.

=head1 ATTRIBUTES

=over

=item remove_final_space

By default, a space is added at the end of each sentence. (This happens already
in tokenization -- the last token gets C<no_space_after=0>.)
Use C<remove_final_space=1> if you do not want to have the final space there.

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
