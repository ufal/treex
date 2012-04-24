package Treex::Block::Write::LemmatizedBitexts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has to_language => ( is => 'ro', isa => 'Str', required => 1 );
has to_selector => ( is => 'ro', isa => 'Str', default  => '' );

sub process_atree {
    my ( $self, $a_root ) = @_;
    my $bundle = $a_root->get_bundle;
    print { $self->_file_handle } $bundle->get_document->loaded_from . "-" . $bundle->id . "\t";

    print { $self->_file_handle }
        join(
        " ",
        map { my $l = $_->lemma; $l =~ s/\s/_/g; $l; }
            $a_root->get_descendants( { ordered => 1 } )
        ) . "\t";
    
    print { $self->_file_handle }
        join(
        " ",
        map { my $l = $_->lemma; $l =~ s/\s/_/g; $l; }
            $bundle->get_tree( $self->to_language, 'a', $self->to_selector )->get_descendants( { ordered => 1 } )
        ) . "\n";
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LemmatizedBitexts

=head1 DESCRIPTION

Writer for a tab-separated format containing sentence id, source language sentence (lemmas), and target language
sentence (lemmas) for GIZA++ alignment.

=head1 PARAMETERS

=over 

=item C<encoding>

The output encoding, C<utf8> by default.

=item C<language>

The first sentence language.

=item C<selector>

The first sentence selector.

=item C<to_language>

The second sentence language.

=item C<to_selector>

The second sentence selector.

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.