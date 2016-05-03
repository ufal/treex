package Treex::Block::A2W::ShowGazeteerItems;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    my $key = lc $anode->form;
    my $translation = $anode->get_bundle()->wild->{gazeteer_translations}->{$key};
    if (defined $translation) {
        $anode->set_form($translation);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::A2W::ShowGazeteerItems

=head1 DESCRIPTION

Show translation of gazeteer items, i.e. replace placeholders such as C<xxxitemaxxx> with the correct translation.
Translations are stored in a hashmap under bundle->wild->{gazeteer_translations} where the key is the placeholder string.

To be used after passing text preprocessed by L<W2A::HideGazeteerItems> through a translator, such as Moses.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
