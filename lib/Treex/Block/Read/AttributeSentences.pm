package Treex::Block::Read::AttributeSentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has layer => ( isa=>'Treex::Type::Layer', is=>'ro', default=> 'a');

has attributes => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'list of attributes separated by spaces or commas',
);

has separator => ( isa => 'Str', is => 'ro', default => ' ' );

has attr_sep => ( isa => 'Str', is => 'ro', default => '\|' );

has from => (
    isa           => 'Treex::Core::Files',
    is            => 'rw',
    coerce        => 1,
    required      => 1,
    handles       => [qw(current_filename file_number _set_file_number)],
    documentation => 'arrayref of filenames to be loaded, '
        . 'coerced from a space or comma separated list of filenames',
);

has '+if_missing_zone' => ( default => 'create');

sub process_zone {
    my ($self, $zone) = @_;
    my $line = $self->from->next_line() // return;
    chomp $line;
    my $tree = $zone->create_tree($self->layer);
    my $sep_nodes = $self->separator;
    my $sep_attrs = $self->attr_sep;
    my @attr_names = split /[, ]/, $self->attributes;
    my @nodes_str = split /$sep_nodes/, $line;

    # First, create nodes without any attributes (just ord).
    my $ord = 1;    
    my @nodes = map {$tree->create_child({ord => $ord++})} @nodes_str;
    
    # Second, fill the attributes (including potential dependencies).
    foreach my $node (@nodes){
        my $node_str    = shift @nodes_str;
        my @attr_values = split /$sep_attrs/, $node_str;
        for my $i (0 .. min($#attr_names, $#attr_values)){
            if ($attr_names[$i] eq 'ignore'){
            } elsif ($attr_names[$i] eq 'parent'){
                $node->set_parent($nodes[$attr_values[$i]]);
            } else {
                $node->set_attr($attr_names[$i], $attr_values[$i]);
            }
        }
    }
    return 1;
}

1;

__END__

=head1 NAME

Treex::Block::Read::AttributeSentences - read various formats

=head1 SYNOPSIS

  Read::AttributeSentences attributes=form,lemma,tag from=input.txt layer=a language=en
  Read::AttributeSentences attributes=form,afun,parent separator='\t' attr_sep=' ' from='!{dir1,dir2}/*.txt'

=head1 DESCRIPTION

Read files with one sentence per line.
Each sentence is represented as a list of nodes (words)
and each node as a list of attributes.

The first block in Synopsis can read files such as:

 John|John|NNP loves|love|VBZ Mary|Mary|NNP
 Second|second|JJ sentence|sentence|NN
  
The second block reads this format (tab is here shown as 8 spaces):

 John Sb 2        loves Pred 0        Mary Obj 2

=head1 PARAMETERS

=head2 layer

Which layer (a,t,n,p) trees should be created. Default is C<a>.

=head2 attributes

List of attributes separated by spaces or commas.
Special attribute I<parent> is treated as index of the parent (governing) node
(index 0 is reserved for the technical root, the first word has index 1).
Special attribute I<ignore> serves for skipping attributes (e.g. ord which is filled by default).

=head2 separator

The separator character (regex) for the individual nodes within one sentence. Space is the default.

=head2 attr_sep

The separator character (regex) for the individual attribute values for one node.
Vertical bar ("\|" -- escaped as it will be included in the regex) is the default.


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
