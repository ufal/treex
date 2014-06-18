package Treex::Block::A2N::EN::NameTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2N::NameTag';

has '+model' => ( default => 'data/models/nametag/en/english-conll-140408.ner' );

my %CONLL_TO_TREEX_TYPE = (
    PER => 'p_',
    LOC => 'g_',
    ORG => 'i_',
    MISC => 'o_',
);

after 'process_zone' => sub {
    my ( $self, $zone ) = @_;
    return if !$zone->has_ntree();
    my $ntree = $zone->get_ntree();
    foreach my $nnode ($ntree->get_descendants()){
        my $new_type = $CONLL_TO_TREEX_TYPE{$nnode->ne_type};
        $nnode->set_ne_type($new_type || $nnode->ne_type);
    }
    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::EN::NameTag - English named entity recognizer NameTag

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::A2N::NameTag> which adds the path to the
default model for English and renames the types of named entities:

  PER => 'p_',
  LOC => 'g_',
  ORG => 'i_',
  MISC => 'o_',

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
