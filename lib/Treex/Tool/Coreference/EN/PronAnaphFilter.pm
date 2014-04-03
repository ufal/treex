package Treex::Tool::Coreference::EN::PronAnaphFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

has 'banned_prons' => (
    isa => 'HashRef[Str]',
    is  => 'ro',
    required => 1,
    builder => '_build_banned_prons',
);

has 'skip_referential' => ( is => 'ro', isa => 'Bool', default => 0, required => 1);

sub _build_banned_prons {
    my ($self) = @_;
    my %banned_prons = map {$_ => 1} 
        qw/i me my mine you your yours we us our ours one/;
    return \%banned_prons;
}

sub is_candidate {
    my ($self, $t_node) = @_;

    my $is_3rd_pers = 0;
    if ( defined $t_node->gram_person ) {
        $is_3rd_pers = ($t_node->gram_person eq '3');
    }
    else {
        my $anode = $t_node->get_lex_anode;
        return 0 if (!defined $anode);
        $is_3rd_pers = (!defined $self->banned_prons->{$anode->lemma});
    }
    # skip nodes marked as non-referential
    my $is_refer = $t_node->wild->{referential};
    return (
        (!$self->skip_referential || !defined $is_refer || ($is_refer == 1)) &&  # referential (if it's set)
        ($t_node->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers    # third person
    );
}

# TODO doc

1;
