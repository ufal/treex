package Treex::Block::Write::CoNLLX;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

has '+language' => ( required => 1 );

sub process_atree {
    my ( $self, $atree ) = @_;
    foreach my $anode ($atree->get_descendants({ordered => 1})) {
        my $lemma = $anode->lemma;
        $lemma = '_' if !defined $lemma;
        my @token = ($anode->ord, $anode->form, $lemma, $anode->tag, $anode->tag, '_', $anode->get_parent->ord, $anode->conll_deprel);
        print join("\t", @token) . "\n";
    }
    print "\n";
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
