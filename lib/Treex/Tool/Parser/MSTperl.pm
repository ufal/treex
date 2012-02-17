package Treex::Tool::Parser::MSTperl;

1;

__END__


=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl - pure Perl implementation of MST parser

=head1 DESCRIPTION

This is a Perl implementation of the MST Parser described in
McDonald et al.:
Non-projective Dependency Parsing using Spanning Tree Algorithms
2005
in Proc. HLT/EMNLP.

Treex::Tool::Parser::MSTperl contains an unlabelled parser C<Parser> and a dependency relation labeller C<Labeller>, which, if chained, provide a labelled dependency parser. Models necessary for these tools can be trained (C<TrainerLabelling>, C<TrainerUnlabelled>) or downloaded from ÚFAL (for Czech and English).

=head1 METHODS

=over 4

=item $parser->load_model('modelfile.model');

Loads an unlabelled and/or a labelled model (= sets feature weights)
using L<Treex::Tool::Parser::MSTperl::ModelBase/load>.

A model has to be loaded before sentences can be parsed.

=item $parser->parse_sentence($sentence);

Parses a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
sets the C<parent> field of each node (instance of
L<Treex::Tool::Parser::MSTperl::Node>), i.e. a word in the sentence, and also
returns these parents as an array reference.

Any parse information already contained in the sentence gets discarded
(explicitely, by calling
L<Treex::Tool::Parser::MSTperl::Sentence/copy_nonparsed>).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
