package Treex::Tool::Coreference::EN::PronAnaphFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::AnaphFilter';

has 'banned_prons' => (
    isa => 'HashRef[Str]',
    is  => 'ro',
    required => 1,
    builder => '_build_banned_prons',
);

sub _build_banned_prons {
    my ($self) = @_;
    my %banned_prons = map {$_ => 1} 
        qw/i me my mine you your yours we us our ours one/;
    return \%banned_prons;
}

sub is_candidate {
    my ($self, $node) = @_;

    my $is_3rd_pers = 0;
    if ( defined $t_node->gram_person ) {
        $is_3rd_pers = ($t_node->gram_person eq '3');
    }
    else {
        my $anode = $t_node->get_lex_anode;
        if (!defined $anode) return 0;
        $is_3rd_pers = (!defined $banned_prons{$anode->lemma});
    }
    return ( $t_node->t_lemma eq '#PersPron' && $is_3rd_pers );
}

# TODO doc

1;
