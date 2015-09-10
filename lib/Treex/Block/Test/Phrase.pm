package Treex::Block::Test::Phrase;
use Moose;
use Treex::Core::Common;
use Treex::Core::Phrase::Builder;
use utf8;
extends 'Treex::Block::Test::BaseTester';



#------------------------------------------------------------------------------
# Converts a dependency tree to phrase-structure tree and back. We should get
# the same structure.
#------------------------------------------------------------------------------
sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $before = $self->tree_to_string($root);
    my $builder = new Treex::Core::Phrase::Builder;
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    my $after = $self->tree_to_string($root);
    if($before ne $after)
    {
        log_info("BEFORE: $before\n".
                 "AFTER:  $after\n");
    }
}



#------------------------------------------------------------------------------
# Serializes a tree to a string of dependencies (similar to the Stanford
# format).
#------------------------------------------------------------------------------
sub tree_to_string
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my @dependencies = map
    {
        my $n = $_;
        my $p = $n->parent();
        my $d = defined($n->deprel()) ? $n->deprel() : 'NR';
        my $no = $n->ord();
        my $po = $p->ord();
        my $nf = $n->form();
        my $pf = $p->form();
        "$d($pf-$po, $nf-$no)"
    }
    (@nodes);
    return join(' ', map {$_->form()} (@nodes))."\t".join('; ', @dependencies);
}



1;

=over

=item Treex::Block::Test::Phrase

Converts a dependency (a-) tree to phrase-structure tree and back.
We should get the same structure.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
