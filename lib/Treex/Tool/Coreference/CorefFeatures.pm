package Treex::Tool::Coreference::CorefFeatures;
use Moose::Role;

requires 'extract_features';

# TODO following is here just for the time being. it is not abstract enough
requires 'count_collocations';
requires 'count_np_freq';
requires 'mark_doc_clause_nums';

# TODO doc
1;
