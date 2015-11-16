package Treex::Block::A2T::DisambiguateGrammatemes;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

# TODO: multi-values for number

extends 'Treex::Core::Block';

# TODO never tested with replace_inher=0
has 'replace_inher' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'gender' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'number' => ( is => 'ro', isa => 'Bool', default => 1 );

sub _fits_multivalue_grammateme {
    my ($type, $tnode, $ante) = @_;
    my ($gram, $ante_gram);
    if ($type eq 'gender') {
        ($gram, $ante_gram) = ($tnode->gram_gender, $ante->gram_gender);
    }
    else {
        ($gram, $ante_gram) = ($tnode->gram_number, $ante->gram_number);
    }
    return if (!defined $gram);
    my %gend_hash = map {$_ => 1} split /\|/, $gram;

    if (defined $ante_gram && $ante_gram !~ /(^nr$)|\|/ && $gram ne "inher" && !$gend_hash{$ante_gram}) {
        log_warn "The $type grammateme '".$ante_gram."' of the node ". $tnode->id . " propagated from its antecedent does not agree with possible grams (".$gram.") in this context.";
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
                
                _fits_multivalue_grammateme('gender', $tnode, $ante);
                $tnode->set_gram_gender($ante->gram_gender);
            }
            if ($self->number &&
                defined $tnode->gram_number &&
                ($tnode->gram_number =~ /(^nr$)|\|/ || ($self->replace_inher && $tnode->gram_number eq 'inher'))) {
                
                _fits_multivalue_grammateme('number', $tnode, $ante);
                $tnode->set_gram_number($ante->gram_number);
            }
        }
    }
}

sub disambiguate_gender_without_coref {
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

sub disambiguate_number_without_coref {
    my ($self, $tnode) = @_;
    
    my $number = $tnode->gram_number;
    return if (!defined $number);
    # do nothing if there is no ambiguity
    return if ($number !~ /\|/);

    $number = "sg";
    $tnode->set_gram_number($number);
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    $self->propagate_via_coref($doc);
};

sub process_tnode {
    my ($self, $tnode) = @_;
    $self->disambiguate_gender_without_coref($tnode);
    $self->disambiguate_number_without_coref($tnode);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::DisambiguateGrammatemes

=head1 DESCRIPTION

The block disambiguates multi-values of number and gender grammatemes of anaphoric 
nodes by copying these values from its antecedent.
By default, the 'inher' values are also replaced by their respective counterparts
from the antecedent.
If there is no antecedent of a node with multi-valued grammateme, this grammateme
is disambiguated by a rule.

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
