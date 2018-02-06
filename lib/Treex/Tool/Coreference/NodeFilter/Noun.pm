package Treex::Tool::Coreference::NodeFilter::Noun;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

###################### SEMANTIC NOUNS ############################

sub is_sem_noun {
    my ($node, $args) = @_;
    if ($node->get_layer eq 't') {
        return is_sem_noun_t($node, $args);
    }
    return 0;
}

sub is_sem_noun_t {
    my ($tnode, $args) = @_;
    $args //= {};
    
    return if !_is_sem_noun_t_all($tnode, $args);
    if ($tnode->language eq 'cs') {
        return if !is_sem_noun_t_cs($tnode, $args);
    }
    return 1;
}

sub is_sem_noun_t_cs {
    my ($tnode, $args) = @_;

    my $anode = $tnode->get_lex_anode;
    return (!$anode || ($anode->tag !~ /^[CJRTDIZV]/));
}    

sub _is_sem_noun_t_all {
    my ($tnode, $args) = @_;

    my $third_pers = !$tnode->gram_person || ($tnode->gram_person !~ /1|2/);
    my $arg_third_pers = $args->{person_3rd} // 0;
    return 0 if !ternary_arg($arg_third_pers, $third_pers);
    
    # indefinite
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        my $arg_indefinite = $args->{indefinite} // 0;
        my $indefinite = any {is_indefinite($_)} $anode->get_children;
        return 0 if !ternary_arg($arg_indefinite, $indefinite);
    }

    # proper
    my $arg_proper = $args->{proper} // 0;
    my $proper = is_proper($tnode);
    return 0 if !ternary_arg($arg_proper, $proper);

    return 1 if (defined $tnode->formeme && $tnode->formeme =~ /^n/);
    return (defined $tnode->gram_sempos && ($tnode->gram_sempos =~ /^n/));
}

####################### ARTICLE #############################

sub is_article {
    my ($node, $args) = @_;
    if ($node->get_layer eq 'a') {
        return _is_article_a($node, $args);
    }
}

sub _is_article_a {
    my ($anode, $args) = @_;
    if ($anode->language eq 'en') {
        return if (!_is_article_a_en($anode));
    }
    if ($anode->language eq 'de') {
        return if (!_is_article_a_de($anode));
    }
    
    my $arg_indefinite = $args->{indefinite} // 0;
    my $indefinite = is_indefinite($anode);
    return 0 if !ternary_arg($arg_indefinite, $indefinite);

    my $arg_definite = $args->{definite} // 0;
    my $definite = is_definite($anode);
    return 0 if !ternary_arg($arg_definite, $definite);

    return 1;
}

sub _is_article_a_en {
    my ($anode, $args) = @_;
    return ($anode->tag eq "DT");
}

sub _is_article_a_de {
    my ($anode, $args) = @_;
    # TODO: a criterion for a German article
    return 1;
}

###################### ATTRIBUTE FUNCTIONS ####################

sub is_indefinite {
    my ($anode) = @_;
    if ($anode->language eq 'de') {
        return ($anode->lemma eq "ein");
    }
    return 0;
}

sub is_definite {
    my ($anode) = @_;
    if ($anode->language eq 'en') {
        return ($anode->lemma eq "the");
    }
    if ($anode->language eq 'de') {
        return any {$anode->lemma eq $_} qw/der die das/;
    }
    return 0;
}

sub is_proper {
    my ($node) = @_;
    if ($node->get_layer eq "a") {
        my $nnode = $node->n_node;
        return (defined $nnode);
    }
    elsif ($node->get_layer eq "t") {
        my $nnode = $node->get_n_node;
        return ($node->is_name_of_person || defined $nnode);
    }
    return 0;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter::Noun

=head1 DESCRIPTION

A filter for nodes that are semantic nouns.

=head1 METHODS

=over

=item my $bool = is_sem_noun($tnode, $args)

Returns whether the input C<$tnode> is a semantic noun or not.
Using the following flags, one can specify the condition:

=over
=item third_pers - 0: both in and not in third person, 1: in third person, -1: not in third person
=back

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
