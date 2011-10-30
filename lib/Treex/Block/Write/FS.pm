package Treex::Block::Write::FS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

has '+language' => ( required => 1 );
has _was        => ( is => 'rw', default => sub{{}} );



#------------------------------------------------------------------------------
# Prints a minimal FS file header.
#------------------------------------------------------------------------------
BEGIN
{
    # Attribute ord is numerical and its values define the word order.
    print("\@N ord\n");
    # Attribute form is the surface representation of the node.
    # It should be used if the sentence is to be printed.
    print("\@V form\n");
    # Attribute form is positional, i.e. it can be printed without the attribute name (i.e. both "form=dog" and "dog" are allowed).
    print("\@P form\n");
}



#------------------------------------------------------------------------------
# Prepares a feature-value pair. Escapes special characters.
#------------------------------------------------------------------------------
sub get_feature_value
{
    my $feature = shift;
    my $value = shift;
    $value =~ s/([[=|,\]])/\\$1/g;
    return "$feature=$value";
}



#------------------------------------------------------------------------------
# Prepares a feature structure, including the square brackets. All features are
# named, i.e. we do not rely on positional definitions in the header. The
# features are added in the specified order.
#------------------------------------------------------------------------------
sub get_feature_structure_fhash
{
    my $fhash = shift; # features and their values
    my $flist = shift; # feature selection and order (array of names)
    my @outlist;
    foreach my $feature (@{$flist})
    {
        if(defined($fhash->{$feature}))
        {
            push(@outlist, get_feature_value($feature, $fhash->{$feature}));
        }
    }
    return '['.join(',', @outlist).']';
}



#------------------------------------------------------------------------------
# Prepares attributes of a node for printing.
#------------------------------------------------------------------------------
sub get_feature_structure
{
    my $node = shift;
    my %fhash =
    (
        'form'  => $node->form(),
        'lemma' => $node->lemma(),
        'tag'   => $node->tag(),
        'afun'  => $node->afun().($node->is_member() ? '_M' : ''),
        'ord'   => $node->ord()
    );
    my @flist = qw(form lemma tag afun ord);
    return get_feature_structure_fhash(\%fhash, \@flist);
}



#------------------------------------------------------------------------------
# Prepares output string for a node and all its descendants.
#------------------------------------------------------------------------------
sub get_subtree
{
    my $node = shift;
    my $result = get_feature_structure($node);
    my @children = map {get_subtree($_)} ($node->get_children({ordered => 1}));
    if(@children)
    {
        $result .= '('.join(',', @children).')';
    }
    return $result;
}



#------------------------------------------------------------------------------
# Prints one FS tree on one line.
#------------------------------------------------------------------------------
sub process_atree
{
    my $self = shift;
    my $root = shift;
    print(get_subtree($root), "\n");
}



#------------------------------------------------------------------------------
# Prints Tred parameters, namely defines custom stylesheet.
#------------------------------------------------------------------------------
END
{
    print("\n");
    print("//Tred:Custom-Attribute:\${form}\n");
    print("//Tred:Custom-Attribute:\${lemma}\n");
    print("//Tred:Custom-Attribute:\${tag}\n");
    print("//Tred:Custom-Attribute:\${afun}\n");
}



1;

__END__

=head1 NAME

Treex::Block::Write::FS

=head1 DESCRIPTION

Document writer for the old FS file format that can be opened, searched and edited in Tred.
This format was used in the first years of the Prague Dependency Treebank (1997) in the predecessor of Tred, called Graph.

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 AUTHOR

Daniel Zeman

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
