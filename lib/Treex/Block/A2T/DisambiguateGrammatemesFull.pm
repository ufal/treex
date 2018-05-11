package Treex::Block::A2T::DisambiguateGrammatemesFull;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has 'gender' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'number' => ( is => 'ro', isa => 'Bool', default => 1 );

sub select_most_common_value {
    my ($self, $gram, $chain) = @_;
    my %counter;
    foreach my $tnode (@$chain) {
        my $g = $tnode->get_attr("gram/$gram") or next;
        foreach my $value (grep {!/nr|inher/} split /\|/, $g){
            $counter{$value}++;
        }
    }
    my ($best_value) = sort {$counter{$b} <=> $counter{$a}} keys %counter;
    next if !$best_value;
    foreach my $tnode (@$chain){
        $tnode->set_attr("gram/$gram", $best_value);
    }
    return;
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
    return;
}

sub disambiguate_number_without_coref {
    my ($self, $tnode) = @_;

    my $number = $tnode->gram_number;
    return if (!defined $number);
    # do nothing if there is no ambiguity
    return if ($number !~ /\|/);

    $number = "sg";
    $tnode->set_gram_number($number);
    return;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, {ordered => 'topological'});

    foreach my $chain (@chains) {
        $self->select_most_common_value('gender', $chain) if $self->gender;
        $self->select_most_common_value('number', $chain) if $self->number;
    }
    return;
};

sub process_tnode {
    my ($self, $tnode) = @_;
    $self->disambiguate_gender_without_coref($tnode);
    $self->disambiguate_number_without_coref($tnode);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::DisambiguateGrammatemesFull

=head1 DESCRIPTION

Unlike Treex::Block::A2T::DisambiguateGrammatemes, this block uses the whole coref chain
to select the most common value of gender and number (except "nr" and "inher"),
thus even nodes in following sentences may help to resolve the ambiguity.

The block disambiguates multi-values of number and gender grammatemes of anaphoric 
nodes by copying these values from its antecedent.
By default, the 'inher' values are also replaced by their respective counterparts
from the antecedent.
If there is no antecedent of a node with multi-valued grammateme, this grammateme
is disambiguated by a rule.

=head1 PARAMETERS

=over

=item C<gender>

Applies disambiguation for genders. Turned on by default.

=item C<number>

Applies disambiguation for numbers. Turned on by default.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
