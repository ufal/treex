package Treex::Tool::SRLParser::PredicateIdentifier;

use Moose;
use Treex::Core::Common;

has 'language' => (
    is          => 'rw',
    isa         => 'Str',
    default     => 'cs',
    required    => 1,
);

sub is_predicate() {
    my ( $self, $candidate ) = @_;

    # One could use more sophisticated methods to idendify possible predicates
    # (words with valency, possible heads) at this point, such as SVM or any
    # other machine learning technique. For now, we identify nouns and verbs as
    # possible predicates.
    if ($self->language eq 'cs') {
        return ($candidate->tag =~ /^V/ or $candidate->tag =~ /^N/);
    }
    elsif ($self->language eq 'en') {
        return ($candidate->tag =~ m/^V[Bpf]/ or $candidate->tag =~ /^(NN|PRP|WP|CD$|WDT$|DT$)/);
    }
    else {
        # unknown language, return 1 for all predicate candidates
        return 1;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::SRLParser::PredicateIdentifier

=head1 SYNOPSIS

my $predicate_identifier = Treex::Tool::SRLParser::PredicateIdentifier->new();
    
my $is_predicate = $predicate_identifier->is_predicate($a_node);

=head1 DESCRIPTION

Predicate identifier for SRL parser according to L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>. Given a treex a-node, it returns true when a-node is a predicate (=has valency, can be a head in a semantic dependency relationship).

=head1 PARAMETERS

=over

=item language

Required parameter language, default is 'cs'.

=over

=head1 METHODS 

=over

=item $self->is_predicate( $self, $candidate )

Given a treex a-node, it returns true when a-node is a predicate (=has valency, can be a head in a semantic dependency relationship).

=back

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
