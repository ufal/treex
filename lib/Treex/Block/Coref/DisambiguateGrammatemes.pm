package Treex::Block::Coref::DisambiguateGrammatemes;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

# TODO never tested with replace_inher=0
has 'replace_inher' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'gender' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'number' => ( is => 'ro', isa => 'Bool', default => 1 );

sub _fits_multi_gram_gender {
    my ($tnode, $ante) = @_;
    my ($gender, $ante_gender) = ($tnode->gram_gender, $ante->gram_gender);
    return if (!defined $gender);
    my %gend_hash = map {$_ => 1} split /\|/, $gender;

    if (defined $ante_gender && $ante_gender !~ /(^nr$)|\|/ && $gender ne "inher" && !$gend_hash{$ante_gender}) {
        log_warn "The gender '".$ante_gender."' of the node ". $tnode->id . " propagated from its antecedent does not agree with possible genders (".$gender.") in this context.";
    }
}

sub propagate_via_coref {
    my ($self, $doc) = @_;
    
    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, {ordered => 'topological'});

    foreach my $chain (@chains) {
        # start with the nodes that do not refer to anything
        foreach my $tnode (reverse @$chain) {
            # TODO add support for multiple antecedents
            my ($ante) = $tnode->get_coref_nodes;
            next if (!defined $ante);
            
            if ($self->gender &&
                defined $tnode->gram_gender &&
                ($tnode->gram_gender =~ /(^nr$)|\|/ || ($self->replace_inher && $tnode->gram_gender eq 'inher'))) {
                
                _fits_multi_gram_gender($tnode, $ante);
                $tnode->set_gram_gender($ante->gram_gender);
            }
            if ($self->number &&
                defined $tnode->gram_number &&
                ($tnode->gram_number eq 'nr' || ($self->replace_inher && $tnode->gram_number eq 'inher'))) {
                
                $tnode->set_gram_number($ante->gram_number);
            }
        }
    }
}

sub disambiguate_without_coref {
    my ($self, $tnode) = @_;
    
    my $gender = $tnode->gram_gender;
    return if (!defined $gender);
    # do nothing if there is no ambiguity
    return if ($gender !~ /\|/);

    $gender = ($gender eq 'anim|inan') ? 'anim' :
              ($gender eq 'fem|neut')  ? 'fem'  :
                                         'nr'   ;
    $tnode->set_gram_gender($gender);
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    $self->propagate_via_coref($doc);
};

sub process_tnode {
    my ($self, $tnode) = @_;
    $self->disambiguate_without_coref($tnode);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::DisambiguateGrammatemes

=head1 DESCRIPTION

The block disambiguates 'nr' values of number and gender grammatemes of anaphoric 
nodes by copying these values from its antecedent.
By default, the 'inher' values are also replaced by their respective counterparts
from the antecedent.

=head1 PARAMETERS

=over

=item C<replace_inher>

Replaces 'inher' values of gender and number grammatemes by a respective value
from the antecedent. Turned on by default.

=item C<gender>

Applies disambiguation for genders. Turned on by default.

=item C<number>

Applies disambiguation for numbers. Turned on by default.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
