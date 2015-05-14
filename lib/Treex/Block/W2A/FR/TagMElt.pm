package Treex::Block::W2A::FR::TagMElt;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;

use Treex::Tool::Tagger::MElt;

extends 'Treex::Block::W2A::Tag';

sub _build_tagger {
    my ($self) = @_;
    return Treex::Tool::Tagger::MElt->new();
}

after 'process_atree' => sub {
    my ($self, $atree) = @_;

    foreach my $anode ($atree->get_descendants({ordered=>1})) {
        my $merged_tag = $anode->tag;
        my ($cpos, $pos, $feats) = split / /, $merged_tag;
        $anode->set_conll_pos($pos);
        $anode->set_conll_cpos($cpos);
        $anode->wild->{mfeats} = $feats;
    }
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::FR::TagStanford

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::W2A::TagStanford> which adds the path to the
default model for French.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
