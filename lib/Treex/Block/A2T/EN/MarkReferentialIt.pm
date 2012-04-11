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

    my $result = 0;
    if ( $self->use_nada && $self->_use_rules ) {
        if ( $nada_prob >= 0.52 && $nada_prob < 0.64 ) {
            $result = $self->_is_nonrefer_by_rules($tnode, $en2cs_node);
        }
        elsif ( $nada_prob >= 0.64 && $nada_prob < 0.76 ) {
            $result = !$self->_is_nonrefer_by_rules($tnode, $en2cs_node);
        }
        else {
            $result = ( $nada_prob >= $self->threshold );
        }
        #$result = ( $nada_prob > $self->threshold ||
        #       ( $nada_prob >= $self->threshold_bottom && !$self->_is_nonrefer_by_rules($tnode, $en2cs_node) ));
    }
    elsif ( $self->use_nada ) {
        $result = ( $nada_prob > $self->threshold );
    }
    elsif ( $self->_use_rules ) {
        $result = !$self->_is_nonrefer_by_rules($tnode, $en2cs_node);
    }
    return $result;
}

sub _is_nonrefer_by_rules {
    my ($self, $tnode, $en2cs_node) = @_;

    my $alex = $tnode->get_lex_anode();

    #log_warn("PersPron does not have its own t-node") if ($alex->form !~ /^[iI]t$/);
   
    my $verb;
    if ( ($tnode->gram_sempos || "") eq "v" ) {
        $verb = $tnode;
    }
    else {
        ($verb) = grep { ($_->gram_sempos || "") eq "v" } $tnode->get_eparents( { or_topological => 1} );
    }
    return 0 if (!defined $verb);
    
    my $feat_has_v_to_inf = Treex::Block::Eval::AddPersPronIt::has_v_to_inf($verb);
    my $feat_is_be_adj = Treex::Block::Eval::AddPersPronIt::is_be_adj($verb);
    my $feat_is_cog_verb = Treex::Block::Eval::AddPersPronIt::is_cog_verb($verb);
    my $feat_is_be_adj_err = Treex::Block::Eval::AddPersPronIt::is_be_adj_err($verb);
    my $feat_is_cog_ed_verb_err = Treex::Block::Eval::AddPersPronIt::is_cog_ed_verb_err($verb);
    my $feat_has_cs_to = Treex::Block::Eval::AddPersPronIt::has_cs_to($verb, $en2cs_node->{$tnode});

    my ($it) = grep { $_->lemma eq "it" } $tnode->get_anodes;
    my $feat_en_has_ACT = Treex::Block::Eval::AddPersPronIt::en_has_ACT($verb, $tnode, $it);
    my $feat_en_has_PAT = Treex::Block::Eval::AddPersPronIt::en_has_PAT($verb, $tnode, $it);
    my $feat_make_it_to = Treex::Block::Eval::AddPersPronIt::make_it_to($verb, $tnode);

    $tnode->wild->{has_v_to_inf} = $feat_has_v_to_inf;
    $tnode->wild->{is_be_adj} = $feat_is_be_adj;
    $tnode->wild->{is_cog_verb} = $feat_is_cog_verb;
    $tnode->wild->{is_be_adj_err} = $feat_is_be_adj_err;
    $tnode->wild->{is_cog_ed_verb_err} = $feat_is_cog_ed_verb_err;
    $tnode->wild->{has_cs_to} = $feat_has_cs_to;

    my @rules_results = grep {defined $_} (
        $self->_rules_hash->{has_v_to_inf} && $feat_has_v_to_inf,
        $self->_rules_hash->{is_be_adj} && $feat_is_be_adj,
        $self->_rules_hash->{is_cog_verb} && $feat_is_cog_verb,
        $self->_rules_hash->{is_be_adj_err} && $feat_is_be_adj_err,
        $self->_rules_hash->{is_cog_ed_verb_err} && $feat_is_cog_ed_verb_err,
        $self->_rules_hash->{has_cs_to} && $feat_has_cs_to,
        $self->_rules_hash->{en_has_ACT} && $feat_en_has_ACT,
        $self->_rules_hash->{en_has_PAT} && $feat_en_has_PAT,
        $self->_rules_hash->{make_it_to} && $feat_make_it_to,
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

1;

# TODO POD
