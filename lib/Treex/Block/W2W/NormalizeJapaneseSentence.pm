package Treex::Block::W2W::NormalizeJapaneseSentence;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_zone {
    my ( $self, $zone ) = @_;

    # get the source sentence and normalize
    my $sentence = $zone->sentence;
    $sentence =~ s/^\s+//;
    log_fatal("No sentence to normalize!") if !defined $sentence;
    my $outsentence = $self->normalize_sentence($sentence);

    $zone->set_sentence($outsentence);
    return 1;
}

sub normalize_sentence {
    my ( $self, $s ) = @_;

    # numbers
    $s =~ s/０/0/g;
    $s =~ s/１/1/g;
    $s =~ s/２/2/g;
    $s =~ s/３/3/g;
    $s =~ s/４/4/g;
    $s =~ s/５/5/g;
    $s =~ s/６/6/g;
    $s =~ s/７/7/g;
    $s =~ s/８/8/g;
    $s =~ s/９/9/g;

    # whitespace
    #$s =~ s/\x{00A0}/ /g;  # nbsp
    #$s =~ s/[&%]\s*nbsp\s*;/ /gi;  # nbsp
    #$s =~ s/\s+/ /g;

    return $s;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::NormalizeJapaneseSentence - Modifies Japanese sentence in place

=head1 DESCRIPTION

Modify japanese_source_sentence in place for a better normalization.
E.g. Substitute numbers in japanese utf-8 (１,２,３) with their ascii equivalent.

=head1 METHODS

=over 4

=item normalize_sentence()

this method can be overridden in more advanced normalizers

=item process_zone()

this loops over all sentences

=back

=head1 TODO

Should we do this for other ascii characters or japanese whitespaces?

=head1 AUTHOR

Ondrej Bojar <bojar@ufal.mff.cuni.cz>
Dusan Varis <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
