package Treex::Block::Write::CoNLLX;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

has '+language' => ( required => 1 );
has 'deprel_attribute' => ( is => 'rw', isa => 'Str', default => 'conll/deprel');
has 'pos_attribute' => ( is => 'rw', isa => 'Str', default => 'conll/pos');
has 'cpos_attribute' => ( is => 'rw', isa => 'Str', default => 'conll/cpos');

sub process_atree {
    my ( $self, $atree ) = @_;
    foreach my $anode ( $atree->get_descendants( { ordered => 1 } ) ) {
        my ( $lemma, $pos, $cpos, $deprel, $afun ) =
            map { defined $anode->get_attr($_) ? $anode->get_attr($_) : '_' }
            ('lemma', $self->pos_attribute, $self->cpos_attribute, $self->deprel_attribute);
        #my $ctag  = $self->get_coarse_grained_tag($tag);
        my $p_ord = $anode->get_parent->ord;
        print { $self->_file_handle } join( "\t", $anode->ord, $anode->form, $lemma, $cpos, $pos, '_', $p_ord, $deprel ) . "\n";
    }
    print { $self->_file_handle } "\n" if $atree->get_descendants;
    return;
}

sub get_coarse_grained_tag {
    my ( $self, $tag ) = @_;
    return substr $tag, 0, 2;
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLLX

=head1 DESCRIPTION

Document writer for CoNLLX format, one token per line.

=head1 ATTRIBUTES

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=item

The name of attribute which will be printed into the 7th column (dependency relation).
Default is C<conll/deprel>.

=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

David Mareček

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
