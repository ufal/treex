package Treex::Block::A2W::EN::DeleteTracesFromSentence;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_atree {
    my ( $self, $a_root ) = @_;
    my @nodes = $a_root->get_descendants( { ordered => 1 } );
    my @form           = map { $_->form } @nodes;
    my @no_space_after = map { $_->no_space_after } @nodes;
    my @tag            = map { $_->tag } @nodes;
    my $sentence       = '';
    foreach my $i ( 0 .. $#form ) {
        if ( $tag[$i] ne '-NONE-' ) {
            $sentence .= ' ' if $i > 0 && !$no_space_after[ $i - 1 ];
            $sentence .= $form[$i];
        }
    }
    $a_root->get_zone->set_sentence($sentence);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::DeleteTracesFromSentence

=head1 DESCRIPTION

Deletes all traces (nodes with tag '-NONE-') from the attribut 'sentence'.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
