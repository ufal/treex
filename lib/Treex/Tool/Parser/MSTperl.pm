package Treex::Tool::Parser::MSTperl;

1;

__END__


=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl - a non-projective dependency natural language 
parser (pure Perl implementation of the MST parser)

=head1 SYNOPSIS

Analysis of a Czech sentence "Martin jde po ulici." ("Martin walks on the 
street."), in case only the word forms are available (i.e. you do not have a 
tagger which would provide you with the POS tags and/or lemmas).

in shell (or in any other way):

 # Download the config file
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/cs/pdt_form.config
 # Download and ungzip the unlabelled parsing model
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/cs/pdt_form.model.gz
 gunzip pdt_form.model.gz
 # Download and ungzip the deprel labelling model
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/labeller_mira/cs/pdt_form.lmodel.gz
 gunzip pdt_form.lmodel.gz

(this model uses only the wordforms to build dependency trees)

in perl:

 my @words = ('Martin', 'jde', 'po', 'ulici', '.');
 
 use Treex::Tool::Parser::MSTperl::Config;
 use Treex::Tool::Parser::MSTperl::Node;
 use Treex::Tool::Parser::MSTperl::Sentence;
 use Treex::Tool::Parser::MSTperl::Parser;
 use Treex::Tool::Parser::MSTperl::Labeller;
 
 # Initialize the Config object from an appropriate config file;
 # this object is passed to all other objects on creation to provide access to the settings
 my $config = Treex::Tool::Parser::MSTperl::Config->new( config_file => 'pdt_form.config' );
 
 # Create the Node objects representing the individual words
 my @nodes;
 foreach my $word (@words) {
    my $node = Treex::Tool::Parser::MSTperl::Node->new( config => $config, fields => [$word] );
    push @nodes, $node;
 }
 
 # Create the Sentence object representing the whole sentence
 my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new( config => $config, nodes => \@nodes );
 
 # Initialize the parser
 my $parser = Treex::Tool::Parser::MSTperl::Parser->new( config => $config );
 # Load the unlabelled parsing model
 $parser->load_model( 'pdt_form.model' );
 
 # Parse the sentence (returns an array reference)
 my $parents = $parser->parse_sentence( $sentence );
 
 # Now $parents contains 1-based indexes of words that are parents... well, look:
 # (0 stands for the root)
 
 # Let's see:
 print "edges in the dependency tree (child -> parent):\n";
 for (my $i = 0; $i < @words; $i++) {
    my $parent = $parents->[$i];
    if ($parent == 0) {
        print $words[$i] . " -> (the root)\n";
    } else {
        print $words[$i] . " -> " . $words[$parent - 1] . "\n";
    }
 }

 # This should return:
 #   edges in the dependency tree (child -> parent):
 #   Martin -> jde
 #   jde -> (the root)
 #   po -> jde
 #   ulici -> po
 #   . -> (the root)
 # which is the correct parse tree.

#  my $parsed_sentence = $parser->parse_sentence_internal( $sentence );

=head1 DESCRIPTION

This is a Perl implementation of the MST Parser described in
McDonald et al.:
Non-projective Dependency Parsing using Spanning Tree Algorithms,
2005,
in Proc. HLT/EMNLP.

B<Treex::Tool::Parser::MSTperl> contains an unlabelled parser 
L<Treex::Tool::Parser::MSTperl::Parser> and a dependency relation (deprel) 
labeller L<Treex::Tool::Parser::MSTperl::Labeller>, which, if chained together,
provide a labelled dependency parser.

Please note that the parser does B<non-projective> parsing and is 
therefore good for parsing of non-projective languages (e.g. Czech or Dutch). 
It is not the best choice for projective languages (e.g. English), but it can 
be used if you have no better parser at hand.
To do projective parsing, it 
would be necessary to change the core algorithm of the parser (Eisner would 
have to be used in stead of Chu-Liu-Edmonds).

Please note that the parser does B<dependency> parsing, 
producing a dependency tree as its output. The parser cannot be used to 
produce phrase-structure trees.

Models necessary for these tools 
can be
downloaded from 
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/> 
for the parser and from 
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/labeller_mira/> for 
the labeller.
Many models for Czech and a few models for English are provided.

If you have a dependency treebank, you can train your own model - see 
L<Treex::Tool::Parser::MSTperl::TrainerLabelling> and 
L<Treex::Tool::Parser::MSTperl::TrainerUnlabelled>. The parameters and the 
feature set are tuned for parsing of Czech language, so doing a little tuning 
might be helpful when parsing other languages (all of the necessary settings 
can be done in the config file - see L<Treex::Tool::Parser::MSTperl::Config>).

No models are provided for languages other than Czech or English. If you want 
to use the parser for another language, you have to train your own model.

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
