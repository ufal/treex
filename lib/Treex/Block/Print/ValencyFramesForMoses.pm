package Treex::Block::Print::ValencyFramesForMoses;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.txt' );


sub process_tnode {

    my ( $self, $tnode ) = @_;

    my $val_frame = $tnode->val_frame_rf;

    return if (!$val_frame);

    my $id = $tnode->root->id;
    $id =~ s/^t_tree-..-//;
    $id =~ s/-root$//;

    my ($part) = ($id =~ /(train|dtest|etest)/);

    my $lex_a = $tnode->get_lex_anode();

    print { $self->_file_handle } join("\t", ($id, $part, $lex_a->lemma, $lex_a->ord, $val_frame)), "\n";
}


1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::ValencyFramesForMoses

=head1 DESCRIPTION

Print valency frame IDs for verbs in the given data, in a tab-separated format. The individual
columns are: sentence ID, train/dtest/etest, lemma, token ordinal number within the sentence,
valency frame ID.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
