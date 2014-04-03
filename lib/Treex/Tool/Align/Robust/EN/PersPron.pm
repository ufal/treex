package Treex::Tool::Align::Robust::EN::PersPron;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;

######################### SELECTORS #############################

sub access_via_ancestor {
    my ($tnode, $align_filters, $errors) = @_;

    my $verb_par = $tnode->get_parent();
    while (defined $verb_par && (!defined $verb_par->formeme || $verb_par->formeme !~ /^v/)) {
        $verb_par = $verb_par->get_parent();
    }
    if (!defined $verb_par) {
        push @$errors, "NO_EN_REF_VERB_ANCESTOR";
        return;
    }

    my @aligned_verb_par = Treex::Tool::Align::Utils::aligned_transitively([$verb_par], $align_filters);
    if (!@aligned_verb_par) {
        push @$errors, "NO_CS_REF_VERB_PAR";
        return;
    }

    my @aligned_kids = map {$_->get_echildren({or_topological => 1})} @aligned_verb_par;
    return @aligned_kids;
}

######################### FILTERS #############################

sub filter_self {
    my ($aligned, $tnode, $errors) = @_;

    my @filtered = grep {
        my $anode = $_->get_lex_anode();
        #defined $anode && $anode->tag =~ /^P[8SDP5]/
        defined $anode && $anode->tag =~ /^P[^47]/
    } @$aligned;
    if (!@filtered) {
        push @$errors, "NOPRON_CS_REF_TNODE";
        return;
    }
    return @filtered;
}

sub filter_eparents {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered = Treex::Block::My::BitextCorefStats::filter_by_functor($aligned, $tnode->functor, $errors);
    return @filtered;
}

sub filter_siblings {
    my ($aligned, $tnode, $errors) = @_;
    my $par = Treex::Block::My::BitextCorefStats::eparents_of_aligned_siblings($aligned, $errors);
    return if (!$par);
    my @kids = $par->get_echildren({or_topological => 1});
    my @filtered = Treex::Block::My::BitextCorefStats::filter_by_functor(\@kids, $tnode->functor, $errors);
    return @filtered;
}

sub filter_ancestor {
    my ($aligned, $tnode, $errors) = @_;

    my @aligned_dative_childs = grep {
        my $anode = $_->get_lex_anode; 
        if (defined $anode) {$anode->tag =~ /^P...3/}
    } @$aligned;
    
    if (!@aligned_dative_childs) {
        push @$errors, "NO_CS_REF_DATIVE_CHILD";
        return;
    }
    push @$errors, "BENEF_FOUND";
    return @aligned_dative_childs;
}

1;
