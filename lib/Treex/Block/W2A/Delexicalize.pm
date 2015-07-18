package Treex::Block::W2A::Delexicalize;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'keep_iset' => ( isa => 'Str', is => 'ro', required => 1, default => 1, documentation => 'comma-separated list of Interset features, or 1 (all), or 0 (none)' );
has '_keep_iset_hash' => ( isa => 'HashRef', is => 'ro', required => 1 );

#------------------------------------------------------------------------------
# This block will be called before object construction. It will build the
# hash of Interset features to be kept. Then it will pass all the attributes to
# the constructor.
#------------------------------------------------------------------------------
around BUILDARGS => sub
{
    my $orig = shift;
    my $class = shift;
    # Call the default BUILDARGS in Moose::Object. It will take care of distinguishing between a hash reference and a plain hash.
    my $attr = $class->$orig(@_);
    # Build the hash.
    my %hash;
    if($attr->{keep_iset}==0)
    {
        # Do nothing. The hash will be empty.
    }
    elsif($attr->{keep_iset}==1)
    {
        # All Interset features will be kept.
        # We will not touch the current data so we do not need the hash.
    }
    else
    {
        my @features = split(/,/, $attr->{keep_iset});
        foreach my $feature (@features)
        {
            $hash{$feature}++;
        }
    }
    # Now add the reference to the attribute hash.
    $attr->{_keep_iset_hash} = \%hash;
    return $attr;
};

sub process_anode
{
    my $self = shift;
    my $node = shift;
    # Backup lexical information as wild attributes so that it can be later restored.
    $node->wild()->{form} = $node->form();
    $node->wild()->{lemma} = $node->lemma();
    # Remove lexical information: word form and lemma.
    # We can set lemma to undef because the CoNLL writing procedures will take care of converting that to '_'.
    # However, the same will not work for the word form (seems like nobody expects it to be undefined), so we must set it to '_' ourselves.
    $node->set_form('_');
    $node->set_lemma(undef);
    # Optionally also remove Interset features (selected or all).
    unless($self->keep_iset()==1)
    {
        ###!!! We should backup iset in wild as well. But it must be a deep copy of the hash!
        my $ish = $node->iset()->get_hash();
        my $keep = $self->_keep_iset_hash();
        foreach my $key (keys(%{$ish}))
        {
            unless($keep->{$key})
            {
                delete($ish->{$key});
            }
        }
        $node->iset()->set_hash($ish);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::Delexicalize

=head1 DESCRIPTION

Removes lexical information (word form and lemma) from every a-node.
The lexical attributes are set to C<undef> (the blocks that export sentences
in formats readable by parsers will then render them as the underscore
character).
This is needed for a technique of cross-language parser training, called
I<delexicalized parsing>.
The removed values are backed up as wild attributes C<form> and C<lemma>
so they can be restored after parsing.

The block can optionally also remove some or all of the Interset features.
For example, if we know that our test data consistently lack the C<case>
feature, we may want to erase this feature from the training data, too.

=head1 PARAMETERS

=item C<keep_iset>

The value is either 0, or 1, or a comma-separated list of Interset features
(e.g. I<gender,animacy>). 1 means that Interset features should be left
untouched, 0 means that Interset should be completely removed.

Otherwise the value is interpreted as a list of Interset features that should
be kept (while the values of all other features will be cleared).

=over

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
