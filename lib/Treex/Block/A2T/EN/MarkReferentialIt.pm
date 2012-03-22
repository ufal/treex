package Treex::Block::A2T::EN::MarkReferentialIt;

use Moose;
use Treex::Tool::Coreference::NADA;

extends 'Treex::Core::Block';

has '_resolver' => (
    is => 'ro',
    isa => 'Treex::Tool::Coreference::NADA',
    required => 1,
    builder => '_build_resolver',
);

has 'use_rules' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 0,
);

has 'threshold' => (
    is => 'ro',
    isa => 'Num',
    required => 1,
    default => 0.5,
);

has 'threshold_bottom' => (
    is => 'ro',
    isa => 'Num',
    required => 1,
    default => 0.7,
);

sub _build_resolver {
    my ($self) = @_;
    return Treex::Tool::Coreference::NADA->new();
}

sub process_zone {
    my ($self, $zone) = @_;

    my $atree = $zone->get_atree;
    my @ids = map {$_->id} $atree->get_descendants({ordered => 1});
    my @words = map {$_->form} $atree->get_descendants({ordered => 1});

    
    my $result = $self->_resolver->process_sentence(@words);
    my %it_ref_probs = map {$ids[$_] => $result->{$_}} keys %$result;

    my $ttree = $zone->get_ttree;
    foreach my $t_node ($ttree->get_descendants) {
        my @anode_ids = map {$_->id} $t_node->get_anodes;
        my ($it_id) = grep {defined $it_ref_probs{$_}} @anode_ids;
        if (defined $it_id) {
#            print STDERR "IT_ID: $it_id " . $it_ref_probs{$it_id} . "\n";
#            print STDERR (join " ", @words) . "\n";
            $t_node->wild->{'referential_prob'} = $it_ref_probs{$it_id};
            $t_node->wild->{'referential'} = $self->_is_refer($t_node, $it_ref_probs{$it_id}) ? 1 : 0;
        }
    }
}

sub _is_refer {
    my ($self, $tnode, $nada_prob) = @_;

    return (
        ($nada_prob > $self->threshold) ||
        ( $self->use_rules 
          && !( $nada_prob < $self->threshold_bottom || 
                $self->_is_nonrefer_by_rules($tnode)
              )
        ));
}

sub _is_nonrefer_by_rules {
    my ($self, $tnode) = @_;

    my $alex = $tnode->get_lex_anode();

    log_warn("PersPron does not have its own t-node") if ($alex->form !~ /^[iI]t$/);
    
    my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $tnode->get_eparents( { or_topological => 1} );

    return (defined $verb && 
        (_has_v_to_inf($verb)
        || _is_be_adj($verb)
        || _is_cog_verb($verb) )
    );
    #return ($alex->afun ne 'Sb');
}

my $to_clause_verbs = 'be|s|take|make';
# has an echild with formeme v:.*to+inf, or an echild with functor PAT and its echild has to+inf
sub _has_v_to_inf {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($to_clause_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
#         my @pats = grep { $_->functor eq "PAT" } @echildren;
#         foreach my $pat ( @pats ) {
#             push @echildren, $pat->get_echildren( { or_topological => 1 } );
#         }
        return 1 if ( grep { $_->formeme =~ /^v:.*to\+inf$/ } @echildren);
    }
    return 0;
}

sub _is_be_adj {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^(be|s)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
        my @pats = grep { $_->functor eq "PAT" and $_->formeme eq "adj:compl" } @echildren;
        foreach my $pat ( @pats ) {
            push @echildren, $pat->get_echildren( { or_topological => 1 } );
        }
        if ( @pats and grep { $_->formeme =~ /^v:.*fin$/ } @echildren) {
            return 1;
        }
    }
    return 0;
}

my $cog_ed_verbs = 'think|believe|recommend|say|note';
my $cog_verbs = 'seem|appear|mean|follow|matter';

sub _is_cog_verb {
    my ( $verb ) = @_;
    return ( 
        ( $verb->t_lemma =~ /^($cog_ed_verbs)$/
            and $verb->get_lex_anode 
            and $verb->get_lex_anode->tag eq "VBN" 
        )
        or $verb->t_lemma =~ /^($cog_verbs)$/
    ) ? 1 : 0;
}

1;

# TODO POD
