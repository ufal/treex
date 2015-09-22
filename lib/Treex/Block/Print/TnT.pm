package Treex::Block::Print::TnT;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'pos_attribute' => ( is      => 'rw',
                         isa     => 'Str',
                         default => 'iset_pos',
                     );

sub process_atree {
    my $self = shift;
    my $a_root = shift;
    for my $anode ( $a_root->get_descendants( { ordered => 1 } ) ) {
        my $form = $anode->form() || '_';
        my $pos;
        if ($self->pos_attribute eq 'iset_pos') {
            $pos = $anode->get_iset('pos') || '_';
        }
        elsif ($self->pos_attribute eq 'iset_feat') {
            $pos = $anode->iset()->as_string_conllx();
        }
        elsif ($self->pos_attribute eq 'conll_pos') {
            $pos = $anode->conll_pos() || '_';
        }
        elsif ($self->pos_attribute eq 'conll_cpos') {
            $pos = $anode->conll_cpos() || '_';
        }
        elsif ($self->pos_attribute eq 'conll_feat') {
            $pos = $anode->conll_feat() || '_';
        }

        print join("\t",
                   $form, $pos,
               ), "\n";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::ExtractTnT;

=head1 DESCRIPTION

Prints the sentences in the TnT format (wordform and tag separated by a tab, one token per line).

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
