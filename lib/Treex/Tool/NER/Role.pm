package Treex::Tool::NER::Role;
use Moose::Role;

requires 'find_entities';

1;

__END__

=head1 NAME

Treex::Tool::NER::Role - role for named entity recognizers

=head1 SYNOPSIS

 use Treex::Tool::NER::NameTag;
 my $ner = Treex::Tool::NER::NameTag->new(
    model => 'data/models/nametag/cs/czech-cnec2.0-140304.ner',
 );

 my @tokens = qw(hádání Prahy s Kutnou Horou zničilo Zikmunda Lucemburského);
 my $entities_rf = $ner->find_entities(\@tokens);
 for my $entity (@$entities_rf) {
     my $entity_string = join ' ', @tokens[$entity->{start} .. $entity->{end}];
     print "type=$entity->{type} entity=$entity_string\n";
 }

=head1 REQUIRED METHOD

=head2 my entities_rf = $parser->find_entities(\@forms);

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
