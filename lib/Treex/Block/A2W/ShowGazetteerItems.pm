package Treex::Block::A2W::ShowGazetteerItems;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_zone {
    my ($self, $zone) = @_;

    my $bundle = $zone->get_bundle();
    my $sentence = $zone->sentence;
    foreach my $key (keys %{$bundle->wild->{gazetteer_translations}}) {
        my $replacement = $bundle->wild->{gazetteer_translations}->{$key};
        $sentence =~ s/$key/$replacement/i;
    }
    $zone->set_sentence($sentence);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::A2W::ShowGazeteerItems

=head1 DESCRIPTION

Show translation of gazetteer items, i.e. replace placeholders such as C<xxxitemaxxx> with the correct translation.
Translations are stored in a hashmap under bundle->wild->{gazetteer_translations} where the key is the placeholder string.

To be used after passing text preprocessed by L<W2A::HideGazeteerItems> through a translator, such as Moses.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
