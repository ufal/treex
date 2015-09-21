package Treex::Core::Phrase::Term;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase';



has 'node' =>
(
    is       => 'ro',
    isa      => 'Treex::Core::Node',
    required => 1
);

has 'deprel' =>
(
    is       => 'rw',
    isa      => 'Str',
    required => 1
);



#------------------------------------------------------------------------------
# This block will be called before object construction. It will copy the deprel
# attribute from the node (unless it has been supplied by the caller
# separately). Then it will pass all the attributes to the constructor.
#------------------------------------------------------------------------------
around BUILDARGS => sub
{
    my $orig = shift;
    my $class = shift;
    # Call the default BUILDARGS in Moose::Object. It will take care of distinguishing between a hash reference and a plain hash.
    my $attr = $class->$orig(@_);
    if(defined($attr->{node}))
    {
        my $node = $attr->{node};
        # Add deprel only if it has not been supplied separately.
        if(!defined($attr->{deprel}))
        {
            if(defined($node->deprel()))
            {
                $attr->{deprel} = $node->deprel();
            }
            elsif(defined($node->afun()))
            {
                $attr->{deprel} = $node->afun();
            }
            elsif(defined($node->conll_deprel()))
            {
                $attr->{deprel} = $node->conll_deprel();
            }
            else
            {
                $attr->{deprel} = 'NR';
            }
        }
        # Copy the initial value of is_member from the node to the phrase.
        if(!defined($attr->{is_member}) && $node->is_member())
        {
            $attr->{is_member} = 1;
        }
    }
    return $attr;
};



#------------------------------------------------------------------------------
# Tells whether this phrase is terminal. We could probably use the Moose's
# methods to query the class name but this will be more convenient.
#------------------------------------------------------------------------------
sub is_terminal
{
    my $self = shift;
    return 1;
}



#------------------------------------------------------------------------------
# Returns the list of dependents of the phrase. Terminal phrases return an
# empty list by definition.
#------------------------------------------------------------------------------
sub dependents
{
    my $self = shift;
    return ();
}



#------------------------------------------------------------------------------
# Projects dependencies between the head and the dependents back to the
# underlying dependency structure. There is not much to do in the terminal
# phrase as it does not have any dependents. However, we will attach all nodes
# to the root, to prevent temporary cycles during the tree construction.
#------------------------------------------------------------------------------
sub project_dependencies
{
    my $self = shift;
    my $node = $self->node();
    unless($node->is_root())
    {
        my $root = $node->get_root();
        $node->set_parent($root);
    }
    # Reset the is_member flag.
    # If we are converting to the Prague style, the flag will be set again where needed.
    $node->set_is_member(0);
}



#------------------------------------------------------------------------------
# Returns a textual representation of the phrase and all subphrases. Useful for
# debugging.
#------------------------------------------------------------------------------
sub as_string
{
    my $self = shift;
    my $node = $self->node();
    my $form = '_';
    if($node->is_root())
    {
        $form = 'ROOT';
    }
    elsif(defined($node->form()))
    {
        $form = $node->form();
    }
    my $ord = $node->ord();
    my $deprel = defined($self->deprel()) ? '-'.$self->deprel() : '';
    return "[ $form-$ord$deprel ]";
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::Term

=head1 SYNOPSIS

  use Treex::Core::Document;
  use Treex::Core::Phrase::Term;

  my $document = new Treex::Core::Document;
  my $bundle   = $document->create_bundle();
  my $zone     = $bundle->create_zone('en');
  my $root     = $zone->create_atree();
  my $phrase   = new Treex::Core::Phrase::Term ('node' => $root);

=head1 DESCRIPTION

C<Term> is a terminal C<Phrase>. It contains (refers to) one C<Node> and it can
be part of nonterminal phrases (C<NTerm>).
See L<Treex::Core::Phrase> for more details.

=head1 ATTRIBUTES

=over

=item node

Refers to the C<Node> wrapped in this terminal phrase.

=item deprel

Any label describing the type of the dependency relation between this phrase
(its node) and the governing phrase (node of the first ancestor phrase where
this one does not act as head). This label is typically taken from the
underlying node when the phrase is built, but it may be translated or modified
and it is not kept synchronized with the underlying dependency tree during
transformations of the phrase structure. Nevertheless it is assumed that once
the transformations are done, the final dependency relations will be projected
back to the dependency tree.

The C<deprel> attribute can also be supplied separately when creating the
C<Phrase::Term>. If it is not supplied, it will be copied from the C<Node>
to which the C<node> attribute refers.

=item dependents

Returns the list of dependents of the phrase. Terminal phrases return an
empty list by definition.

=item project_dependencies

Projects dependencies between the head and the dependents back to the
underlying dependency structure. There is not much to do in the terminal
phrase as it does not have any dependents. However, we will attach all nodes
to the root, to prevent temporary cycles during the tree construction.

=item as_string

Returns a textual representation of the phrase and all subphrases. Useful for
debugging.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
