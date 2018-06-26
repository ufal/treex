package Treex::Block::A2T::CS::DeleteExtraCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Delete generated #PersPron in constructions like "zdá se, že"

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if $tnode->formeme ne 'drop';
    return if !$tnode->get_coref_text_nodes();
    my $verb = $tnode->get_parent();
    # this kind of error is common only in present tense
    return if ($verb->gram_tense || '') ne 'sim';
    return if $verb->t_lemma !~ /_se$/;
    if (any {$_->formeme =~ /^v:že/} $verb->get_children()){
        $tnode->remove();
    }
    return;
}

1;

