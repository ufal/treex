package Treex::Block::A2A::CS::RemoveFeaturesFromLemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Block::HamleDT::CS::Harmonize;
my $harmonize_block = Treex::Block::HamleDT::CS::Harmonize->new();

sub process_atree {
    my ($self, $atree) = @_;
    $harmonize_block->remove_features_from_lemmas($atree);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::RemoveFeaturesFromLemmas - store lemma features as wild attributes

=head1 DESCRIPTION

The real implementation is in the method C<remove_features_from_lemmas>
in block L<Treex::Block::HamleDT::CS::Harmonize>.

=head1 SEE ALSO

L<Treex::Block::A2A::CS::TruncateLemma> an alternative solution which does not store the features as wild attributes

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


