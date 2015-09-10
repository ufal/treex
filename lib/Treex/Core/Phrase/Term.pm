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
    is       => 'ro',
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
    # Add deprel only if it has not been supplied separately.
    if(!defined($attr->{deprel}) && defined($attr->{node}))
    {
        $attr->{deprel} = $attr->{node}->deprel();
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

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
