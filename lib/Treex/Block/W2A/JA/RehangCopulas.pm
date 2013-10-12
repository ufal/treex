package Treex::Block::W2A::JA::RehangCopulas;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# We rehang copulas "だ" and "です" which are auxiliary words
# But they are often dependent on non-verb token (noun, adjective...)
# So they function as a predicate in a sentence (often translated as "to be")
# Note that polite form "でございます" contains lemma "だ" so it is also processed

# TODO: take care of negative form of "だ" and "です" (maybe just change lemmas?)

# While recursively depth-first-traversing the tree
# we sometimes rehang already processed parent node as a child node.
# But we don't want to process such nodes again.
my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;
    my $lemma = $a_node->lemma;

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;
    
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }
    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $lemma = $a_node->lemma;
    return 0 if $tag !~ /^Jodōshi/;
    
    #TODO: make sure, that lemmas "です" and "だ" (and their negative forms) cover all copulas
    return 0 if ( $lemma ne "です" && $lemma ne "だ" && $lemma ne "じゃ" && $lemma ne "では" ) ;

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # All particles processed in following steps must stand after the word to which they are related
    return 0 if $a_node->precedes($parent);

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    # we rehang aux verbs which were dependent on previous parent
    # we also rehang all the particles dependent on coplusas previous parent
    foreach my $child ( $parent->get_children() ) {
        next if ( $child->tag !~ /^Joshi/ && $child->tag !~ /^Jodōshi/ ) ;
        $child->set_parent($a_node);
    }
    return;
}

1;

__END__

=over

=item Treex::Block::W2A::JA::RehangCopulas

Modifies the topology of trees parsed by JDEPP parser.
W2A::JA::RehangConjunctions should be used before using this block.
The word made into predicate by copula should depend on the copula, because that way the sentence should be easier to translate.

=back

=cut

# Author: Dusan Varis
