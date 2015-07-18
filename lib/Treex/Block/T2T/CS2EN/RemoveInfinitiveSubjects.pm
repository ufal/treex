package Treex::Block::T2T::CS2EN::RemoveInfinitiveSubjects;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # only solve infinitive verbs
    return if ( $t_node->formeme !~ /^v.*inf$/ );
    
    # TODO: Sometimes (raising/control) the subject should not be deleted:
    # Očekáváme, že přinese změnu -> We expect HIM to bring about a change.
    
    foreach my $subj (grep { $_->t_lemma eq '#PersPron' and $_->formeme eq 'n:subj' } $t_node->get_children()){
        $subj->remove();
    }
}

1;
