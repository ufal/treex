package Treex::Block::A2T::EN::MarkReferentialIt;

use Moose;
use Treex::Tool::Coreference::NADA;
use List::MoreUtils qw/all any/;

use Treex::Block::Eval::AddPersPronIt;

extends 'Treex::Core::Block';

has '_resolver' => (
    is => 'ro',
    isa => 'Treex::Tool::Coreference::NADA',
    required => 1,
    builder => '_build_resolver',
);

has 'use_nada' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 1,
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

has '_use_rules' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'rules' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => '',
);

has '_rules_hash' => (
    is => 'ro',
    isa => 'HashRef[Bool]',
    required => 1,
    lazy => 1,
    builder => '_build_rules_hash',
);

sub BUILD {
    my ($self) = @_;
    $self->_rules_hash;
    use Data::Dumper;
    print Dumper($self->_rules_hash);
}

sub _build_resolver {
    my ($self) = @_;
    return Treex::Tool::Coreference::NADA->new();
}

sub _build_rules_hash {
    my ($self) = @_;

    my %rules = map {$_ => 1} (split /,/, $self->rules);
    $self->_set_use_rules(1) if (keys %rules > 0);
    return \%rules;
}

sub process_zone {
    my ($self, $zone) = @_;

    my $atree = $zone->get_atree;
    my @ids = map {$_->id} $atree->get_descendants({ordered => 1});
    my @words = map {$_->form} $atree->get_descendants({ordered => 1});

    
    my $result = $self->_resolver->process_sentence(@words);
    my %it_ref_probs = map {$ids[$_] => $result->{$_}} keys %$result;

    my $ttree = $zone->get_ttree;
    
    ##### BRUTAL HACK ##########
    my $cs_src_tree = $zone->get_bundle->get_tree('cs','t','src');
    my %en2cs_node = Treex::Block::Eval::AddPersPronIt::get_en2cs_links($cs_src_tree);

    foreach my $t_node ($ttree->get_descendants) {
        my @anode_ids = map {$_->id} $t_node->get_anodes;
        my ($it_id) = grep {defined $it_ref_probs{$_}} @anode_ids;
        if (defined $it_id) {
#            print STDERR "IT_ID: $it_id " . $it_ref_probs{$it_id} . "\n";
#            print STDERR (join " ", @words) . "\n";
            $t_node->wild->{'referential_prob'} = $it_ref_probs{$it_id};
            $t_node->wild->{'referential'} = $self->_is_refer($t_node, $it_ref_probs{$it_id}, \%en2cs_node) ? 1 : 0;
        }
    }
}

sub _is_refer {
    my ($self, $tnode, $nada_prob, $en2cs_node) = @_;

    return (
        ( $self->use_nada && $self->_use_rules
            && ( $nada_prob > $self->threshold ||
               ( $nada_prob >= $self->threshold_bottom && !$self->_is_nonrefer_by_rules($tnode, $en2cs_node) ))) ||
        ( $self->use_nada 
            && ( $nada_prob > $self->threshold )) ||
        ( $self->_use_rules 
            && !$self->_is_nonrefer_by_rules($tnode, $en2cs_node)));
}

sub _is_nonrefer_by_rules {
    my ($self, $tnode, $en2cs_node) = @_;

    my $alex = $tnode->get_lex_anode();

    log_warn("PersPron does not have its own t-node") if ($alex->form !~ /^[iI]t$/);
   
    my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $tnode->get_eparents( { or_topological => 1} );
    return 0 if (!defined $verb);

    my @rules_results = grep {defined $_} (
        $self->_rules_hash->{has_v_to_inf} && Treex::Block::Eval::AddPersPronIt::has_v_to_inf($verb),
        $self->_rules_hash->{is_be_adj} && Treex::Block::Eval::AddPersPronIt::is_be_adj($verb),
        $self->_rules_hash->{is_cog_verb} && Treex::Block::Eval::AddPersPronIt::is_cog_verb($verb),
        $self->_rules_hash->{is_be_adj_err} && Treex::Block::Eval::AddPersPronIt::is_be_adj_err($verb),
        $self->_rules_hash->{is_cog_ed_verb_err} && Treex::Block::Eval::AddPersPronIt::is_cog_ed_verb_err($verb),
        $self->_rules_hash->{has_cs_to} && Treex::Block::Eval::AddPersPronIt::has_cs_to($verb, $en2cs_node->{$tnode}),
    );
#                         or has_v_to_inf_err($t_node, $autom_tree)
    return any {$_} @rules_results;

    #return (defined $verb && 
    #    (has_v_to_inf($verb)
    #    || is_be_adj($verb)
    #    || is_cog_verb($verb) )
    #);
    #return ($alex->afun ne 'Sb');
}

my $to_clause_verbs = 'be|s|take|make';
# has an echild with formeme v:.*to+inf, or an echild with functor PAT and its echild has to+inf
sub has_v_to_inf {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($to_clause_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
#         my @pats = grep { $_->functor eq "PAT" } @echildren;
#         foreach my $pat ( @pats ) {
#             push @echildren, $pat->get_echildren( { or_topological => 1 } );
#         }
        return 1 if ( grep { $_->formeme =~ /^v:.*to\+inf$/ } @echildren );
    }
    return 0;
}

my $be_verbs = 'be|s|become';
sub is_be_adj {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($be_verbs)$/ ) {
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

sub is_cog_verb {
    my ( $verb ) = @_;
    return ( 
        ( $verb->t_lemma =~ /^($cog_ed_verbs)$/
            and $verb->get_lex_anode 
            and $verb->get_lex_anode->tag eq "VBN" 
        )
        or $verb->t_lemma =~ /^($cog_verbs)$/
    ) ? 1 : 0;
}

my $to_clause_verbs_pat = 'make|take';
# error case: make it <adj/noun> + <inf>: it is a child of <adj/noun> or <inf>
# looks for the word that precede it in the surface sentence, if it's make/take and has inf among children
sub has_v_to_inf_err {
    my ( $t_it, $t_tree ) = @_;
    my $a_it = $t_it->get_lex_anode;
    if ( $a_it ) {
        my $a_ord = $a_it->ord - 1;
        my ($precendant) = grep { $_->get_lex_anode and $_->get_lex_anode->ord == $a_ord } $t_tree->get_descendants;
        if ( $precendant 
            and $precendant->t_lemma =~ /^($to_clause_verbs_pat)$/
            and grep { $_->formeme =~ /^v:.*to\+inf$/ } $precendant->get_echildren( { or_topological => 1 } )
        ) {
            return 1;
        }
    }
    return 0;
}

sub is_be_adj_err {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($be_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
        my @pats = grep { $_->functor eq "PAT" and $_->formeme =~ /^(adj:compl|n:obj)$/ } @echildren;
        foreach my $pat ( @pats ) {
            push @echildren, $pat->get_echildren( { or_topological => 1 } );
        }
        if ( @pats and grep { $_->formeme =~ /^v:/ } @echildren) {
            return 1;
        }
    }
    return 0;
}

# error case: it can be said: be -> {it, say}
sub is_cog_ed_verb_err {
    my ( $verb ) = @_;
    return ( 
        $verb->t_lemma =~ /^(be|s)$/
        and grep { $_->t_lemma =~ /^($cog_ed_verbs)$/ } $verb->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

# English "it's" has a Czech equivalent "to"
sub has_cs_to {
    my ( $verb, $t_to ) = @_;
    return ( 
        $verb->t_lemma =~ /^($be_verbs)$/ 
        and $t_to 
        and $t_to->t_lemma eq "ten" 
        and $t_to->get_lex_anode 
        and $t_to->get_lex_anode->lemma eq "to"  
    ) ? 1 : 0;
}

1;

# TODO POD
