package Treex::Block::A2A::Tag2Interset;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;

has 'tagset' => (
    is => 'rw',
    required => 1,
);

#------------------------------------------------------------------------------
# Reads the a-tree, converts the original morphosyntactic tags to the PDT
# tagset, converts dependency relation tags to afuns and transforms the tree to
# adhere to the PDT guidelines. This method must be overriden in the subclasses
# that know about the differences between the style of their treebank and that
# of PDT. However, here is a sample of what to do. (Actually it's not just a
# sample. You can call it from the overriding method as
# $a_root = $self->SUPER::process_zone($zone);. Call this first and then do
# your specific stuff.)
#------------------------------------------------------------------------------
sub process_zone
{
    my ( $self, $zone ) = @_;

    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags( $zone->get_atree, $self->tagset );

    return 1;
}


#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    my $tagset = shift;    # optional, see below
    foreach my $node ( $root->get_descendants() )
    {
        $self->convert_tag( $node, $tagset );
    }
}

#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self   = shift;
    my $node   = shift;
    my $tagset = shift;    # optional tagset identifier (default = 'conll'; sometimes we need 'conll2007' etc.)
    $tagset = 'conll' unless ($tagset);

    # Note that the following hack will not work for all treebanks.
    # Some of them use tagsets not called '*::conll'.
    # Many others are not covered by DZ Interset yet.
    # tagset::common::find_drivers() could help but it would not be efficient to call it every time.
    # Instead, every subclass of this block must know whether to call convert_tag() or not.
    # List of CoNLL tagsets covered by 2011-07-05:
    my @known_drivers = qw(
        ar::conll ar::conll2007 bg::conll cs::conll cs::conll2009 da::conll de::conll de::conll2009
        en::conll en::conll2009
        es::conll2009 tr::conll
        hu::conll
        it::conll nl::conll pt::conll sv::conll zh::conll
        ja::conll hi::conll te::conll bn::conll el::conll ru::syntagrus sl::conll
        ro::rdt);
    my $driver = $node->get_zone()->language() . '::' . $tagset;
    if ( !grep { $_ eq $driver } (@known_drivers) ){
        log_fatal "Interset driver $driver not found";
        return;
	}


    # Current tag is probably just a copy of conll_pos.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $tag        = $node->tag();
    my $conll_cpos = $node->conll_cpos();
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    my $src_tag = $tagset eq 'conll2009' ? "$conll_pos\t$conll_feat" : $tagset =~ m/^conll/ ? "$conll_cpos\t$conll_pos\t$conll_feat" : $tag;
    my $f = tagset::common::decode($driver, $src_tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
}


1;

=over

=item Treex::Block::A2A::Tag2Interset

Convert C<tag> into Interset structure stored in C<iset>.
Replace the content of C<tag> with a newly serialized positional value.

Params:
- language
- tagset

=back

=cut

# Copyright 2011 Dan Zeman, Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
